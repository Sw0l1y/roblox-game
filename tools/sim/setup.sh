#!/bin/sh
# One-time setup for tools/sim/run.mjs: builds api_data.luau (classes, properties, enums) from the Roblox API dump.
# Needs tools/luau/setup.sh first (the Luau runtime). render.py needs python3 with numpy + pillow.
set -e
cd "$(dirname "$0")"
if [ ! -f api_data.luau ]; then
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/full.json" https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
  python3 gen_api.py "$tmp/full.json"
  rm -rf "$tmp"
fi
echo "sim ready"
