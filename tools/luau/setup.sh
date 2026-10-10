#!/bin/sh
# One-time setup for tools/check.mjs: Luau (WASM) from npm + Roblox type definitions from luau-lsp,
# patched so the WASM type checker accepts them (the Enum global is too big for its limits).
set -e
cd "$(dirname "$0")"
[ -d node_modules/@luau-rs/luau ] || npm install --silent
if [ ! -f roblox.d.luau ]; then
  curl -sSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau
  python3 - <<'PY'
s = open("globalTypes.d.luau").read()
s = s.replace("} & { GetEnums: (self: ENUM_LIST) -> { Enum } }", "\tGetEnums: (self: any) -> { Enum },\n}")
s = s.replace("declare Enum: ENUM_LIST", "declare Enum: any")
open("roblox.d.luau", "w").write(s)
PY
  rm globalTypes.d.luau
fi
echo "luau tools ready"
