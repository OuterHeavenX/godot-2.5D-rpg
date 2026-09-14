#!/bin/bash
# Export the game for Web and stamp cache-busting version strings into index.html.
# Godot's web export uses fixed filenames (index.js / index.wasm / index.pck),
# so without versioning, browsers keep serving the previous build from cache.
#
# Usage:  tools/export_web.sh            (uses `godot` from PATH)
#         GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/export_web.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
VERSION="$(date +%Y%m%d-%H%M%S)"

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "error: Godot binary not found ('$GODOT'). Set GODOT=/path/to/godot." >&2
	exit 1
fi

cd "$PROJECT_DIR"
mkdir -p docs
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" docs/index.html

# Bust caches: version the engine script and the game pack.
# (index.wasm is left unversioned on purpose: it only changes with the
# Godot version, and at ~38MB we want it cached.)
python3 tools/stamp_web_version.py "$VERSION"
