# Rogue's Tale

A grimdark Godot 4.7 action RPG with a fixed angled camera like old-school
Final Fantasy field screens. **Playable in the browser** via GitHub Pages:
https://outerheavenx.github.io/godot-2.5D-rpg/

## The world

Emberfell sits at the centre. Five regions run out from it, and each one
stays shut until the guardian of the one before it falls. Nothing ever
re-locks: once a region is open it stays open, so any earlier region is
there to train in. There is no fast travel — the roads are the roads.

| Region | Opens when | Guardian |
|---|---|---|
| **Emberfell** (hub) | — | — |
| **The Southern Wilds** | open from the start | Vorgath, the Drowned King |
| **The Northern Wilds** | Vorgath falls | Morvain, the Frozen Heart |
| **The Ashen Highlands** | Morvain falls | Kael, the Ash Reaver |
| **The Mirefen** | Kael falls | Gholl, the Mire Horror |
| **The Sunken Vault** | Gholl falls | The Hollow Crown |

- **Emberfell** — the hub village. Enterable tavern, market, blacksmith
  forge and houses; Mira, Bram, Old Fen and Pip in the square. Iron
  portcullises stand in the north, west and east walls, and a slab of old
  stone caps the well. Walk up to a barred gate and the hero reads off it
  what still stands in the way.
- **The Southern Wilds** — skeletons, drowned husks, shadow bandits,
  slimes, wisps and jack-o'-lanterns. Each breed behaves differently:
  bandits break off when badly hurt, whistle up their friends and come
  back enraged; husks lurk submerged and burst out when you walk close;
  wisps drift just out of reach, luring the curious, before they turn.
  East of the wilds a bridge crosses the black water to **Vorgath's**
  island.
- **The Northern Wilds** — dead trees, jagged rocks and snow, with
  **Grimholt** at the far end (five enterable buildings, Elder Sella, Hob
  and Wren). Past the north wall, the **Frozen Arena** holds **Morvain**:
  crushing slam, shard volleys and an enraged second phase.
- **The Ashen Highlands** — burnt country west of the village, where
  nothing grows and embers still smoulder in the ash. **Ashfall Watch**
  holds out halfway along the road: a broken tower, a palisade and three
  survivors of the company sent up four years ago. Ash Reavers fight as a
  band — one that spots you calls in every reaver within earshot. At the
  end of the road, on a bowl of black glass, **Kael** closes the distance
  in a single rush and calls his two guards at half health. Beating him
  recruits **Ilsa** as a third companion.
- **The Mirefen** — a flooded plain east of the village with one raised
  causeway through it. Step off the stones and you are wading. The
  **Drowned Chapel** stands on the last dry island, three of its order
  still lighting lamps. Bog Wights drag whoever they hit in closer.
  Beyond the lich-gate, **Gholl** sinks into its pool twice a fight,
  untouchable while it is down there, and comes back up behind you with
  two of the drowned.
- **The Sunken Vault** — climb down the village well. An entry hall, a
  long gallery, four burial chambers and a throne room, lit by braziers
  somebody has been keeping alight. Crypt Shades blink through the dark
  instead of closing on foot. On the throne, **The Hollow Crown** reaches
  up through the floor, steps out of shadows behind you, drinks a share of
  every blow it lands, and wakes its court at half health.

Only the region the hero stands in is simulated. Walking out of one
clears its monsters and stops its scenery ticking; walking back in
repopulates it. Kill counts and quest progress carry across regardless.

## Systems

- **Combat** — real-time ATB melee with dodge i-frames, knockback, damage numbers, and hit effects. Enemies telegraph swings with a red `!`.
- **Magic** — Fireball, Heal, Frost Bolt (chills enemies), and Glacial Spike (quest reward from the Frozen Heart). Blue MP bar, regenerates over time. Morvain's ice shards chill the player, slowing movement.
- **Party** — Mira (ranged, mends the hero), Bram (melee) and Ilsa (the Warden of Ashfall, who holds the line) join through quests; two travel at a time, so the third is a choice. Companions follow in formation, fight, get knocked out and recover; enemies fight the whole party. They banter as you walk, take FOLLOW / STAY / ATTACK orders (V key or the PARTY tab), and the blacksmith forges better gear for them.
- **Quests** — a five-chapter main story, one per region (Vorgath → Morvain → Kael → Gholl → the Hollow Crown), plus side quests. Golden `!` / `?` markers, HUD objective tracker, QUESTS menu tab, persistent quest states. A story card plays when the game opens, again each time a guardian falls and the next region unseals, and once more at the end.
- **Shops** — market merchant (potions, capes, hoods), blacksmith (60 weapon tiers), tavern inns (Rest + Ale), Wren's Wares in Grimholt.
- **Progression** — 60 cape/hood color tiers and 60 weapon tiers with level gates, sold for gold. Level-ups grant HP, MP, attack, a full heal and a skill point. Wild foes scale with your level; dying costs a tenth of your gold.
- **Skills** — eight skills on the SKILLS tab, up to three ranks each: Swift Blade (faster ATB), Long Step (longer dodge), Twin Slash (second cut), Keen Edge (+attack), Iron Skin (less damage taken), Deep Well (mana regen), Arcane Focus (cheaper spells), Second Wind (heal on kill).
- **Interiors** — walk up to a building for the ENTER prompt; EXIT returns you outside. Dollhouse-style rooms, no ceilings.
- **Save** — three slots holding level, XP, gold, items, skills, position, quests, boss kills and party. CONTINUE and NEW GAME open a slot picker with a summary line per slot; autosave after quests, level-ups and every two minutes goes to the current slot; the SAVE tab can save to any slot. QUIT TO TITLE lives there too.
- **Weather** — snow thickens the further north you walk, ash falls through the highlands and stains the fog brown, mist hangs over the black water, and the fog grows heavier by the shore and colder in the north.
- **Potions** — 40% drop chance from foes, walk over to collect, heal 50 HP from the ITEMS tab or with the Q key / flask button.
- **Loot and crafting** — every foe has a drop table (bone shards, black pearls, stolen trinkets, slime gel, wisp essence, ember seeds, ash cinders, bog iron, grave dust; each guardian drops its own trophy). The blacksmith forges ethers, elixirs and nine accessories from reagents; merchants buy spare reagents. The ITEMS tab is a grid with use / wear, and one accessory is worn at a time (XP bonus, max HP, chill immunity, attack).
- **Minimap** — top-right, north-up, drawn from the layout tables: each region's own landmarks (buildings, walls, water, the causeway, the vault's rooms), plus foes, villagers, companions and a gold marker (or edge arrow with distance) for the tracked quest.
- **Music** — six loops that crossfade by region: Emberfell, the cold north, the highlands, the fen, the vault, and a drum track whenever a boss is near. Footsteps and enemy voice lines on aggro.

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
| Party order | V | D-pad up | PARTY tab |
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

Saves live in `user://savegame_1.cfg` to `_3.cfg` and settings in
`user://settings.cfg` (IndexedDB in the browser). An old single-slot save is
migrated into slot 1 on first run.

## Credits

- Characters, buildings and props: [KayKit](https://kaykit.itch.io/) (CC0)
- Sound effects: Kenney (CC0), plus two generated spell sounds
- Item icons: CraftPix
