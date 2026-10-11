# rbx5 Studio worker: lets the project's cloud Claude session drive Roblox Studio on this PC through files.
# Run once, detached:  powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File rbx-worker.ps1
# Stop it: create a file named STOP next to this script (or it exits by itself after IdleHours with no tasks).
#
# The cloud session drops task files into inbox\<id>.json; results land in outbox\<id>\ (log.txt, results.json,
# images, DONE). Task kinds (nothing else is executed):
#   {"kind":"mcp","match":"rocket","calls":[...]}     Studio MCP tool calls through mcp-call.ps1
#   {"kind":"open","place":"rocket.rbxlx","closeOurs":true}   open places\<file> in Studio (closes Studios we opened)
#   {"kind":"close"}                                   close the Studio windows this worker opened
#   {"kind":"studiowin"}                               PNG of the Studio window(s) only (to see dialogs)
#   {"kind":"keys","keys":"^s"}                        SendKeys to the Studio window this worker opened
param([string] $Root = $PSScriptRoot, [double] $IdleHours = 72)
$ErrorActionPreference = 'Continue'
$mutex = New-Object System.Threading.Mutex($false, 'Global\rbx5-studio-worker')
if (-not $mutex.WaitOne(0)) { exit 0 }

$inbox = Join-Path $Root 'inbox'; $outbox = Join-Path $Root 'outbox'; $doneDir = Join-Path $Root 'done'; $places = Join-Path $Root 'places'
foreach ($d in $inbox, $outbox, $doneDir, $places) { New-Item -ItemType Directory -Force $d | Out-Null }
$logFile = Join-Path $Root 'worker.log'
function Log($m) { Add-Content -Path $logFile -Value ("{0:u} {1}" -f (Get-Date), $m) }

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class RbxW {
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

function Get-StudioExe {
  Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter 'RobloxStudioBeta.exe' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
function Get-Studios { @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }) }
function Get-OurStudios {
  $names = @(Get-ChildItem $places -Filter *.rbxlx | ForEach-Object { $_.BaseName })
  @(Get-Studios | Where-Object { $t = $_.MainWindowTitle; $names | Where-Object { $t -like "*$_*" } })
}
function Show-Studios {
  # Studio only renders captures while not minimized: restore without stealing focus, keep it behind other windows.
  foreach ($s in Get-OurStudios) {
    $h = $s.MainWindowHandle
    if ([RbxW]::IsIconic($h)) { [void][RbxW]::ShowWindowAsync($h, 4) }
    [void][RbxW]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x13)
  }
}
function Close-OurStudios {
  foreach ($s in Get-OurStudios) {
    Log "closing studio pid $($s.Id) '$($s.MainWindowTitle)'"
    try { $s.Kill() } catch { Log "kill failed: $_" }
  }
  Start-Sleep -Seconds 2
}
function Save-WindowPng($proc, $path) {
  $r = New-Object RbxW+RECT
  [void][RbxW]::GetWindowRect($proc.MainWindowHandle, [ref]$r)
  $w = [math]::Max(1, $r.R - $r.L); $hgt = [math]::Max(1, $r.B - $r.T)
  $bmp = New-Object System.Drawing.Bitmap $w, $hgt
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc()
  [void][RbxW]::PrintWindow($proc.MainWindowHandle, $hdc, 2)
  $g.ReleaseHdc($hdc); $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
function Write-Heartbeat {
  $hb = @{ time = (Get-Date).ToString('u'); pid = $PID; studios = @(Get-Studios | ForEach-Object { @{ pid = $_.Id; title = $_.MainWindowTitle } }) }
  $hb | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 (Join-Path $outbox 'heartbeat.json')
}

function Run-Task($file) {
  $id = [IO.Path]::GetFileNameWithoutExtension($file.Name)
  $od = Join-Path $outbox $id
  New-Item -ItemType Directory -Force $od | Out-Null
  $log = Join-Path $od 'log.txt'
  try { $task = Get-Content $file.FullName -Raw -Encoding utf8 | ConvertFrom-Json } catch { "bad json: $_" | Out-File $log; return }
  Log "task $id kind=$($task.kind)"
  switch ($task.kind) {
    'mcp' {
      $callsPath = Join-Path $od 'calls.json'
      $task.calls | ConvertTo-Json -Depth 40 | Out-File -Encoding utf8 $callsPath
      Show-Studios
      $timeout = if ($task.timeoutSec) { [int]$task.timeoutSec } else { 1200 }
      $match = if ($task.match) { [string]$task.match } else { '' }
      $client = Join-Path $Root 'mcp-call.ps1'
      $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$client`" -Calls `"$callsPath`" -OutDir `"$od`" -Match `"$match`""
      $p = Start-Process powershell -ArgumentList $argList -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError (Join-Path $od 'stderr.txt')
      if (-not $p.WaitForExit($timeout * 1000)) { try { $p.Kill() } catch {}; Add-Content $log "WORKER: killed after $timeout s" }
    }
    'open' {
      $name = [IO.Path]::GetFileName([string]$task.place)
      $path = Join-Path $places $name
      if (-not ($name -like '*.rbxlx') -or -not (Test-Path $path)) { "no such place: $name" | Out-File $log; break }
      if ($task.closeOurs) { Close-OurStudios }
      $exe = Get-StudioExe
      if (-not $exe) { 'RobloxStudioBeta.exe not found' | Out-File $log; break }
      Start-Process $exe.FullName -ArgumentList @('-task', 'EditFile', '-localPlaceFile', "`"$path`"") | Out-Null
      $base = [IO.Path]::GetFileNameWithoutExtension($name)
      $deadline = (Get-Date).AddSeconds(120); $ok = $false
      while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        if (Get-Studios | Where-Object { $_.MainWindowTitle -like "*$base*" }) { $ok = $true; break }
      }
      Start-Sleep -Seconds 8
      Show-Studios
      "opened=$ok $path`n" + ((Get-Studios | ForEach-Object { "$($_.Id) $($_.MainWindowTitle)" }) -join "`n") | Out-File $log
    }
    'close' { Close-OurStudios; 'closed' | Out-File $log }
    'studiowin' {
      Show-Studios; Start-Sleep -Milliseconds 500
      $i = 0
      foreach ($s in Get-Studios) { $i++; Save-WindowPng $s (Join-Path $od "studio$i.png"); Add-Content $log "$i $($s.Id) $($s.MainWindowTitle)" }
    }
    'keys' {
      $s = Get-OurStudios | Select-Object -First 1
      if ($s) {
        [void][RbxW]::ShowWindowAsync($s.MainWindowHandle, 9); [void][RbxW]::SetForegroundWindow($s.MainWindowHandle)
        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.SendKeys]::SendWait([string]$task.keys)
        "sent $($task.keys) to $($s.MainWindowTitle)" | Out-File $log
      } else { 'no studio of ours open' | Out-File $log }
    }
    default { "unknown kind $($task.kind)" | Out-File $log }
  }
}

Log "worker start pid $PID root $Root"
$lastTask = Get-Date; $lastBeat = (Get-Date).AddMinutes(-1)
while ($true) {
  if (Test-Path (Join-Path $Root 'STOP')) { Log 'STOP file found, exiting'; break }
  if (((Get-Date) - $lastTask).TotalHours -gt $IdleHours) { Log 'idle limit reached, exiting'; break }
  if (((Get-Date) - $lastBeat).TotalSeconds -ge 15) { Write-Heartbeat; $lastBeat = Get-Date }
  $files = @(Get-ChildItem $inbox -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name)
  foreach ($f in $files) {
    Start-Sleep -Milliseconds 500   # let the writer finish
    try { Run-Task $f } catch { Log "task $($f.Name) crashed: $_" }
    $od = Join-Path $outbox ([IO.Path]::GetFileNameWithoutExtension($f.Name))
    New-Item -ItemType Directory -Force $od | Out-Null
    (Get-Date).ToString('u') | Out-File (Join-Path $od 'DONE')
    Move-Item -Force $f.FullName (Join-Path $doneDir $f.Name)
    $lastTask = Get-Date
    Write-Heartbeat; $lastBeat = Get-Date
  }
  Start-Sleep -Seconds 2
}
$mutex.ReleaseMutex()
