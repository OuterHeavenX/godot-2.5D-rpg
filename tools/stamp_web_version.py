#!/usr/bin/env python3
"""Stamp a cache-busting version into docs/index.html after a web export.

Godot's web export always writes index.js / index.pck. Browsers cache those
by name, so returning players would keep the previous build. This rewrites
the loader to request index.js?v=VERSION and index.pck?v=VERSION.
Safe to run more than once: an existing stamp is replaced.
"""
import re
import sys
from pathlib import Path

version = sys.argv[1] if len(sys.argv) > 1 else "dev"
path = Path(__file__).resolve().parent.parent / "docs" / "index.html"
html = path.read_text()

# 1. Version the engine loader script.
html = re.sub(r'<script src="index\.js(?:\?v=[^"]*)?">',
              f'<script src="index.js?v={version}">', html)

# 2. Tell the engine to load a versioned main pack (cache-busted game content).
html = re.sub(r'"executable":"index"(?:,"mainPack":"index\.pck\?v=[^"]*")?',
              f'"executable":"index","mainPack":"index.pck?v={version}"', html)

# 3. Keep the loading progress bar accurate for the versioned pack name.
html = re.sub(r',"index\.pck\?v=[^"]*":\d+', "", html)
m = re.search(r'"index\.pck":(\d+)', html)
if m:
    html = html.replace(f'"index.pck":{m.group(1)}',
                        f'"index.pck":{m.group(1)},"index.pck?v={version}":{m.group(1)}', 1)

path.write_text(html)
print(f"stamped {path.name} with v={version}")
