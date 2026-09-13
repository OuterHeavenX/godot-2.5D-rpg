extends SceneTree
## Development tool: walk the camera through every region and save a PNG
## of each, so a change to the world can be eyeballed without playing to
## the far end of it.
##
##   xvfb-run -a godot --path . -s tools/region_shots.gd -- <out_dir>
##
## Never shipped or run by the game itself.

const SPOTS := [
	["01_village", Vector3(0, 0.1, 14)],
	["02_south_wilds", Vector3(-4, 0.1, 48)],
	["03_island", Vector3(30, 0.1, 57)],
	["04_north_road", Vector3(2, 0.1, -120)],
	["05_grimholt", Vector3(0, 0.1, -240)],
	["06_frozen_arena", Vector3(0, 0.1, -276)],
	["07_west_gate", Vector3(-40, 0.1, 0)],
	["08_highlands", Vector3(-130, 0.1, 0)],
	["09_ashfall_watch", Vector3(-204, 0.1, 6)],
	["10_reaver_wall", Vector3(-262, 0.1, 0)],
	["11_kael_arena", Vector3(-276, 0.1, 0)],
	["12_east_gate", Vector3(40, 0.1, 0)],
	["13_mirefen", Vector3(130, 0.1, 0)],
	["14_fen_water", Vector3(130, 0.1, 14)],
	["15_drowned_chapel", Vector3(204, 0.1, 6)],
	["16_lich_gate", Vector3(262, 0.1, 0)],
	["17_gholl_pool", Vector3(276, 0.1, 0)],
]

var _out := "shots"

func _init() -> void:
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://src/world/main.tscn")
	await _frames(6)
	paused = false
	var menu := get_first_node_in_group("main_menu")
	if menu != null:
		menu.set("_showing_story", false)
		menu.set("visible", false)
	# Every gate open, so the tour is not stopped at the first one.
	var qm := root.get_node_or_null("QuestMan")
	if qm != null:
		for boss_id in ["vorgath", "morvain", "kael", "gholl"]:
			qm.call("mark_boss_slain", boss_id)
	var player := get_first_node_in_group("player") as Node3D
	if player == null:
		printerr("no player")
		quit(1)
		return
	for spot: Array in SPOTS:
		player.global_position = spot[1]
		await _frames(30)
		var img := root.get_texture().get_image()
		var path := "%s/%s.png" % [_out, String(spot[0])]
		img.save_png(path)
		print("saved ", path)
	quit(0)
