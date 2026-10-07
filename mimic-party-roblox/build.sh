#!/usr/bin/env bash
# Builds the place file. Needs rojo (https://rojo.space) on PATH.
set -euo pipefail
cd "$(dirname "$0")"
rojo build -o MimicParty.rbxlx
echo "→ MimicParty.rbxlx — ábrelo con Roblox Studio y publicá."
