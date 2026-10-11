# Minimal stdio MCP client for Roblox StudioMCP.exe (v2 of playbook/pc-research/studio-mcp-test/studio-mcp-client.ps1).
# Usage: mcp-call.ps1 -Calls <calls.json> -OutDir <dir> [-Match <text>] [-TimeoutSec 120]
# calls.json: [{"name":"tool_name","arguments":{...},"timeout":300,"save":"file-prefix"}, ...]
#   "name":"__list" writes tools-list.json.  "studio_id":"AUTO" in arguments is replaced with the id of the
#   connected Studio whose listing contains -Match (else the first one).
# Writes log lines to stdout and every result (full text, image file names) to <OutDir>\results.json.
param(
  [Parameter(Mandatory)] [string] $Calls,
  [Parameter(Mandatory)] [string] $OutDir,
  [string] $Match = '',
  [int] $TimeoutSec = 120
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$exe = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter 'StudioMCP.exe' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { throw 'StudioMCP.exe not found' }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe.FullName
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)
$errTask = $p.StandardError.ReadToEndAsync()
$script:pending = $null
$script:nextId = 1
$results = New-Object System.Collections.ArrayList

function Send-Msg($obj) {
  $json = $obj | ConvertTo-Json -Depth 40 -Compress
  $p.StandardInput.WriteLine($json)
  $p.StandardInput.Flush()
}

function Receive-Result([int] $id, [int] $timeout) {
  $deadline = (Get-Date).AddSeconds($timeout)
  while ((Get-Date) -lt $deadline) {
    if (-not $script:pending) { $script:pending = $p.StandardOutput.ReadLineAsync() }
    $left = [int][math]::Max(100, ($deadline - (Get-Date)).TotalMilliseconds)
    if (-not $script:pending.Wait($left)) { break }
    $line = $script:pending.Result
    $script:pending = $null
    if ($null -eq $line) { throw "server closed stdout. stderr: $($errTask.Result)" }
    if (-not $line.Trim()) { continue }
    try { $msg = $line | ConvertFrom-Json } catch { Write-Output "[non-json] $line"; continue }
    if ($msg.id -eq $id) { return $msg }
    if ($msg.method) { Write-Output "[notification] $($msg.method)" }
  }
  throw "timeout after $timeout s waiting for id $id"
}

function Invoke-Rpc([string] $method, $params, [int] $timeout) {
  $id = $script:nextId++
  Send-Msg @{ jsonrpc = '2.0'; id = $id; method = $method; params = $params }
  Receive-Result $id $timeout
}

function Get-StudioId($listText) {
  try { $obj = $listText | ConvertFrom-Json } catch { return $null }
  $studios = @($obj.studios)
  if ($studios.Count -eq 0) { return $null }
  $pick = $studios[0]
  if ($Match) {
    foreach ($s in $studios) { if (($s | ConvertTo-Json -Compress -Depth 10) -like "*$Match*") { $pick = $s; break } }
  }
  foreach ($k in 'studio_id', 'studioId', 'id') { if ($pick.$k) { return [string]$pick.$k } }
  return $null
}

$studioId = $null
try {
  $init = Invoke-Rpc 'initialize' @{ protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'rbx5-worker'; version = '0.2' } } 60
  Write-Output ("server: " + ($init.result.serverInfo | ConvertTo-Json -Compress))
  Send-Msg @{ jsonrpc = '2.0'; method = 'notifications/initialized' }

  # The proxy needs a few seconds to find running Studios; wait until one is listed.
  $warm = (Get-Date).AddSeconds(60)
  while ((Get-Date) -lt $warm) {
    $s = Invoke-Rpc 'tools/call' @{ name = 'list_roblox_studios'; arguments = @{} } 30
    $txt = ($s.result.content | Where-Object type -eq 'text' | Select-Object -First 1).text
    if ($txt -match '"studios":\s*\[\s*\{') {
      Write-Output "studios: $txt"
      $studioId = Get-StudioId $txt
      Write-Output "picked studio_id: $studioId (match '$Match')"
      [void]$results.Add(@{ n = 0; name = 'list_roblox_studios'; ok = $true; texts = @($txt); images = @(); studio_id = $studioId })
      break
    }
    Start-Sleep -Seconds 2
  }

  $list = Get-Content $Calls -Raw -Encoding utf8 | ConvertFrom-Json
  $n = 0
  foreach ($c in $list) {
    $n++
    if ($c.name -eq '__list') {
      $tl = Invoke-Rpc 'tools/list' @{} 60
      $tl | ConvertTo-Json -Depth 40 | Out-File -Encoding utf8 (Join-Path $OutDir 'tools-list.json')
      Write-Output "tools-list.json written ($(@($tl.result.tools).Count) tools)"
      continue
    }
    $t = if ($c.timeout) { [int]$c.timeout } else { $TimeoutSec }
    $args2 = if ($c.arguments) { $c.arguments } else { New-Object PSObject }
    if ($args2.PSObject.Properties.Name -contains 'studio_id' -and $args2.studio_id -eq 'AUTO') { $args2.studio_id = $studioId }
    Write-Output "=== [$n] $($c.name)"
    $rec = @{ n = $n; name = $c.name; ok = $false; texts = @(); images = @() }
    try {
      $r = Invoke-Rpc 'tools/call' @{ name = $c.name; arguments = $args2 } $t
      if ($r.error) {
        $rec.texts += ("RPC ERROR: " + ($r.error | ConvertTo-Json -Compress -Depth 10))
        Write-Output $rec.texts[-1]
      } else {
        $rec.ok = -not $r.result.isError
        if ($r.result.isError) { Write-Output 'TOOL REPORTED ERROR' }
        $k = 0
        foreach ($part in $r.result.content) {
          $k++
          if ($part.type -eq 'image') {
            $ext = if ($part.mimeType -match 'jpeg') { 'jpg' } else { 'png' }
            $name = if ($c.save) { "$($c.save)-$k.$ext" } else { "call$n-$k.$ext" }
            [IO.File]::WriteAllBytes((Join-Path $OutDir $name), [Convert]::FromBase64String($part.data))
            $rec.images += $name
            Write-Output "IMAGE saved $name"
          } elseif ($part.type -eq 'text') {
            $rec.texts += $part.text
            $txt = $part.text
            if ($txt.Length -gt 2000) { $txt = $txt.Substring(0, 2000) + " ...[+$($part.text.Length - 2000) chars]" }
            Write-Output "TEXT: $txt"
          } else {
            $rec.texts += ("PART " + ($part | ConvertTo-Json -Compress -Depth 10))
          }
        }
      }
    } catch {
      $rec.texts += "CALL FAILED: $($_.Exception.Message)"
      Write-Output $rec.texts[-1]
    }
    [void]$results.Add($rec)
    $results | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 (Join-Path $OutDir 'results.json')
  }
} finally {
  $results | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 (Join-Path $OutDir 'results.json')
  try { $p.StandardInput.Close() } catch {}
  if (-not $p.WaitForExit(3000)) { $p.Kill() }
  $e = $errTask.Result
  if ($e) { Write-Output ("STDERR (tail): " + $e.Substring([math]::Max(0, $e.Length - 1500))) }
}
