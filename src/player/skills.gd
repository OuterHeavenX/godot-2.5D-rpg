class_name Skills
## Skill definitions. Every level-up grants one skill point; each skill can
## be learned up to max_rank times. Effects are read live by the player
## (nothing is baked into saved stats), so ranks are the only state.

const SKILLS := {
	"swift_blade": {"name": "Swift Blade", "max_rank": 3,
		"desc": "The ATB gauge fills 12% faster per rank."},
	"long_step": {"name": "Long Step", "max_rank": 3,
		"desc": "Dodge carries you 20% farther per rank."},
	"twin_slash": {"name": "Twin Slash", "max_rank": 1,
		"desc": "Every attack strikes twice; the second cut deals half damage."},
	"keen_edge": {"name": "Keen Edge", "max_rank": 3,
		"desc": "+6% attack damage per rank."},
	"iron_skin": {"name": "Iron Skin", "max_rank": 3,
		"desc": "Take 8% less damage per rank."},
	"deep_well": {"name": "Deep Well", "max_rank": 3,
		"desc": "Mana regenerates 40% faster per rank."},
	"arcane_focus": {"name": "Arcane Focus", "max_rank": 2,
		"desc": "Spells cost 20% less MP per rank."},
	"second_wind": {"name": "Second Wind", "max_rank": 1,
		"desc": "Slaying a foe restores 10% of your max HP."},
}

static func ids() -> Array:
	return SKILLS.keys()

static func get_skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})

static func max_rank(id: String) -> int:
	return int(SKILLS.get(id, {}).get("max_rank", 0))
