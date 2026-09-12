class_name QuestDB
## Static quest definitions: the main story of Emberfell and a side chain
## across the four village NPCs.
##
## Objective types:
##   "talk"     — talk to the NPC named in "target"
##   "kill"     — kill "target" skeletons (counted from acceptance)
##   "collect"  — hold "target" potions at once
##   "level"    — reach player level "target"
##   "reach"    — reach the [x, z, radius] in "objective_target"
##   "bosskill" — slay the boss

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETE, TURNED_IN }

const QUESTS := [
	# ---------------------------------------------------------- MAIN STORY
	{
		"id": "emberfell_arrives",
		"giver": "Old Fen",
		"title": "The Road to Emberfell",
		"main": true,
		"prereq": "",
		"objective_type": "talk",
		"objective_target": "Old Fen",
		"objective_text": "Speak with Old Fen",
		"offer": [
			"The Road to Emberfell",
			"So. The traveler from the tales stands before me at last.",
			"The dead rise in the southern wilds, and Emberfell's lamps burn low.",
			"Will you help this old keeper of stories write a better ending?",
		],
		"reminder": [
			"The wilds are waiting, traveler.",
		],
		"complete_lines": [
			"The Road to Emberfell",
			"Then it's settled. Rest up, stock your pack, and come back when you're ready.",
			"Your legend starts here — try not to die in the first chapter.",
		],
		"reward_gold": 50,
		"reward_xp": 30,
	},
	{
		"id": "what_stirs_below",
		"giver": "Old Fen",
		"title": "What Stirs Below",
		"main": true,
		"prereq": "emberfell_arrives",
		"objective_type": "kill",
		"objective_target": 8,
		"objective_text": "Defeat 8 skeletons",
		"offer": [
			"What Stirs Below",
			"Every skeleton you shatter is one less blade at our throats — but they're just the fingers.",
			"Something down south is making a fist. I can feel it in my bones, and my bones are never wrong.",
			"Thin the herd: 8 of them. Then we'll talk about the black water.",
		],
		"reminder": [
			"Eight skeletons, traveler. The southern wilds.",
		],
		"complete_lines": [
			"What Stirs Below",
			"Eight shattered. But you felt it too, didn't you? They weren't wandering — they were called.",
			"There's a lake in the southeast wilds, black as a drowned man's dream. Cross it, and you'll find what's calling them.",
		],
		"reward_gold": 150,
		"reward_xp": 100,
	},
	{
		"id": "the_black_water",
		"giver": "Old Fen",
		"title": "The Black Water",
		"main": true,
		"prereq": "what_stirs_below",
		"objective_type": "reach",
		"objective_target": [17.0, 57.0, 4.0],
		"objective_text": "Cross the bridge to the island",
		"offer": [
			"The Black Water",
			"Past the southeast wilds runs black water, and over it a bridge no living hands maintain.",
			"On the island beyond, something old wears a crown of drowned gold.",
			"Cross the bridge. See what's waiting. Then come back — if you can.",
		],
		"reminder": [
			"Southeast wilds. Cross the bridge to the island.",
		],
		"complete_lines": [
			"The Black Water",
			"You stood on the cursed isle and lived. Few can say that.",
			"Now finish it. Send Vorgath back to the dark he crawled from.",
		],
		"reward_gold": 100,
		"reward_xp": 80,
	},
	{
		"id": "the_drowned_tyrant",
		"giver": "Old Fen",
		"title": "The Drowned Tyrant",
		"main": true,
		"prereq": "the_black_water",
		"objective_type": "bosskill",
		"objective_target": 1,
		"objective_text": "Slay Vorgath, the Drowned King",
		"offer": [
			"The Drowned Tyrant",
			"Vorgath was a king before Emberfell had a name. The black water took him — and gave him back wrong.",
			"He calls the dead from his island throne. While he wears that crown, the wilds will never rest.",
			"End him, traveler. End this.",
		],
		"reminder": [
			"Vorgath waits on the island. Finish it.",
		],
		"complete_lines": [
			"The Drowned Tyrant",
			"The crown is silent. The wilds are quiet — for the first time in living memory.",
			"Emberfell owes you more than gold, hero. But gold is what I have.",
		],
		"reward_gold": 500,
		"reward_xp": 300,
	},
	# ---------------------------------------------------------- SIDE QUESTS
	{
		"id": "pips_dream",
		"giver": "Pip",
		"title": "Pip's Dream",
		"main": false,
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
		"main": false,
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
		"main": false,
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
		"main": false,
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
