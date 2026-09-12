class_name Equipment
## Cape and hood equipment: 60 levels each, 6 colors x 10 shades.
## Colors represent strength (weak to strong). Within a color,
## shades go from lightest (level 1 of that color) to darkest (level 10).

const MAX_LEVEL := 60
const SHADES_PER_COLOR := 10

# Colors from weakest to strongest.
const COLORS := [
	{"name": "Slate", "base": Color(0.55, 0.56, 0.60)},   # Gray
	{"name": "Forest", "base": Color(0.22, 0.52, 0.28)},  # Green
	{"name": "Ocean", "base": Color(0.20, 0.42, 0.72)},   # Blue
	{"name": "Royal", "base": Color(0.52, 0.28, 0.72)},   # Purple
	{"name": "Blood", "base": Color(0.72, 0.16, 0.16)},   # Red
	{"name": "Radiant", "base": Color(0.88, 0.68, 0.22)}, # Gold
]

## Get the color for a level (1-60). Level 0 = default (black/red).
static func get_color(level: int) -> Color:
	if level <= 0:
		return Color(0.015, 0.015, 0.015)  # Default black
	if level > MAX_LEVEL:
		level = MAX_LEVEL
	var color_idx := (level - 1) / SHADES_PER_COLOR  # 0-5
	var shade := (level - 1) % SHADES_PER_COLOR + 1  # 1-10
	var base: Color = COLORS[color_idx]["base"]
	# Shade 1 = lightest, shade 10 = darkest (base color).
	# Lighten by (10 - shade) * 0.07.
	return base.lightened((SHADES_PER_COLOR - shade) * 0.07)

## Get the color name for a level (e.g., "Blood Red", "Light Slate").
static func get_color_name(level: int) -> String:
	if level <= 0:
		return "Worn"
	if level > MAX_LEVEL:
		level = MAX_LEVEL
	var color_idx := (level - 1) / SHADES_PER_COLOR
	var shade := (level - 1) % SHADES_PER_COLOR + 1
	var base_name: String = COLORS[color_idx]["name"]
	if shade <= 3:
		return "Light " + base_name
	elif shade >= 8:
		return "Dark " + base_name
	else:
		return base_name

## Cape: +Max HP. 5 HP per level.
static func cape_hp_bonus(level: int) -> float:
	return float(level) * 5.0

## Hood: +Attack damage. 0.3 per level.
static func hood_attack_bonus(level: int) -> float:
	return float(level) * 0.3

## Price for the next level. 100G per level.
static func upgrade_price(current_level: int) -> int:
	return (current_level + 1) * 100

## Player level required to buy a cape/hood level.
## Each color tier needs 10 more player levels:
## Slate (1-10): any level, Forest (11-20): Lv.10, Ocean: Lv.20,
## Royal: Lv.30, Blood: Lv.40, Radiant (51-60): Lv.50.
static func required_player_level(level: int) -> int:
	if level <= 0:
		return 0
	var color_idx := (level - 1) / SHADES_PER_COLOR  # 0-5
	return color_idx * 10

## Display name for a cape at a level.
static func cape_name(level: int) -> String:
	if level <= 0:
		return "Worn Cape"
	return "%s Cape Lv.%d" % [get_color_name(level), level]

## Display name for a hood at a level.
static func hood_name(level: int) -> String:
	if level <= 0:
		return "Worn Hood"
	return "%s Hood Lv.%d" % [get_color_name(level), level]

# Weapon types by color tier (weakest to strongest).
const WEAPON_TYPES := [
	"Dagger",       # Slate (1-10)
	"Short Sword",  # Forest (11-20)
	"Long Sword",   # Ocean (21-30)
	"Knight's Blade", # Royal (31-40)
	"Bloodbrand",   # Blood (41-50)
	"Dawnbringer",  # Radiant (51-60)
]

## Display name for a weapon at a level.
static func weapon_name(level: int) -> String:
	if level <= 0:
		return "Rusty Dagger"
	if level > MAX_LEVEL:
		level = MAX_LEVEL
	var color_idx := (level - 1) / SHADES_PER_COLOR
	return "%s %s Lv.%d" % [get_color_name(level), WEAPON_TYPES[color_idx], level]

## Weapon: +Attack damage. 0.5 per level.
static func weapon_attack_bonus(level: int) -> float:
	return float(level) * 0.5

## Price for the next weapon level. 150G per level.
static func weapon_upgrade_price(current_level: int) -> int:
	return (current_level + 1) * 150
