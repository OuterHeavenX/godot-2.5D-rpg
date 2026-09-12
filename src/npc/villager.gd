extends CharacterBody3D
## Generic villager NPC: KayKit character (or low-poly primitives) with
## dialogue. Can wander around or stand still. Talk to them for flavor text.
## A real physics body, so wanderers walk around buildings, props and the
## player instead of through them, and play a walk cycle while moving.

@export var npc_name := "Villager"
@export var dialogue := ["Hello, traveler!"]
@export var tunic_color := Color(0.45, 0.35, 0.25)
@export var wanders := false
@export var wander_radius := 5.0
@export var shop_title := ""  # If set, opens shop instead of dialogue.
@export var shop_items := []
@export var kaykit_model := ""  # "Barbarian", "Knight", "Mage", or "Rogue". Empty = primitive.

const WALK_SPEED := 1.5

var _home_pos := Vector3.ZERO
var _target_pos := Vector3.ZERO
var _wait_timer := 0.0
var _stuck_timer := 0.0
var _anim: AnimationPlayer
var _quest_marker: Label3D

func _ready() -> void:
	_home_pos = position
	_target_pos = _home_pos
	# Flat ground: no gravity, just slide around obstacles.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_collision()
	_build_body()
	_build_interaction()
	_build_quest_marker()
	QuestMan.quests_changed.connect(_update_quest_marker)
	_update_quest_marker()

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.5
	cs.shape = capsule
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

func _build_quest_marker() -> void:
	_quest_marker = Label3D.new()
	_quest_marker.text = ""
	_quest_marker.font_size = 96
	_quest_marker.pixel_size = 0.008
	_quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_marker.no_depth_test = true
	_quest_marker.modulate = Color(1.0, 0.85, 0.3)
	_quest_marker.outline_size = 12
	_quest_marker.outline_modulate = Color(0, 0, 0, 0.9)
	_quest_marker.position = Vector3(0, 2.4, 0)
	add_child(_quest_marker)

func _update_quest_marker() -> void:
	if _quest_marker == null:
		return
	_quest_marker.text = QuestMan.marker_for(npc_name)

func _build_body() -> void:
	# KayKit model (if specified).
	if kaykit_model != "":
		_build_kaykit()
		return
	# Body (tunic).
	var body := _part(Vector3(0.55, 0.75, 0.35), tunic_color)
	body.position = Vector3(0, 0.95, 0)
	add_child(body)
	# Head.
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.26
	hm.height = 0.52
	head.mesh = hm
	head.position = Vector3(0, 1.55, 0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.95, 0.78, 0.62)
	head.set_surface_override_material(0, skin)
	add_child(head)
	# Simple cap/hood.
	var cap := _part(Vector3(0.4, 0.18, 0.4), tunic_color.darkened(0.25))
	cap.position = Vector3(0, 1.78, 0)
	add_child(cap)
	# Arms.
	for side in [-1.0, 1.0]:
		var arm := _part(Vector3(0.16, 0.55, 0.16), tunic_color)
		arm.position = Vector3(side * 0.36, 0.95, 0)
		add_child(arm)
	# Legs.
	for side in [-1.0, 1.0]:
		var leg := _part(Vector3(0.18, 0.55, 0.18), Color(0.32, 0.25, 0.18))
		leg.position = Vector3(side * 0.15, 0.28, 0)
		add_child(leg)

func _part(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.set_surface_override_material(0, mat)
	return mi

## Load a KayKit character model instead of primitives.
func _build_kaykit() -> void:
	var path := "res://src/npc/%s.glb" % kaykit_model
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return
	add_child(instance)
	# KayKit models are about 1.8m tall, a good villager size as-is.
	_anim = instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("Idle")

func _play(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation != clip:
		_anim.play(clip)

func _build_interaction() -> void:
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.2
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	area.add_child(col)
	area.body_entered.connect(_on_body_enter)
	area.body_exited.connect(_on_body_exit)
	add_child(area)

func _on_body_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		_show_talk_prompt()

func _on_body_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_hide_talk_prompt()

func _show_talk_prompt() -> void:
	# If this NPC is a seller, open the shop prompt. Otherwise show a
	# TALK button (doesn't pause — player chooses to talk).
	if shop_title != "":
		var shop := get_tree().get_first_node_in_group("shop_ui")
		if shop != null and shop.has_method("set_shop"):
			shop.set_shop(shop_title, shop_items, "%s: \"Welcome in, traveler.\"" % npc_name)
		if shop != null and shop.has_method("show_talk_prompt"):
			shop.show_talk_prompt()
	else:
		var ui := get_tree().get_first_node_in_group("dialogue_ui")
		if ui != null and ui.has_method("show_talk_button"):
			var talk: Dictionary = QuestMan.get_talk(npc_name, dialogue)
			ui.show_talk_button(npc_name, talk["lines"],
				String(talk["offer"]), String(talk["turnin"]))

func _hide_talk_prompt() -> void:
	if shop_title != "":
		var shop := get_tree().get_first_node_in_group("shop_ui")
		if shop != null and shop.has_method("hide_talk_prompt"):
			shop.hide_talk_prompt()
	else:
		var ui := get_tree().get_first_node_in_group("dialogue_ui")
		if ui != null and ui.has_method("hide_talk_button"):
			ui.hide_talk_button()

func _physics_process(delta: float) -> void:
	if not wanders:
		return
	# Simple wander: pick a target, walk to it, wait, repeat.
	_wait_timer -= delta
	var to_target := _target_pos - position
	to_target.y = 0
	if to_target.length() < 0.3:
		velocity = Vector3.ZERO
		_play("Idle")
		if _wait_timer <= 0:
			_pick_target()
	else:
		# Walk toward target; the body slides around anything solid.
		var dir := to_target.normalized()
		velocity = dir * WALK_SPEED
		move_and_slide()
		_play("Walking_A")
		# Face movement direction.
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 8.0 * delta)
		# Blocked by a wall, a crate or the hero? Give up on this target.
		if get_real_velocity().length() < 0.3:
			_stuck_timer += delta
			if _stuck_timer > 1.0:
				_pick_target()
		else:
			_stuck_timer = 0.0

func _pick_target() -> void:
	var ang := randf() * TAU
	var dist := randf() * wander_radius
	_target_pos = _home_pos + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
	_wait_timer = randf_range(2.0, 5.0)
	_stuck_timer = 0.0
