# Rogue's Tale

A grimdark 2.5D action RPG built in Godot 4.7 with a fixed, angled camera in
the style of old-school Final Fantasy field screens. **Playable in the
browser** from `docs/index.html` (hosted with GitHub Pages).

You play a hooded rogue who arrives in the village of Emberfell at dusk. The
dead rise in the southern wilds; something old and crowned waits on an island
in the black water to the east.

## Features

- Real-time ATB combat: attack, dodge with i-frames, sprint. Enemies
  telegraph their swings with a red `!`.
- Magic: Fireball, Frost Bolt (slows) and Heal, with mana that regenerates.
- Skeletons that scale with your level, plus a boss: Vorgath, the Drowned King.
- XP and levels, gold, potions, and a 60-step cape / hood / weapon ladder
  bought at the market and the blacksmith.
- Enterable buildings (market, tavern, blacksmith, houses) with shopkeepers
  and villagers who wander, talk and hand out quests.
- A four-quest main story with an opening and an ending scene, plus a
  side-quest chain. HUD tracker and a QUESTS tab.
- Save / continue with autosave after quests and level-ups.
- Keyboard, gamepad and touch controls (virtual joystick and buttons).

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Joystick |
| Attack | Space | X | Sword button |
| Dodge | Shift | B | Roll button |
| Cast spell | C | Y | Spark button |
| Sprint | F | LB | Fast button |
| Potion | Q | RB | Flask button |
| Talk / enter / next | E or Enter | A | Tap the prompt |
| Menu | Esc or Tab | Start | Top-right button |

Up is north (-Z), like classic Final Fantasy: the camera is angled but
movement stays world-aligned.

## Project layout

```
project.godot            Project settings, input map, autoloads
export_presets.cfg       Web export preset (exports to docs/)
src/
  player/                Player body, movement, combat, stats (player.gd)
  camera/                Fixed-angle follow camera
  enemy/                 Skeleton AI, boss, spawner
  magic/                 Spell table and projectiles
  item/                  Equipment ladder, potion drops
  npc/                   Villagers, shopkeeper, blacksmith
  quest/                 Quest definitions (quest_db.gd) and QuestMan autoload
  save/                  Save file helpers and autosave
  ui/                    HUD, menus, dialogue, shop, story panels, touch UI
  world/                 Village layout, buildings, props, walls, wilderness,
                         lake + boss island, interiors, doors
  audio/                 AudioMan autoload, SFX, music
  fx/                    Hit particles, damage numbers, vignette
assets/                  Icon, splash, item icons
tools/                   Export script and helpers
docs/                    Web export (ignored by the editor via .gdignore)
```

The world is built procedurally at startup from the data tables in
`src/world/village_layout.gd`, `src/world/props.gd` and friends. Quests are
plain dictionaries in `src/quest/quest_db.gd`.

## Running

- **Editor**: open the project in Godot 4.7 and press Play.
- **Browser**: serve `docs/` over HTTP (GitHub Pages does this).
- **Web export**: `tools/export_web.sh` (uses `godot` from PATH, or set
  `GODOT=/path/to/binary`). It exports and stamps a cache-busting version
  into `docs/index.html`; commit the result.
- **CI**: `.github/workflows/web-export.yml` exports on every push to `main`
  and deploys to GitHub Pages. Set the Pages source to "GitHub Actions" for
  that to take effect.

Saves live in `user://savegame.cfg` (IndexedDB in the browser). One slot;
starting a new game overwrites it at the first autosave.

## Credits

- Characters, buildings and props: [KayKit](https://kaykit.itch.io/) (CC0)
- Sound effects: Kenney (CC0), plus two generated spell sounds
- Item icons: CraftPix
