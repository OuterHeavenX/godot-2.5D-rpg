class_name Regions
extends RefCounted
## The hub-and-spoke map of the world.
##
## Emberfell sits at the centre. Four spokes run out from its gates and a
## fifth drops through the village well. Each spoke is sealed until the
## boss of the previous one falls, and once a spoke is open it stays open
## for good — the hero can walk back to any earlier region to train.
##
##   town   Emberfell, the hub                 always open
##   south  the Southern Wilds   -> Vorgath    always open
##   north  the Northern Wilds   -> Morvain    opens when Vorgath falls
##   west   the Ashen Highlands  -> Kael       opens when Morvain falls
##   east   the Mirefen          -> Gholl      opens when Kael falls
##   deep   the Sunken Vault     -> the Crown  opens when Gholl falls

const TOWN := "town"
const SOUTH := "south"
const NORTH := "north"
const WEST := "west"
const EAST := "east"
const DEEP := "deep"

## The spokes in the order the story opens them.
const ORDER := [SOUTH, NORTH, WEST, EAST, DEEP]

## Boss that must fall before a region opens ("" = open from the start).
const UNLOCKED_BY := {
	TOWN: "",
	SOUTH: "",
	NORTH: "vorgath",
	WEST: "morvain",
	EAST: "kael",
	DEEP: "gholl",
}

## Banner shown when the hero crosses into a region.
const NAMES := {
	TOWN: "EMBERFELL",
	SOUTH: "THE SOUTHERN WILDS",
	NORTH: "THE NORTHERN WILDS",
	WEST: "THE ASHEN HIGHLANDS",
	EAST: "THE MIREFEN",
	DEEP: "THE SUNKEN VAULT",
}

## Music track per region (see AudioMan.MUSIC).
const MUSIC := {
	TOWN: "village",
	SOUTH: "village",
	NORTH: "north",
	WEST: "ash",
	EAST: "mire",
	DEEP: "vault",
}

## Told to the hero at a sealed gate.
const SEALED_LINES := {
	NORTH: "The north gate is barred. Vorgath still reigns in the black water.",
	WEST: "The west gate is barred. Morvain still walks the northern ice.",
	EAST: "The east gate is barred. Kael still holds the highlands.",
	DEEP: "The well is capped with old stone. Something below is still awake.",
}

## Rough extent of each region in the XZ plane, used to decide which
## scenery stays awake. Generous on purpose: scenery wakes before the
## hero can see it.
const BOUNDS := {
	TOWN: Rect2(-32, -32, 64, 64),
	SOUTH: Rect2(-32, 28, 104, 50),
	NORTH: Rect2(-32, -302, 64, 274),
	WEST: Rect2(-302, -32, 274, 64),
	EAST: Rect2(28, -32, 274, 64),
	DEEP: Rect2(-64, 176, 128, 208),
}

## Where a spoke begins, for gates and travel prompts.
const GATES := {
	NORTH: Vector3(0, 0, -30),
	WEST: Vector3(-30, 0, 0),
	EAST: Vector3(30, 0, 0),
	SOUTH: Vector3(0, 0, 30),
	DEEP: Vector3(0, 0, 7),
}

## Interiors are built far to the east, out of sight of the map proper.
const INTERIOR_X := 400.0

## Which region a world position belongs to.
static func at(x: float, z: float) -> String:
	if x > INTERIOR_X:
		return TOWN  # Inside a building: the hub, as far as the world cares.
	if z > 150.0:
		return DEEP
	if z > 30.0:
		return SOUTH
	if z < -30.0:
		return NORTH
	if x < -30.0:
		return WEST
	if x > 30.0:
		return EAST
	return TOWN

static func at_pos(p: Vector3) -> String:
	return at(p.x, p.z)

static func display_name(region: String) -> String:
	return String(NAMES.get(region, ""))

## True while `p` is inside the region's bounds grown by `margin`.
static func near(region: String, p: Vector3, margin := 0.0) -> bool:
	if not BOUNDS.has(region):
		return false
	var r: Rect2 = BOUNDS[region]
	return r.grow(margin).has_point(Vector2(p.x, p.z))

## Boss that guards a region ("" when the region needs no key).
static func key_boss(region: String) -> String:
	return String(UNLOCKED_BY.get(region, ""))
