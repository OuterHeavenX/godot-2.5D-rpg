class_name QuestDB
## Static quest definitions: a short chain across the four village NPCs.
##
## Objective types:
##   "talk"    — talk to the NPC named in "target"
##   "kill"    — kill "target" skeletons (counted from acceptance)
##   "collect" — hold "target" potions at once
##   "level"   — reach player level "target"

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETE, TURNED_IN }

const QUESTS := [
	{
		"id": "pips_dream",
		"giver": "Pip",
		"title": "Pip's Dream",
		"prereq": "",
		"objective_type": "talk",
		"objective_target": "Old Fen",
		"objective_text": "Talk to Old Fen",
		"offer": [
			"Pip's Dream",
			"I wanna be an adventurer, just like you! But Old Fen says I'm too young.",
			"Could you go talk to Old Fen for me? Maybe he'll tell you a real hero story!",
		],
		"reminder": [
			"Did you talk to Old Fen yet? He hangs around the square, telling stories.",
		],
		"complete_lines": [
			"Pip's Dream",
			"Old Fen told you about the Battle of the Ashen Field?! Wow...",
			"One day I'll be a hero too. Thanks, traveler! Take this for your trouble.",
		],
		"reward_gold": 30,
		"reward_xp": 20,
	},
	{
		"id": "bones_in_the_wild",
		"giver": "Old Fen",
		"title": "Bones in the Wild",
		"prereq": "pips_dream",
		"objective_type": "kill",
		"objective_target": 5,
		"objective_text": "Defeat 5 skeletons",
		"offer": [
			"Bones in the Wild",
			"Pip speaks highly of you. Good — we'll need heroes before long.",
			"The skeletons in the southern wilds grow bolder every night.",
			"Drive back 5 of them. Show this village what you're made of.",
		],
		"reminder": [
			"The skeletons still trouble the southern wilds.",
		],
		"complete_lines": [
			"Bones in the Wild",
			"Five skeletons shattered. The wilds breathe a little easier tonight.",
			"You've earned this, hero. The village thanks you.",
		],
		"reward_gold": 100,
		"reward_xp": 60,
	},
	{
		"id": "stock_up",
		"giver": "Bram",
		"title": "Stock Up",
		"prereq": "bones_in_the_wild",
		"objective_type": "collect",
		"objective_target": 3,
		"objective_text": "Hold 3 potions at once",
		"offer": [
			"Stock Up",
			"Heard you thinned the skeleton herd. Fine work!",
			"But listen — a hero who marches out unprepared is just a corpse with confidence.",
			"Carry 3 potions at once. Buy them at the market or pry them from skeleton hands.",
		],
		"reminder": [
			"Potions, traveler. Three of them, in your pack at the same time.",
		],
		"complete_lines": [
			"Stock Up",
			"Now that's a prepared adventurer. Skeletons drop potions too, remember.",
			"Take this gold — spend it on something sharp.",
		],
		"reward_gold": 120,
		"reward_xp": 80,
	},
	{
		"id": "proving_ground",
		"giver": "Mira",
		"title": "Proving Ground",
		"prereq": "stock_up",
		"objective_type": "level",
		"objective_target": 6,
		"objective_text": "Reach level 6",
		"offer": [
			"Proving Ground",
			"So you're the one everyone's talking about. Bram says you're prepared; Fen says you're brave.",
			"But are you strong? The wilds only respect strength.",
			"Reach level 6 and come back. Then I'll believe the stories.",
		],
		"reminder": [
			"Level 6, traveler. The skeletons are waiting.",
		],
		"complete_lines": [
			"Proving Ground",
			"Level 6. I can see it in the way you carry that blade now.",
			"The village is lucky to have you. This is yours — you've earned it.",
		],
		"reward_gold": 200,
		"reward_xp": 150,
	},
]

static func get_quest(quest_id: String) -> Dictionary:
	for q in QUESTS:
		if q["id"] == quest_id:
			return q
	return {}

static func quest_ids() -> Array:
	var ids := []
	for q in QUESTS:
		ids.append(q["id"])
	return ids
