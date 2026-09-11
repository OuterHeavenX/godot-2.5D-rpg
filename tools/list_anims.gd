extends SceneTree

func _init() -> void:
	var packed := load("res://src/player/hero.glb") as PackedScene
	if packed == null:
		print("FAILED to load hero.glb")
		quit(1)
		return
	var inst := packed.instantiate()
	root.add_child(inst)
	var players: Array = []
	_find_players(inst, players)
	print("PLAYERS FOUND: ", players.size())
	for p in players:
		var ap := p as AnimationPlayer
		print("ANIMPLAYER node: ", ap.name)
		var anims := ap.get_animation_list()
		print("ANIM COUNT: ", anims.size())
		for a in anims:
			print("CLIP: ", a)
	# Also print node tree depth-1 for structure
	print("ROOT CHILDREN:")
	for c in inst.get_children():
		print("  - ", c.name, " (", c.get_class(), ")")
	quit()

func _find_players(n: Node, out: Array) -> void:
	if n is AnimationPlayer:
		out.append(n)
	for c in n.get_children():
		_find_players(c, out)
