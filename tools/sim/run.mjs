// Headless playtest of a game: runs the real game scripts against a simulated Roblox (tools/sim/lib) and
// reports runtime errors, warnings, what the player sees, and the world layout. No Studio needed.
//
// Usage: node tools/sim/run.mjs <game> [--seconds 240] [--bots 2] [--mobile] [--debug "cmd1;cmd2"] [--out dir]
//                                     [--quiet] [--watchdog] [--no-render]
// Writes report.json, world.json, summary.md and <game>-{spawn,overview,map}.png (software render of the world).
// First run tools/luau/setup.sh and tools/sim/setup.sh once.
import fs from 'fs';
import { spawnSync } from 'child_process';
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SIM = path.join(ROOT, 'tools', 'sim');
const { Lua } = await import(pathToFileURL(path.join(ROOT, 'tools', 'luau', 'node_modules', '@luau-rs', 'luau', 'dist', 'direct-api.js')).href);

const argv = process.argv.slice(2);
const game = argv[0];
if (!game) {
  console.error('usage: node tools/sim/run.mjs <game> [--seconds N] [--bots N] [--mobile] [--debug "a;b"] [--out dir]');
  process.exit(2);
}
const opt = (name, def) => {
  const i = argv.indexOf('--' + name);
  return i >= 0 ? argv[i + 1] : def;
};
const flag = (name) => argv.includes('--' + name);
const seconds = Number(opt('seconds', 240));
const bots = Number(opt('bots', 2));
const mobile = flag('mobile');
const debugCmds = opt('debug', '');
const outDir = opt('out', path.join('/mnt/project-files/rbx5/sim', game));
const quiet = flag('quiet');
const watchdog = flag('watchdog');

function modules(...dirs) {
  const out = {};
  for (const d of dirs) {
    if (!fs.existsSync(d)) continue;
    for (const f of fs.readdirSync(d).sort()) {
      if (f.endsWith('.lua') && f.split('.').length === 2) out[f.slice(0, -4)] = path.join(d, f);
    }
  }
  return out;
}

function manifest() {
  const gdir = path.join(ROOT, 'games', game);
  if (!fs.existsSync(gdir)) throw new Error('no such game ' + gdir);
  const items = [];
  const add = (container, folder, name, cls, p) =>
    items.push({ container, folder, name, class: cls, source: fs.readFileSync(p, 'utf8'), path: path.relative(ROOT, p) });
  for (const [n, p] of Object.entries(modules(path.join(ROOT, 'kit', 'shared'), path.join(gdir, 'shared')))) add('ReplicatedStorage', 'Shared', n, 'ModuleScript', p);
  for (const [n, p] of Object.entries(modules(path.join(ROOT, 'kit', 'client'), path.join(gdir, 'client')))) add('ReplicatedStorage', 'ClientLib', n, 'ModuleScript', p);
  for (const [n, p] of Object.entries(modules(path.join(ROOT, 'kit', 'server'), path.join(gdir, 'server')))) add('ServerScriptService', 'Lib', n, 'ModuleScript', p);
  add('ServerScriptService', '', 'Main', 'Script', path.join(gdir, 'server', 'Main.server.lua'));
  add('StarterPlayer', '', 'Main', 'LocalScript', path.join(gdir, 'client', 'Main.client.lua'));
  const materials = [];
  for (const f of [path.join(ROOT, 'kit', 'materials.json'), path.join(gdir, 'materials.json')]) {
    if (!fs.existsSync(f)) continue;
    for (const [k, v] of Object.entries(JSON.parse(fs.readFileSync(f, 'utf8')))) {
      if (!k.startsWith('_') && v.color) materials.push({ name: k, base: v.base, color: v.color, normal: v.normal, roughness: v.roughness, metalness: v.metalness });
    }
  }
  const meta = fs.existsSync(path.join(gdir, 'game.json')) ? JSON.parse(fs.readFileSync(path.join(gdir, 'game.json'), 'utf8')) : {};
  return { items, materials, walkSpeed: meta.walkSpeed ?? 20, jumpPower: meta.jumpPower ?? 50, maxPlayers: meta.maxPlayers };
}

async function newVM() {
  const lua = await Lua.create();
  lua.loadLibraries('all');
  let deadline = Infinity;
  let timedOut = false;
  // The interrupt hook costs ~90x speed, so it is only on with --watchdog (use it when a run hangs).
  if (watchdog) lua.setInterruptHooks({
    mode: 'continuous',
    execution: (c) => {
      if (Date.now() > deadline && c.yieldable) {
        deadline = Infinity;
        timedOut = true;
        return 'yield';
      }
      return 'continue';
    },
  });
  const g = lua.globals;
  g.set('__arm', lua.createFunction((ms) => { deadline = Date.now() + Number(ms); }));
  g.set('__timedout', lua.createFunction(() => { const t = timedOut; timedOut = false; return t; }));
  g.set('__load', lua.createFunction((src, name, env) => {
    try {
      return lua.load(String(src), { name: String(name), environment: env ?? null });
    } catch (e) {
      return String(e.message || e);
    }
  }));
  g.set('__readFile', lua.createFunction((rel) => fs.readFileSync(path.join(SIM, String(rel)), 'utf8')));
  g.set('__writeOut', lua.createFunction((name, text) => { fs.mkdirSync(outDir, { recursive: true }); fs.writeFileSync(path.join(outDir, String(name)), String(text)); }));
  g.set('__stdout', lua.createFunction((text) => { if (!quiet) process.stdout.write(String(text) + '\n'); }));
  lua.addEventListener('print', (e) => { if (!quiet) process.stdout.write('[lua] ' + e.text + '\n'); });
  const boot = `
    local R = { G = setmetatable({}, { __index = _G }), TYPENAME = {} }
    local api = __load(__readFile("api_data.luau"), "=sim/api_data", nil)
    if type(api) ~= "function" then error(api) end
    R.API = api()
    local Sim
    for _, name in ipairs({ "core", "types", "util", "behaviors", "services", "sim" }) do
      local f = __load(__readFile("lib/" .. name .. ".luau"), "=sim/" .. name, nil)
      if type(f) ~= "function" then error(f) end
      local r = f(R)
      if name == "sim" then Sim = r end
    end
    _SIM = Sim
    return true
  `;
  lua.execute(boot);
  return lua;
}

const man = manifest();
const scenario = fs.readFileSync(process.env.SIM_SCENARIO || path.join(SIM, 'scenario.luau'), 'utf8'); // SIM_SCENARIO: custom script for debugging

async function runScenario(kind, dataJson) {
  const lua = await newVM();
  lua.globals.set('MANIFEST', JSON.stringify(man));
  lua.globals.set('OPTS', JSON.stringify({ kind, seconds, bots, mobile, debug: debugCmds, data: dataJson || null, game }));
  const t0 = Date.now();
  const res = lua.execute(scenario, { name: '=scenario' });
  return { out: JSON.parse(String(res[0])), ms: Date.now() - t0 };
}

const first = await runScenario('smoke');
const second = await runScenario('rejoin', first.out.data);
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ smoke: first.out.report, rejoin: second.out.report }, null, 1));
// texture preview colours (materials.json "preview") so the renderer can draw textured parts in their real colour
const world = JSON.parse(first.out.world);
world.variants = {};
for (const f of [path.join(ROOT, 'kit', 'materials.json'), path.join(ROOT, 'games', game, 'materials.json')]) {
  if (!fs.existsSync(f)) continue;
  for (const [k, v] of Object.entries(JSON.parse(fs.readFileSync(f, 'utf8')))) if (v && v.preview) world.variants[k] = v.preview.map((c) => c / 255);
}
fs.writeFileSync(path.join(outDir, 'world.json'), JSON.stringify(world));

// Human summary
const lines = [];
const rep = first.out.report;
const rep2 = second.out.report;
const fileOf = (msg) => {
  const m = String(msg).match(/^([\w.]+):(\d+):/);
  if (!m) return '';
  const it = man.items.find((i) => {
    const full = (i.container === 'StarterPlayer' ? 'Players.Tester.PlayerScripts' : i.container) + (i.folder ? '.' + i.folder : '') + '.' + i.name;
    return full === m[1] || m[1].endsWith('.' + i.name) && (i.folder ? m[1].includes(i.folder) : true);
  });
  return it ? ` (${it.path}:${m[2]})` : '';
};
lines.push(`# Sim playtest: ${game}`);
lines.push(`smoke run: ${rep.now.toFixed(0)} s simulated in ${(first.ms / 1000).toFixed(1)} s, rejoin run: ${(second.ms / 1000).toFixed(1)} s`);
lines.push(`errors: ${rep.errors.length} (+${rep2.errors.length} on rejoin), warnings: ${rep.warnings.length}, UI issues: ${Object.keys(first.out.uiIssues || {}).length}`);
for (const e of [...rep.errors, ...rep2.errors]) {
  lines.push(`\nERROR x${e.count} [${e.ctx} t=${Number(e.t).toFixed(1)}] ${e.msg}${fileOf(e.msg)}`);
  const tb = String(e.trace).split('\n').filter((l) => !l.includes('sim/') && l.trim()).slice(1, 7);
  for (const l of tb) lines.push('    ' + l.trim() + fileOf(l.trim()));
}
for (const w of rep.warnings) {
  lines.push(`WARN x${w.count} [${w.ctx} t=${Number(w.t).toFixed(1)}] ${String(w.msg).slice(0, 400)}`);
  const tb = String(w.trace || '').split('\n').filter((l) => l.trim() && !l.includes('sim/') && !l.includes('[C]') && !l.startsWith('stack')).slice(0, 4);
  for (const l of tb) lines.push('    ' + l.trim() + fileOf(l.trim()));
}
const issues = Object.entries(first.out.uiIssues || {});
lines.push(`\n## UI issues (${mobile ? 'phone 844x390' : 'desktop 1280x720'}): ${issues.length}`);
for (const [msg, n] of issues) lines.push(`- ${msg}${n > 1 ? ` (seen ${n}x)` : ''}`);
lines.push('\n## Phases');
for (const ph of first.out.phases) {
  lines.push(`\n### ${ph.name} (t=${ph.t.toFixed(1)})`);
  if (ph.info) lines.push(ph.info);
  if (ph.leaderstats) lines.push('leaderstats: ' + JSON.stringify(ph.leaderstats));
  if (ph.ui) lines.push('UI:\n' + ph.ui.map((x) => '  ' + x).join('\n'));
}
lines.push('\n## Rejoin (data persisted?)');
for (const ph of second.out.phases) {
  lines.push(`${ph.name}: ${ph.info || ''} leaderstats ${JSON.stringify(ph.leaderstats || {})}`);
}
lines.push('\n## Stats\n' + JSON.stringify(rep.stats));
lines.push('world: ' + JSON.stringify(first.out.worldStats));
lines.push('lighting: ' + JSON.stringify(first.out.lighting));
lines.push('\n## Asset ids used at runtime');
for (const [id, where] of Object.entries(rep.assets)) lines.push(`${id}: ${where}`);
lines.push('\n## Simulator notes (unmocked APIs)\n' + rep.notes.join('\n'));
lines.push('\n## Script output (first 150 lines)\n' + rep.log.slice(0, 150).join('\n'));
fs.writeFileSync(path.join(outDir, 'summary.md'), lines.join('\n'));
if (!flag('no-render')) {
  const r = spawnSync('python3', [path.join(SIM, 'render.py'), path.join(outDir, 'world.json'), path.join(outDir, game)], { encoding: 'utf8' });
  if (r.status !== 0) console.log('render failed: ' + (r.stderr || r.error));
}
console.log(lines.slice(0, 3).join('\n'));
console.log(`full summary: ${path.join(outDir, 'summary.md')}`);
process.exit(rep.errors.length + rep2.errors.length > 0 ? 1 : 0);
