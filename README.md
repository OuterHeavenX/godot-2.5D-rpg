# Rogue's Tale

A grimdark Godot 4.7 action RPG with a fixed angled camera like old-school
Final Fantasy field screens. **Playable in the browser** via GitHub Pages:
https://outerheavenx.github.io/godot-2.5D-rpg/

## The world

- **Emberfell** — the starting village. Enterable tavern, market, blacksmith forge, and houses. NPCs wander the square: Mira, Bram, Old Fen, Pip.
- **Southern wilderness** — skeletons, drowned husks, shadow bandits, slimes, wisps, and jack-o'-lanterns roam the wilds.
- **The black water** — a dark lake to the east with a wooden bridge to an island. **Vorgath the Drowned King** (boss) waits there.
- **Northern wilds** — harsher country past the north gate: dead trees, jagged rocks, snow-dusted pines, tougher 1.5x enemy variants.
- **Grimholt** — the northern town. All 5 buildings are enterable: tavern (Innkeeper Yrsa's *Frostbound Rest*), market, and 3 houses. NPCs: Elder Sella, Hob, and Wren (potion merchant). Wild things are kept out of the square.
- **The Frozen Arena** — past the far-north gate: a ringed ice arena where **Morvain, the Frozen Heart** (ice-golem boss) waits. Crushing slam, chilling shard volleys, and an enraged phase 2.

## Systems

- **Combat** — real-time ATB melee with dodge i-frames, knockback, damage numbers, and hit effects. Enemies telegraph swings with a red `!`.
- **Magic** — Fireball, Heal, Frost Bolt (chills enemies), and Glacial Spike (quest reward from the Frozen Heart). Blue MP bar, regenerates over time. Morvain's ice shards chill the player, slowing movement.
- **Party** — Mira (ranged, mends the hero) and Bram (melee) join through side quests. Companions follow in formation, fight, get knocked out and recover; enemies fight the whole party.
- **Quests** — main story chain (Emberfell → Vorgath → Grimholt → Morvain) plus side quests. Golden `!` / `?` markers, HUD objective tracker, QUESTS menu tab, persistent quest states. Story scenes open the game, mark chapter two, and close it.
- **Shops** — market merchant (potions, capes, hoods), blacksmith (60 weapon tiers), tavern inns (Rest + Ale), Wren's Wares in Grimholt.
- **Progression** — 60 cape/hood color tiers and 60 weapon tiers with level gates, sold for gold. Level-ups grant HP, MP, attack, a full heal and a skill point. Wild foes scale with your level; dying costs a tenth of your gold.
- **Skills** — eight skills on the SKILLS tab, up to three ranks each: Swift Blade (faster ATB), Long Step (longer dodge), Twin Slash (second cut), Keen Edge (+attack), Iron Skin (less damage taken), Deep Well (mana regen), Arcane Focus (cheaper spells), Second Wind (heal on kill).
- **Interiors** — walk up to a building for the ENTER prompt; EXIT returns you outside. Dollhouse-style rooms, no ceilings.
- **Save** — one slot with level, XP, gold, potions, position, quests, boss kills and party. CONTINUE on the title screen, autosave after quests, level-ups and every two minutes, QUIT TO TITLE on the SAVE tab.
- **Potions** — 40% drop chance from foes, walk over to collect, heal 50 HP from the ITEMS tab or with the Q key / flask button.
- **Loot and crafting** — every foe has a drop table (bone shards, black pearls, stolen trinkets, slime gel, wisp essence, ember seeds; the bosses drop their crown and heart shard). The blacksmith forges ethers, elixirs and four accessories from reagents; merchants and Wren buy spare reagents. The ITEMS tab is a grid with use / wear, and one accessory is worn at a time (XP bonus, max HP, chill immunity, attack).
- **Minimap** — top-right, north-up, drawn from the layout tables: buildings, walls, water, foes, villagers, companions and a gold marker (or edge arrow with distance) for the tracked quest.
- **Music** — three loops that crossfade by region: Emberfell, the cold north, and a drum track whenever a boss is near. Footsteps and enemy voice lines on aggro.

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

## Project structure

```
godot-2.5D-rpg/
├── project.godot            # Main scene, input map, autoloads
├── export_presets.cfg       # Web export preset (exports to docs/)
├── src/
│   ├── player/              # Player controller, cape/hood/weapon progression
│   ├── enemy/               # Skeleton, bosses, procedural monsters, spawn managers
│   ├── party/               # PartyMan autoload + companion AI
│   ├── npc/                 # Villagers, shopkeeper, blacksmith (KayKit models)
│   ├── magic/               # Spells, projectiles
│   ├── quest/               # QuestDB + QuestMan autoload
│   ├── ui/                  # HUD, JRPG menu, dialogue, shop, story panels, touch UI
│   ├── world/               # Village, wilderness, island, Grimholt, arena, interiors, doors
│   ├── save/                # Save/load system + autosave
│   ├── fx/                  # Hit effects, vignette
│   └── audio/               # Music + SFX
├── tools/                   # Export script and version stamper
└── docs/                    # Web export (GitHub Pages serves this; .gdignore keeps the editor out)
```

The world is built procedurally at startup from data tables
(`src/world/village_layout.gd`, `src/world/grimholt.gd`, the spawner
population tables). Quests are plain dictionaries in `src/quest/quest_db.gd`.

## Running

- **In the editor**: open the project in Godot 4.7 and press Play.
- **In a browser**: serve `docs/` over HTTP (GitHub Pages does this).
- **Web export**: `tools/export_web.sh` (uses `godot` from PATH, or set
  `GODOT=/path/to/binary`). It exports and stamps a cache-busting version
  into `docs/index.html`; commit the result.
- **Tests**: `godot --headless --path . -s tests/run_tests.gd` boots the real
  scene and drives the quest chain, both bosses, party, save round-trip, death
  and doors (50 checks).
- **CI**: `.github/workflows/web-export.yml` boots the game headless, runs the
  tests, exports, screenshots the HUD in Chromium (artifact `hud-screenshot`),
  and deploys to GitHub Pages on every push to `main`.

Saves live in `user://savegame.cfg` (IndexedDB in the browser). One slot;
starting a new game overwrites it at the first autosave.

## Credits

- Characters, buildings and props: [KayKit](https://kaykit.itch.io/) (CC0)
- Sound effects: Kenney (CC0), plus two generated spell sounds
- Item icons: CraftPix
