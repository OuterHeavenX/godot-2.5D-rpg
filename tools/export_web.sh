#!/bin/bash
# Export the game for Web and stamp cache-busting version strings into index.html.
# Godot's web export uses fixed filenames (index.js / index.wasm / index.pck),
# so without versioning, browsers keep serving the previous build from cache.
set -euo pipefail

PROJECT_DIR="$HOME/workspace/your_files/godot-25d-rpg"
GODOT="$HOME/workspace/tools/godot/Godot_v4.7.2-stable_linux.x86_64"
VERSION="$(date +%Y%m%d-%H%M%S)"

cd "$PROJECT_DIR"
mkdir -p docs
"$GODOT" --headless --path . --export-release "Web" docs/index.html

# Bust caches: version the engine script and the game pack.
# (index.wasm is left unversioned on purpose: it only changes with the
# Godot version, and at 38MB we want it cached.)
python3 - "$VERSION" <<'EOF'
import re, sys

version = sys.argv[1]
p = "docs/index.html"
html = open(p).read()

# 1. Version the engine loader script.
html = html.replace('<script src="index.js">',
                    f'<script src="index.js?v={version}">')

# 2. Tell the engine to load a versioned main pack (cache-busted game content).
html = html.replace('"executable":"index"',
                    f'"executable":"index","mainPack":"index.pck?v={version}"')

# 3. Keep the loading progress bar accurate for the versioned pack name.
m = re.search(r'"index\.pck":(\d+)', html)
if m:
    html = html.replace(f'"index.pck":{m.group(1)}',
                        f'"index.pck":{m.group(1)},"index.pck?v={version}":{m.group(1)}')

open(p, "w").write(html)
print(f"stamped index.html with v={version}")
EOF
