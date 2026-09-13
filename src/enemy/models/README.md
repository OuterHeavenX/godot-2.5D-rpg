# Enemy Models

Unwired model stash — future enemies, saved here for later use.
Nothing in the subfolders below is referenced by the game yet.

Each stash subfolder carries a `.gdignore`, so Godot skips it: the models
are not imported and not packed into the exported build. The web download
would otherwise carry 25MB of models nobody can see. **To wire one up,
delete that folder's `.gdignore` first, then re-import.**

All KayKit assets are **CC0** (free for personal and commercial use,
no attribution required). Each subfolder carries its pack's LICENSE.txt.

## jackolantern.gltf (+ .bin, halloweenbits_texture.png)
Source: KayKit Halloween Bits pack
https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0
Used for the Jack-o'-lantern enemy (wired in `../jackolantern.gd`).

## skeletons/ — KayKit Character Pack: Skeletons
https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0
- `Skeleton_Mage.glb` — robed skeleton caster (self-contained: mesh + rig + 90+ anims)
- `Skeleton_Rogue.glb` — nimble skeleton skirmisher (self-contained)
- `Skeleton_Staff / Blade / Axe / Crossbow / Shield_Large_A / Quiver` (.gltf + .bin) — weapon attachments
- `skeleton_texture.png` — shared gradient texture for the .gltf weapons
- (Minion + Warrior already wired in `../skeleton.tscn`)

## adventurers/ — KayKit Character Pack: Adventures
https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- `Barbarian.glb` — bruiser enemy (self-contained)
- `Knight.glb` — armored enemy, dark-knight material (self-contained)
- `Mage.glb` — enemy spellcaster (self-contained)
- `Rogue.glb` — bandit/skirmisher enemy (self-contained)
- Weapons (.gltf + .bin): `sword_1handed`, `sword_2handed`, `axe_1handed`,
  `axe_2handed`, `dagger`, `staff`, `wand`, `crossbow_1handed`,
  `shield_spikes`, `spellbook_open`
- `*_texture.png` — per-character textures, also referenced by the weapon .gltfs

## halloween/ — KayKit Halloween Bits (extra)
https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0
- `pumpkin_yellow_jackolantern` (.gltf + .bin) — yellow variant of the wired enemy
- `pumpkin_orange_small`, `pumpkin_yellow_small`, `pumpkin_yellow` — pumpkin variants
- `skull`, `ribcage`, `coffin` (.gltf + .bin) — spooky props / enemy dressing
- `halloweenbits_texture.png` — shared texture for the .gltf files

## Wiring notes (for later)
- The `.glb` characters are fully rigged/animated on KayKit's shared
  `Rig_Medium` skeleton — same rig family as the wired skeletons, so the
  existing enemy animation code should largely carry over.
- The `.gltf` + `.bin` weapons/props need their sibling texture `.png`
  in the same folder (already placed).
