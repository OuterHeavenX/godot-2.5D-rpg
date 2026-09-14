extends SceneTree
## Ninja hero integration test. Run with:
##   godot --headless --path . -s tests/ninja_hero_test.gd
## Boots the real main scene and verifies the ninja hero: meshes, props,
## two-tone materials, equipment colors, and all combat animations.

var _fails := 0
var _passes := 0

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	print("== ninja hero boot")
	change_scene_to_file("res://src/world/main.tscn")
	await _frames(5)
	paused = false
	var mm := get_first_node_in_group("main_menu")
	if mm != null:
		mm.set("_showing_story", false)
	await _frames(5)
	var player := get_first_node_in_group("player")
	_check(player != null, "player present")
	if player == null:
		quit(1)
		return
	var rig: Node3D = player.get_node_or_null("HeroRig")
	_check(rig != null, "HeroRig node present")

	print("== ninja meshes")
	var mask := rig.find_child("Ninja_Mask")
	var band := rig.find_child("Ninja_Headband")
	var cape := rig.find_child("Rogue_Cape")
	_check(mask is MeshInstance3D, "Ninja_Mask present")
	_check(band is MeshInstance3D, "Ninja_Headband present")
	_check(cape is MeshInstance3D, "Rogue_Cape present")
	_check(rig.find_child("Rogue_Head_Hooded") == null, "old hooded head gone")

	print("== props")
	var knife := rig.find_child("Knife") as MeshInstance3D
	var off := rig.find_child("Knife_Offhand") as MeshInstance3D
	_check(knife != null and knife.visible, "main-hand dagger visible")
	_check(off != null and not off.visible, "off-hand dagger hidden")

	print("== two-tone materials")
	_check(mask.get_surface_override_material(0) != null, "mask has override material")
	_check(cape.get_surface_override_material(0) != null, "cape has override material")

	print("== equipment colors")
	player.equip_hood(45)
	player.equip_cape(25)
	await _frames(2)
	var mm2 := mask.get_surface_override_material(0) as StandardMaterial3D
	_check(mm2 != null and mm2.albedo_color.r > 0.3, "mask tinted blood-red by hood level 45")
	_check(int(player.get("hood_level")) == 45, "hood level stored")
	_check(int(player.get("cape_level")) == 25, "cape level stored")

	print("== animations")
	var anim := rig.get_node("AnimationPlayer") as AnimationPlayer
	# The player's own physics keeps grabbing the AnimationPlayer back to
	# Idle; freeze it while the test drives the clips directly.
	player.set_physics_process(false)
	var all_ok := true
	for clip in ["Idle", "Walking_A", "1H_Melee_Attack_Slice_Horizontal",
			"Dodge_Forward", "Hit_A", "Death_A"]:
		if not anim.has_animation(clip):
			all_ok = false
			printerr("  FAIL missing anim: ", clip)
		else:
			anim.play(clip)
			await _frames(2)
			if anim.current_animation != StringName(clip):
				all_ok = false
				printerr("  FAIL did not play: ", clip)
	_check(all_ok, "all six hero animations play")
	anim.play("Idle")
	player.set_physics_process(true)

	print("== attack path")
	player.set("atb", 1.0)
	player.try_attack()
	await _frames(30)
	_check(true, "try_attack ran without errors")

	print("")
	print("%d passed, %d failed" % [_passes, _fails])
	if _fails > 0:
		printerr("NINJA HERO TESTS FAILED")
		quit(1)
	else:
		print("NINJA HERO ALL TESTS PASSED")
		quit(0)
