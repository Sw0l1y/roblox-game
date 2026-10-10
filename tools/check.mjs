// Type-check a game's scripts with Luau's own type checker (WASM) and Roblox's API types, no Studio needed.
// Usage: node tools/check.mjs <game> [--all]   (run tools/luau/setup.sh once first)
// Mirrors build.py's layout. Instance-path requires are rewritten to module names, and Instance.new("X") /
// GetService("X") get casts to their class (luau-lsp does this with magic functions) so typos in property and
// method names are caught. Errors about the generic `Instance` type (FindFirstChild results etc.) are dropped as
// noise unless --all is given. Exits 1 when errors remain.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pathToFileURL } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const LUAU = path.join(ROOT, 'tools', 'luau');
const { Analysis } = await import(pathToFileURL(path.join(LUAU, 'node_modules', '@luau-rs', 'luau', 'dist', 'analysis.js')).href);

const game = process.argv[2];
const showAll = process.argv.includes('--all');
if (!game) {
  console.error('usage: node tools/check.mjs <game> [--all]');
  process.exit(2);
}
const gdir = path.join(ROOT, 'games', game);

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

// Replace require(<instance path>) with require("<last segment>"), keeping every line in place.
function rewriteRequires(src) {
  let out = '';
  let i = 0;
  while (true) {
    const j = src.indexOf('require(', i);
    if (j < 0) { out += src.slice(i); break; }
    out += src.slice(i, j);
    let depth = 0, k = j + 'require'.length;
    for (; k < src.length; k++) {
      if (src[k] === '(') depth++;
      else if (src[k] === ')') { depth--; if (depth === 0) break; }
    }
    const inner = src.slice(j + 8, k);
    let m = inner.match(/WaitForChild\(\s*"(\w+)"[^)]*\)\s*(?:::\s*\w+)?\s*$/) || inner.match(/FindFirstChild\(\s*"(\w+)"\s*\)\s*(?:::\s*\w+)?\s*$/) || inner.match(/\.(\w+)\s*(?:::\s*\w+)?\s*$/);
    if (m && !inner.trim().startsWith('"')) {
      const newlines = (inner.match(/\n/g) || []).length;
      out += `require("${m[1]}")` + '\n'.repeat(newlines);
    } else {
      out += src.slice(j, k + 1);
    }
    i = k + 1;
  }
  return out;
}

const defsText = fs.readFileSync(path.join(LUAU, 'roblox.d.luau'), 'utf8');
const creatable = new Set(JSON.parse(defsText.split('\n', 1)[0].slice('--#METADATA#'.length)).CREATABLE_INSTANCES);
const services = new Set(JSON.parse(defsText.split('\n', 1)[0].slice('--#METADATA#'.length)).SERVICES);

function castMagic(src) {
  // Enum.Foo used as a type (not Enum.Foo.Bar or Enum.Foo:Method) -> the defs' EnumFoo type.
  src = src.replace(/\bEnum\.(\w+)(?![\w.:\[])/g, 'Enum$1');
  src = src.replace(/Instance\.new\(\s*"(\w+)"(\s*,[^()]*)?\)/g, (all, cls) => (creatable.has(cls) ? `(${all} :: ${cls})` : all));
  src = src.replace(/(game|[A-Za-z_]\w*):GetService\(\s*"(\w+)"\s*\)/g, (all, _o, cls) => (services.has(cls) ? `(${all} :: ${cls})` : all));
  return src;
}

const sets = {
  shared: modules(path.join(ROOT, 'kit', 'shared'), path.join(gdir, 'shared')),
  client: modules(path.join(ROOT, 'kit', 'client'), path.join(gdir, 'client')),
  server: modules(path.join(ROOT, 'kit', 'server'), path.join(gdir, 'server')),
};
const files = {};
for (const s of Object.values(sets)) Object.assign(files, s);
const scripts = {};
for (const [name, rel] of [['MainServer', 'server/Main.server.lua'], ['MainClient', 'client/Main.client.lua']]) {
  const p = path.join(gdir, rel);
  if (fs.existsSync(p)) scripts[name] = p;
}

const a = await Analysis.create({ mode: 'strict', lint: true });
a.addDefinition('roblox', defsText);
for (const [name, p] of Object.entries(files)) a.setModule(name, castMagic(rewriteRequires(fs.readFileSync(p, 'utf8'))), 'module');
for (const [name, p] of Object.entries(scripts)) a.setModule(name, castMagic(rewriteRequires(fs.readFileSync(p, 'utf8'))), 'script');

const NOISE = [
  /type 'Instance'/,                      // FindFirstChild/WaitForChild results are plain Instances
  /external type 'Instance'/,
  /Unknown require/,
  /could not be converted into 'Instance/,
  /^Type 'Instance' could not be converted/,
];
const LINT_WARN_ONLY = true;
const all = { ...files, ...scripts };
let errors = 0, warnings = 0, hidden = 0;
const results = a.checkModules(Object.keys(all));
const seen = new Set();
for (const { result } of results) {
  for (const d of result.diagnostics) {
    const file = all[d.module] ? path.relative(ROOT, all[d.module]) : d.module;
    const key = `${file}:${d.location.begin.line}:${d.message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const isError = d.severity === 'error' && !(LINT_WARN_ONLY && d.kind === 'lint');
    if (!showAll && isError && NOISE.some((r) => r.test(d.message))) { hidden++; continue; }
    if (!showAll && !isError && /is never used|LocalUnused|ImportUnused|FunctionUnused/.test(d.message)) { hidden++; continue; }
    if (isError) errors++; else warnings++;
    console.log(`${isError ? 'ERROR' : 'warn '} ${file}:${d.location.begin.line + 1}: ${d.message.replace(/\s+/g, ' ').slice(0, 300)}`);
  }
}
console.log(`\n${game}: ${errors} errors, ${warnings} warnings (${hidden} generic-Instance/unused notes hidden; --all to show)`);
process.exit(errors ? 1 : 0);
