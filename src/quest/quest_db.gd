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
		"objective_text": "Defeat 8 foes",
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
			"There's black water east of the wilds, dark as a drowned man's dream. Cross the bridge, and you'll find what's calling them.",
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
		"objective_target": [37.0, 57.0, 5.0],
		"objective_text": "Cross the bridge to the island",
		"offer": [
			"The Black Water",
			"East of the wilds lies black water, and over it a bridge no living hands maintain.",
			"On the island beyond, something old wears a crown of drowned gold.",
			"Cross the bridge. See what's waiting. Then come back — if you can.",
		],
		"reminder": [
			"East, past the wilds. Cross the bridge to the island.",
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
		"boss_id": "vorgath",
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
	# ---------------------------------------------------------- CHAPTER TWO
	{
		"id": "the_northern_road",
		"giver": "Old Fen",
		"title": "The Northern Road",
		"main": true,
		"prereq": "the_drowned_tyrant",
		"objective_type": "talk",
		"objective_target": "Old Fen",
		"objective_text": "Speak with Old Fen",
		"offer": [
			"The Northern Road",
			"Vorgath is gone, but the riders from Grimholt bring grim news.",
			"The northern road is overrun. The dead walk the cold wilds, bolder than ever.",
			"Grimholt needs a hero, traveler. The north gate stands open. Will you go?",
		],
		"reminder": [
			"The north gate, traveler. Grimholt is waiting.",
		],
		"complete_lines": [
			"The Northern Road",
			"Then go with my blessing. The northern wilds are cruel — dead trees, jagged rocks, and worse.",
			"Find Elder Sella in Grimholt. Tell her Emberfell remembers its friends.",
		],
		"reward_gold": 100,
		"reward_xp": 80,
	},
	{
		"id": "grimholt_bound",
		"giver": "Old Fen",
		"title": "Grimholt Bound",
		"main": true,
		"prereq": "the_northern_road",
		"objective_type": "reach",
		"objective_target": [0.0, -250.0, 10.0],
		"objective_text": "Reach Grimholt in the far north",
		"offer": [
			"Grimholt Bound",
			"North through the gate, then follow the road. It's a long walk — the wilds are bigger than ours.",
			"Stay on the road if you can. The treeline hides teeth.",
			"Grimholt's lamps burn at the far end. Don't let them go out.",
		],
		"reminder": [
			"North, traveler. Follow the road to Grimholt.",
		],
		"complete_lines": [
			"Grimholt Bound",
			"You made it. The town still stands — barely.",
			"Find Elder Sella. She'll know what needs doing.",
		],
		"reward_gold": 150,
		"reward_xp": 120,
	},
	{
		"id": "the_cold_dark",
		"giver": "Elder Sella",
		"title": "The Cold Dark",
		"main": true,
		"prereq": "grimholt_bound",
		"objective_type": "kill",
		"objective_target": 12,
		"objective_text": "Defeat 12 northern foes",
		"offer": [
			"The Cold Dark",
			"Emberfell sends us a hero. Good — we need one.",
			"The northern wilds crawl with the dead. Stronger than the southern rabble, too — the cold preserves them.",
			"Thin them: 12. Then we'll talk about what's really stirring out there.",
		],
		"reminder": [
			"Twelve of them, hero. The northern wilds.",
		],
		"complete_lines": [
			"The Cold Dark",
			"Twelve. The road breathes easier already.",
			"But this is just the beginning. Something ancient sleeps beneath the northern ice — and it's waking.",
		],
		"reward_gold": 300,
		"reward_xp": 250,
	},
	{
		"id": "the_frozen_arena",
		"giver": "Elder Sella",
		"title": "The Frozen Arena",
		"main": true,
		"prereq": "the_cold_dark",
		"objective_type": "reach",
		"objective_target": [0.0, -288.0, 9.0],
		"objective_text": "Find the frozen arena beyond the north wall",
		"offer": [
			"The Frozen Arena",
			"Beyond our north wall, where the road ends, the ice never melts — even in high summer.",
			"Our scouts speak of a circle of black ice ringed with crystals, and something moving at its heart.",
			"Morvain, the old songs call it. A golem of living ice, older than Grimholt itself.",
			"Go. Look. Then come back and tell me what you saw.",
		],
		"reminder": [
			"North of the north wall, hero. Follow the road past Grimholt.",
		],
		"complete_lines": [
			"The Frozen Arena",
			"You've seen it. Then the songs are true — Morvain wakes.",
			"If that thing walks south, Grimholt is finished. It has to end on that ice.",
		],
		"reward_gold": 200,
		"reward_xp": 180,
	},
	{
		"id": "the_frozen_heart",
		"giver": "Elder Sella",
		"title": "The Frozen Heart",
		"main": true,
		"prereq": "the_frozen_arena",
		"objective_type": "bosskill",
		"boss_id": "morvain",
		"objective_target": 1,
		"objective_text": "Shatter Morvain, the Frozen Heart",
		"offer": [
			"The Frozen Heart",
			"Morvain's heart is a shard of the first winter — crack it, and the golem falls.",
			"Bring me that shard and I'll teach you what the old mages knew: Glacial Spike.",
			"The cold answers the cold, hero. Make it answer to you.",
		],
		"reminder": [
			"Morvain waits on the black ice. Shatter it.",
		],
		"complete_lines": [
			"The Frozen Heart",
			"The shard... it's still cold. Colder than any winter I've known.",
			"A promise is a promise. Hold out your hand — and learn Glacial Spike.",
		],
		"reward_gold": 800,
		"reward_xp": 600,
		"reward_spell": "glacial_spike",
	},
	# ---------------------------------------------------------- SIDE QUESTS
	{
		"id": "hobs_watch",
		"main": false,
		"giver": "Hob",
		"title": "Hob's Watch",
		"prereq": "grimholt_bound",
		"objective_type": "kill",
		"objective_target": 6,
		"objective_text": "Defeat 6 foes",
		"offer": [
			"Hob's Watch",
			"You're the Emberfell hero? Good. I could use a hand on my rounds.",
			"The treeline near the road — that's where they gather. Six of 'em, at least.",
			"Watch yourself. They're tougher up here.",
		],
		"reminder": [
			"Six foes near the northern road, hero.",
		],
		"complete_lines": [
			"Hob's Watch",
			"Six down. The road's safer for it.",
			"You're alright, Emberfell. Here's your pay.",
		],
		"reward_gold": 180,
		"reward_xp": 140,
	},
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
		"objective_text": "Defeat 5 foes",
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
	{
		"id": "miras_courage",
		"main": false,
		"giver": "Mira",
		"title": "A Mage's Courage",
		"prereq": "proving_ground",
		"objective_type": "talk",
		"objective_target": "Mira",
		"objective_text": "Speak with Mira",
		"offer": [
			"A Mage's Courage",
			"You've proven yourself in the wilds, and I've been... practicing. My frost bolts finally fly straight!",
			"Take me with you. I can fight beside you — and patch you up when the skeletons bite back.",
		],
		"reminder": [
			"Ready when you are. Just say the word and I'll pack my staff.",
		],
		"complete_lines": [
			"A Mage's Courage",
			"You won't regret this! I'll cover you from range — and keep you standing.",
			"Mira has joined your party! Check the PARTY tab.",
		],
		"reward_gold": 0,
		"reward_xp": 100,
		"reward_companion": "mira",
	},
	{
		"id": "brams_oath",
		"main": false,
		"giver": "Bram",
		"title": "A Barbarian's Oath",
		"prereq": "the_drowned_tyrant",
		"objective_type": "talk",
		"objective_target": "Bram",
		"objective_text": "Speak with Bram",
		"offer": [
			"A Barbarian's Oath",
			"You slew the Drowned King. I saw the whole thing from the shore, and my axe arm has itched ever since.",
			"A warrior like you shouldn't walk alone. Let me stand at your side — I'll break whatever stands in our way.",
		],
		"reminder": [
			"My axe is sharp and my oath is ready. Say the word.",
		],
		"complete_lines": [
			"A Barbarian's Oath",
			"HA! The wilds won't know what hit them. I fight in front — you watch my back.",
			"Bram has joined your party! Check the PARTY tab.",
		],
		"reward_gold": 0,
		"reward_xp": 150,
		"reward_companion": "bram",
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
