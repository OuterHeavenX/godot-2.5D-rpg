# 2.5D RPG — Classic Final Fantasy-style

A Godot 4.7 action RPG with a fixed angled camera like old-school Final Fantasy field screens. **Playable in the browser** via GitHub Pages: https://outerheavenx.github.io/godot-2.5D-rpg/

## The world

- **Emberfell** — the starting village. Enterable tavern, market, blacksmith forge, and houses. NPCs wander the square: Mira, Bram, Old Fen, Pip.
- **Southern wilderness** — skeletons, drowned husks, shadow bandits, slimes, wisps, and jack-o'-lanterns roam the wilds.
- **The black water** — a dark lake to the east with a wooden bridge to an island. **Vorgath the Drowned King** (boss) waits there.
- **Northern wilds** — harsher country past the north gate: dead trees, jagged rocks, snow-dusted pines, tougher 1.5x enemy variants.
- **Grimholt** — the northern town. All 5 buildings are enterable: tavern (Innkeeper Yrsa's *Frostbound Rest*), market, and 3 houses. NPCs: Elder Sella, Hob, and Wren (potion merchant).

## Systems

- **Combat** — real-time melee with dodge, knockback, damage numbers, and hit effects. Touch controls + keyboard.
- **Magic** — Fireball, Heal, Frost Bolt (chills enemies). Blue MP bar, regenerates over time. Cast via Spark button / C key.
- **Quests** — full quest system: main story chain (Emberfell → Vorgath → Grimholt) plus side quests. Golden `!` / `?` markers, HUD objective tracker, QUESTS menu tab, persistent quest states.
- **Shops** — market merchant (potions), blacksmith (60 weapon tiers), tavern inns (Rest + Ale), Wren's Wares in Grimholt.
- **Progression** — 60 cape/hood color tiers and 60 weapon tiers with level gates, sold for gold. Level-ups grant HP, attack, and full heal.
- **Interiors** — walk up to a building for the ENTER prompt; EXIT returns you outside. Dollhouse-style rooms, no ceilings.
- **Save** — full save persistence (level, XP, HP, gold, potions, position, quests, boss kills) with CONTINUE on the title screen.
- **Potions** — 40% drop chance from foes, walk over to collect, heal 50 HP from the ITEMS tab.

## Controls

- **Desktop**: WASD / arrows to move, Space to dodge, C to cast, E to interact
- **Touch**: virtual joystick (bottom-left), action buttons appear in context

## Project structure

```
godot-2.5D-rpg/
├── project.godot            # Main scene: src/world/main.tscn
├── export_presets.cfg       # Web export preset (exports to docs/)
├── src/
│   ├── player/              # Player controller, cape/hood/weapon progression
│   ├── enemy/               # Skeleton, boss, procedural monsters, spawn managers
│   ├── npc/                 # Villagers, shopkeeper, blacksmith (KayKit models)
│   ├── magic/               # Spells, projectiles
│   ├── quest/               # QuestDB + QuestMan autoload
│   ├── ui/                  # HUD, JRPG menu, dialogue, shop, story intro
│   ├── world/               # Village, wilderness, island, Grimholt, interiors, doors
│   ├── save/                # Save/load system
│   ├── fx/                  # Hit effects, vignette
│   └── audio/               # Music + SFX
└── docs/                    # Web export (GitHub Pages serves this)
```

## Running

- **In the editor**: open the project in Godot 4.7 and press Play.
- **In a browser**: open `docs/index.html` (must be served over HTTP).
- **Headless check**: `godot --headless --path .`
- **Re-export web**: `godot --headless --path . --export-release "Web" docs/index.html`
