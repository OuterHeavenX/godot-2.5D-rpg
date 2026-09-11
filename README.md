# 2.5D RPG — Classic Final Fantasy-style

A Godot 4.7 starter for a 2.5D RPG with a fixed angled camera like old-school Final Fantasy field screens. **Playable in the browser** (see `docs/index.html`, hosted via GitHub Pages).

## Project structure

```
godot-2.5D-rpg/
├── project.godot            # Project settings (main scene: src/world/main.tscn)
├── export_presets.cfg       # Web export preset (exports to docs/)
├── icon.svg
├── src/
│   ├── player/
│   │   ├── player.tscn      # Player scene (CharacterBody3D)
│   │   └── player.gd        # Movement: keyboard + virtual joystick
│   ├── camera/
│   │   └── camera_rig.gd    # Classic FF-style follow camera
│   ├── ui/
│   │   ├── touch_controls.tscn  # Touch controls layer (CanvasLayer)
│   │   ├── touch_controls.gd    # Shows controls on touch devices
│   │   └── virtual_joystick.gd  # On-screen joystick (touch + mouse)
│   └── world/
│       └── main.tscn        # Main scene: world, camera, player, touch UI
└── docs/                    # Web export (playable index.html)
```

## Camera

The `CameraRig` holds the camera at offset (0, 12, 10), looking down ~50° at FOV 40 — the tilted-down view from FF7/FF9 field screens. It smoothly follows the player on X/Z.

Tweak in `src/world/main.tscn`:
- `camera_offset` on the CameraRig — higher Y = more top-down
- `fov` on the Camera3D — lower = flatter, more orthographic feel

## Controls

- **Desktop**: WASD / arrow keys (Up = north, like classic FF)
- **Touch**: on-screen virtual joystick (bottom-left, appears automatically on touch devices)

## Running

- **In the editor**: open the project in Godot 4.7 and press Play.
- **In a browser**: open `docs/index.html` (needs to be served over HTTP, e.g. via GitHub Pages).
- **Headless check**: `godot --headless --path .`
- **Re-export web**: `godot --headless --path . --export-release "Web" docs/index.html`

## Next steps

- Replace the capsule with billboarded 2D sprites (Sprite3D) for a true 2.5D look
- NPCs + dialogue system
- Turn-based battle scene
- Larger village / tile-based map
