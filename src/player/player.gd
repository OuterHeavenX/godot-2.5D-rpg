extends CharacterBody3D
## Classic JRPG-style movement for 2.5D RPG, with ATB combat.
## Camera is angled like old-school Final Fantasy; movement is on the XZ plane.
## Supports keyboard (WASD/arrows) and the on-screen virtual joystick.
## The player is a real 3D animated character (KayKit "Adventurers" Hooded
## Rogue, CC0).
##
## ATB: the gauge fills in real time (~1.4s). Attacks and dodges spend it.
## Skeletons telegraph their swings, so a well-timed dodge avoids damage.

@export var speed: float = 5.0
@export var accel: float = 12.0
@export var turn_speed: float = 12.0

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_ATTACK := "1H_Melee_Attack_Slice_Horizontal"
const ANIM_DODGE := "Dodge_Forward"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"

const MAX_HP := 100.0
const ATTACK_RANGE := 2.6
const ATB_FILL_TIME := 1.4
const DODGE_IFRAMES := 0.4
const DODGE_DISTANCE := 3.5
const DODGE_TIME := 0.28
const SPRINT_MULT := 1.7
const XP_BASE := 100

signal hp_changed(hp: float, max_hp: float)
signal mp_changed(mp: float, max_mp: float)
signal atb_changed(atb: float)
signal sprint_changed(sprinting: bool)
signal xp_changed(xp: int, xp_next: int, level: int)
signal leveled_up(new_level: int)
signal died

const MAX_MP := 30.0
const MP_REGEN := 2.5

var max_mp := MAX_MP
var mp := MAX_MP
var selected_spell := Spells.FIREBALL
var bonus_spells: Array = [] # Quest-unlocked spells (e.g. Glacial Spike).

var max_hp := MAX_HP
var attack_damage := 14.0
var level := 1
var xp := 0
var deaths := 0
var play_time := 0.0
var hp := MAX_HP
var atb := 1.0
var potions := 0
var gold := 0
var cape_level := 0
var hood_level := 0
var weapon_level := 0

signal potions_changed(count: int)
signal gold_changed(amount: int)
signal equipment_changed()
signal items_changed()
signal skills_changed()

# Inventory beyond potions: item id -> count (see ItemDB).
var items := {}
# Skill tree: skill id -> rank (see Skills). One point per level-up.
var skills := {}
var skill_points := 0
# One equipped accessory (ItemDB id), or "".
var accessory := ""
var sprinting := false
var dead := false
var _hood_mat: ShaderMaterial
var _cape_mat: ShaderMaterial

const HOOD_SHADER := preload("res://src/player/hood_two_tone.gdshader")
const CAPE_SHADER := preload("res://src/player/cape_two_tone.gdshader")
const ROGUE_TEXTURE := preload("res://src/player/rogue_hooded_rogue_texture.png")
const RESPAWN_POS := Vector3(0, 0.1, 0)
const DEATH_GOLD_LOSS := 0.10  # fraction of gold dropped on death

# Weapon/prop meshes that ship with the KayKit rig; we keep only the dagger.
const HIDDEN_PROPS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var _attack_timer := 0.0
var _attack_dir := Vector3.ZERO
var _hit_timer := 0.0
var _dodge_timer := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _iframes := 0.0
var _chill_timer := 0.0 # Player chill: enemy ice slows movement.
var _step_dist := 0.0   # Distance walked since the last footstep sound.
var _slash: MeshInstance3D

## Chill the player (ice attacks): movement slowed to 60% while active.
func apply_chill(duration: float) -> void:
	if dead or bool(ItemDB.get_item(accessory).get("chill_immune", false)):
		return
	_chill_timer = maxf(_chill_timer, duration)

# ---------------------------------------------------------------- inventory

func add_item(id: String, count := 1) -> void:
	if id == "potion":
		add_potion(count)
		return
	items[id] = int(items.get(id, 0)) + count
	items_changed.emit()

func has_item(id: String, count := 1) -> bool:
	if id == "potion":
		return potions >= count
	return int(items.get(id, 0)) >= count

func item_count(id: String) -> int:
	if id == "potion":
		return potions
	return int(items.get(id, 0))

func remove_item(id: String, count := 1) -> bool:
	if not has_item(id, count):
		return false
	if id == "potion":
		potions -= count
		potions_changed.emit(potions)
		return true
	items[id] = int(items[id]) - count
	if int(items[id]) <= 0:
		items.erase(id)
	items_changed.emit()
	return true

## Drink or apply a consumable from the inventory. Returns false if it
## could not be used (none owned, nothing to restore, dead).
func use_item(id: String) -> bool:
	if id == "potion":
		return use_potion()
	if dead or not has_item(id):
		return false
	var info := ItemDB.get_item(id)
	if not ItemDB.is_kind(id, ItemDB.KIND_CONSUMABLE):
		return false
	if bool(info.get("full", false)):
		if hp >= max_hp and mp >= max_mp:
			return false
		hp = max_hp
		mp = max_mp
	elif info.has("mp"):
		if mp >= max_mp:
			return false
		mp = minf(max_mp, mp + float(info["mp"]))
	else:
		return false
	remove_item(id)
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	AudioMan.play("potion_drink", 1.1, 0.0)
	return true

## What the hero actually hits for: the bare stat with the worn
## accessory's bonuses laid on top.
##
## The accessory is never folded into attack_damage. It used to be —
## multiplied in on equip and divided back out on unequip — and every
## level earned while wearing it was taxed on the way off, because the
## flat +2 a level adds was added after the multiply and divided by it
## after. Applying the bonus here instead means taking a charm off
## always leaves exactly what was there without it.
func total_attack() -> float:
	if accessory == "":
		return attack_damage
	var info := ItemDB.get_item(accessory)
	return (attack_damage + float(info.get("atk", 0.0))) * float(info.get("atk_mult", 1.0))

## Wear an accessory from the inventory (swapping out the current one).
## Max HP is a stored stat, so it is adjusted here; attack is derived by
## total_attack() and needs no bookkeeping.
func equip_accessory(id: String) -> bool:
	if id != "" and (not has_item(id) or not ItemDB.is_kind(id, ItemDB.KIND_ACCESSORY)):
		return false
	# Health moves with the ceiling in both directions. Taking a +HP charm
	# off used to only clamp, which did nothing while health was already
	# below the lower ceiling — so wearing it again handed back the full
	# bonus, and WEAR/REMOVE on the same panel was free healing forever.
	if accessory != "":
		var old := ItemDB.get_item(accessory)
		var lost := float(old.get("hp", 0.0))
		max_hp -= lost
		hp = minf(hp - lost, max_hp)
	accessory = id
	if id != "":
		var info := ItemDB.get_item(id)
		var gained := float(info.get("hp", 0.0))
		max_hp += gained
		hp = minf(max_hp, hp + gained)
	hp = maxf(hp, 1.0)
	hp_changed.emit(hp, max_hp)
	equipment_changed.emit()
	items_changed.emit()
	return true

## Craft a recipe from ItemDB at the forge: consumes the materials and the
## smith's fee. Returns false if anything is missing.
func craft(result_id: String) -> bool:
	if not ItemDB.RECIPES.has(result_id):
		return false
	var recipe: Dictionary = ItemDB.RECIPES[result_id]
	var needs: Dictionary = recipe["needs"]
	for mat in needs:
		if not has_item(String(mat), int(needs[mat])):
			return false
	if gold < int(recipe.get("fee", 0)):
		return false
	for mat in needs:
		remove_item(String(mat), int(needs[mat]))
	spend_gold(int(recipe.get("fee", 0)))
	add_item(result_id, 1)
	return true

# ---------------------------------------------------------------- skills

func skill_rank(id: String) -> int:
	return int(skills.get(id, 0))

## Spend a skill point on a skill. Returns false if maxed or no points.
func learn_skill(id: String) -> bool:
	if skill_points <= 0 or not Skills.SKILLS.has(id):
		return false
	if skill_rank(id) >= Skills.max_rank(id):
		return false
	skills[id] = skill_rank(id) + 1
	skill_points -= 1
	skills_changed.emit()
	return true

func atb_fill_time() -> float:
	return ATB_FILL_TIME / (1.0 + 0.12 * skill_rank("swift_blade"))

func dodge_distance() -> float:
	return DODGE_DISTANCE * (1.0 + 0.2 * skill_rank("long_step"))

func attack_multiplier() -> float:
	return 1.0 + 0.06 * skill_rank("keen_edge")

func damage_taken_multiplier() -> float:
	return 1.0 - 0.08 * skill_rank("iron_skin")

func mp_regen_rate() -> float:
	return MP_REGEN * (1.0 + 0.4 * skill_rank("deep_well"))

func spell_cost(base: int) -> int:
	return maxi(1, int(round(base * (1.0 - 0.2 * skill_rank("arcane_focus")))))

## Called by foes when the party slays them.
func on_foe_slain() -> void:
	if dead or skill_rank("second_wind") <= 0 or hp >= max_hp:
		return
	hp = minf(max_hp, hp + max_hp * 0.10)
	hp_changed.emit(hp, max_hp)

func xp_multiplier() -> float:
	return float(ItemDB.get_item(accessory).get("xp_mult", 1.0))

func is_chilled() -> bool:
	return _chill_timer > 0.0

## True if the spell is usable: by level, or unlocked via quest reward.
func is_spell_unlocked(spell_id: String) -> bool:
	if level >= int(Spells.get_info(spell_id).get("unlock_level", 99)):
		return true
	return String(spell_id) in bonus_spells

## Grant a quest-reward spell permanently.
func unlock_spell(spell_id: String) -> void:
	if String(spell_id) not in bonus_spells:
		bonus_spells.append(String(spell_id))

@onready var rig: Node3D = $HeroRig
@onready var anim: AnimationPlayer = $HeroRig/AnimationPlayer

func _ready() -> void:
	add_to_group("player")
	for prop_name in HIDDEN_PROPS:
		var prop := rig.find_child(prop_name) as MeshInstance3D
		if prop != null:
			prop.visible = false
	_apply_two_tone()
	anim.play(ANIM_IDLE)

func _process(delta: float) -> void:
	# Total adventuring time (pauses with the game).
	play_time += delta
	# Mana regenerates over time.
	if not dead and mp < max_mp:
		mp = minf(max_mp, mp + mp_regen_rate() * delta)
		mp_changed.emit(mp, max_mp)

## Black-outside / red-inside materials for the hood and the cape.
## Colors update based on equipped cape/hood levels.
func _apply_two_tone() -> void:
	var head := rig.find_child("Rogue_Head_Hooded") as MeshInstance3D
	if head != null:
		_hood_mat = ShaderMaterial.new()
		_hood_mat.shader = HOOD_SHADER
		_hood_mat.set_shader_parameter("albedo_tex", ROGUE_TEXTURE)
		head.set_surface_override_material(0, _hood_mat)
	var cape := rig.find_child("Rogue_Cape") as MeshInstance3D
	if cape != null:
		_cape_mat = ShaderMaterial.new()
		_cape_mat.shader = CAPE_SHADER
		cape.set_surface_override_material(0, _cape_mat)
	_update_equipment_colors()

## Update hood/cape colors from equipped levels.
func _update_equipment_colors() -> void:
	if _hood_mat != null:
		var hood_color := Equipment.get_color(hood_level)
		_hood_mat.set_shader_parameter("outside_color", Vector3(hood_color.r, hood_color.g, hood_color.b))
		# Keep the red lining, or match it to the hood? Keep red for now.
	if _cape_mat != null:
		var cape_color := Equipment.get_color(cape_level)
		_cape_mat.set_shader_parameter("outside_color", Vector3(cape_color.r, cape_color.g, cape_color.b))

## Equip a cape level. Returns true if equipped (must be higher than current).
func equip_cape(level: int) -> bool:
	if level <= cape_level or level > Equipment.MAX_LEVEL:
		return false
	var old_bonus := Equipment.cape_hp_bonus(cape_level)
	cape_level = level
	var new_bonus := Equipment.cape_hp_bonus(cape_level)
	# Add the delta to max_hp and heal it.
	var delta := new_bonus - old_bonus
	max_hp += delta
	hp = minf(max_hp, hp + delta)
	hp_changed.emit(hp, max_hp)
	_update_equipment_colors()
	equipment_changed.emit()
	return true

## Equip a hood level. Returns true if equipped.
func equip_hood(level: int) -> bool:
	if level <= hood_level or level > Equipment.MAX_LEVEL:
		return false
	var old_bonus := Equipment.hood_attack_bonus(hood_level)
	hood_level = level
	var new_bonus := Equipment.hood_attack_bonus(hood_level)
	attack_damage += new_bonus - old_bonus
	_update_equipment_colors()
	equipment_changed.emit()
	return true

## Called after loading a save: set levels and update colors
## (stats are already in the save, so no bonus recalc needed).
func load_equipment(cape: int, hood: int, weapon: int = 0) -> void:
	cape_level = cape
	hood_level = hood
	weapon_level = weapon
	_update_equipment_colors()
	equipment_changed.emit()

## Equip a weapon level. Returns true if equipped.
func equip_weapon(level: int) -> bool:
	if level <= weapon_level or level > Equipment.MAX_LEVEL:
		return false
	var old_bonus := Equipment.weapon_attack_bonus(weapon_level)
	weapon_level = level
	var new_bonus := Equipment.weapon_attack_bonus(weapon_level)
	attack_damage += new_bonus - old_bonus
	equipment_changed.emit()
	return true

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_chill_timer = maxf(0.0, _chill_timer - delta)

	# ATB gauge fills in real time; full bar = ready to act.
	if atb < 1.0 and _attack_timer <= 0.0 and _dodge_timer <= 0.0:
		atb = minf(1.0, atb + delta / atb_fill_time())
		atb_changed.emit(atb)

	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("cast"):
		cast_spell()
	if Input.is_action_just_pressed("dodge"):
		try_dodge()
	if Input.is_action_just_pressed("sprint"):
		toggle_sprint()
	if Input.is_action_just_pressed("use_potion"):
		if not use_potion():
			AudioMan.play("click", 0.8, -4.0)
	if Input.is_action_just_pressed("party_command"):
		PartyMan.cycle_stance_all()

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	# Add virtual joystick input (touch controls) when present.
	var joystick := get_tree().get_first_node_in_group("virtual_joystick")
	if joystick != null:
		input_dir += joystick.output
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Camera is angled, but movement stays world-aligned like classic FF:
	# Up = north (-Z), Down = south (+Z), Left/Right = X.
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var busy := _attack_timer > 0.0 or _dodge_timer > 0.0 or _hit_timer > 0.0

	if _dodge_timer > 0.0:
		# Dodge dash: committed movement in the dodge direction.
		var t := 1.0 - _dodge_timer / DODGE_TIME
		var dash_speed := dodge_distance() / DODGE_TIME * (1.0 - t * 0.5)
		velocity.x = _dodge_dir.x * dash_speed
		velocity.z = _dodge_dir.z * dash_speed
	elif _attack_timer > 0.0:
		# Attack lunge: drive forward through the swing.
		velocity.x = _attack_dir.x * 7.0
		velocity.z = _attack_dir.z * 7.0
	elif direction != Vector3.ZERO and not busy:
		var move_speed := speed * (SPRINT_MULT if sprinting else 1.0)
		if _chill_timer > 0.0:
			move_speed *= 0.6 # Chilled: sluggish in the cold.
		velocity.x = move_toward(velocity.x, direction.x * move_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, accel * delta)
		# Smoothly turn the 3D model to face the movement direction.
		var target_yaw := atan2(direction.x, direction.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
		_play(ANIM_WALK)
	else:
		if not busy:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)
			velocity.z = move_toward(velocity.z, 0.0, accel * delta)
			anim.speed_scale = 1.0
			_play(ANIM_IDLE)

	# Simple gravity for 2.5D grounding.
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_footsteps(delta)

## A soft step every stride while walking on the ground.
func _footsteps(delta: float) -> void:
	var speed_xz := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or speed_xz < 1.0 or _dodge_timer > 0.0:
		_step_dist = 0.0
		return
	_step_dist += speed_xz * delta
	var stride := 1.5 if sprinting else 1.1
	if _step_dist >= stride:
		_step_dist = 0.0
		AudioMan.play("step", randf_range(0.9, 1.1), -14.0)

## Toggle sprint on/off (run button or F key).
func toggle_sprint() -> void:
	if dead:
		return
	sprinting = not sprinting
	if not sprinting:
		anim.speed_scale = 1.0
	sprint_changed.emit(sprinting)

## XP needed to go from the current level to the next.
func xp_for_next() -> int:
	return XP_BASE * level

## Award XP (called on skeleton kills). Handles multi-level-ups.
func gain_xp(amount: int) -> void:
	if dead:
		return
	xp += int(round(amount * xp_multiplier()))
	var leveled := false
	while xp >= xp_for_next():
		xp -= xp_for_next()
		level += 1
		max_hp += 15.0
		max_mp += 5.0
		attack_damage += 2.0
		hp = max_hp  # full heal on level up
		mp = max_mp
		skill_points += 1
		leveled = true
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	xp_changed.emit(xp, xp_for_next(), level)
	if leveled:
		AudioMan.play("levelup")
		skills_changed.emit()
		leveled_up.emit(level)

func add_potion(count: int) -> void:
	potions += count
	potions_changed.emit(potions)

## Re-emit every stat signal so the HUD and menus match the current values
## (used after loading a save, which writes fields directly).
func emit_all_stats() -> void:
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	atb_changed.emit(atb)
	xp_changed.emit(xp, xp_for_next(), level)
	gold_changed.emit(gold)
	potions_changed.emit(potions)
	equipment_changed.emit()
	items_changed.emit()
	skills_changed.emit()

func use_potion() -> bool:
	if dead or potions <= 0 or hp >= max_hp:
		return false
	potions -= 1
	hp = minf(max_hp, hp + 50.0)
	hp_changed.emit(hp, max_hp)
	potions_changed.emit(potions)
	AudioMan.play("potion_drink", 1.0, 0.0)
	return true

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

## ATB attack: needs a full gauge. Heavy horizontal slash with a lunge,
## a white slash arc, and a hit-stop kick on connect.
func try_attack() -> void:
	if dead or atb < 1.0 or _attack_timer > 0.0 or _dodge_timer > 0.0 or _hit_timer > 0.0:
		return
	atb = 0.0
	atb_changed.emit(atb)
	_attack_timer = 0.38
	_attack_dir = Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	_play(ANIM_ATTACK)
	AudioMan.play("swing")
	_spawn_slash()
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_callback(_deal_attack_hit.bind(1.0))
	if skill_rank("twin_slash") > 0:
		tw.tween_interval(0.14)
		tw.tween_callback(_deal_attack_hit.bind(0.5))

func _deal_attack_hit(scale_dmg := 1.0) -> void:
	if dead:
		return
	var facing := Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	var hit_any := false
	for node in get_tree().get_nodes_in_group("skeletons"):
		if node == null or bool(node.get("dead")):
			continue
		if not node.has_method("take_damage"):
			continue
		var to: Vector3 = node.global_position - global_position
		to.y = 0.0
		if to.length() > ATTACK_RANGE:
			continue
		if to.normalized().dot(facing) < 0.2:
			continue
		node.take_damage(total_attack() * attack_multiplier() * scale_dmg, global_position)
		hit_any = true
	if hit_any:
		AudioMan.play("hit")
		_hit_stop()

## Cast the currently selected spell. Returns false if it fizzles
## (not enough MP, dead, or spell locked).
func cast_spell() -> bool:
	return cast_specific_spell(selected_spell)

func cast_specific_spell(spell_id: String) -> bool:
	if dead:
		return false
	var info := Spells.get_info(spell_id)
	if info.is_empty():
		return false
	if not is_spell_unlocked(spell_id):
		return false
	var cost := spell_cost(int(info["mp"]))
	if mp < cost:
		AudioMan.play("click")
		return false
	mp -= cost
	mp_changed.emit(mp, max_mp)
	var facing := Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	match String(info["kind"]):
		"projectile":
			var dmg := total_attack() * float(info["dmg_mult"])
			var proj := MagicProjectile.create(spell_id, global_position, facing, dmg)
			get_parent().add_child(proj)
			_play(ANIM_ATTACK)
			AudioMan.play("cast")
		"instant":
			var heal_amount := max_hp * float(info.get("heal_frac", 0.4))
			hp = minf(max_hp, hp + heal_amount)
			hp_changed.emit(hp, max_hp)
			HitEffects.burst(get_parent(), global_position + Vector3(0, 1.0, 0), info["color"])
			HitEffects.damage_number(get_parent(), global_position + Vector3(0, 2.2, 0),
				"+%d" % int(heal_amount), Color(0.3, 1.0, 0.5))
			AudioMan.play("heal")
	return true

## Heal the player by amount (used by Mira's mending and other helpers).
func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)
	HitEffects.damage_number(get_parent(), global_position + Vector3(0, 2.2, 0),
		"+%d" % int(amount), Color(0.3, 1.0, 0.5))

## Switch the selected spell (from the MAGIC tab).
func select_spell(spell_id: String) -> void:
	if is_spell_unlocked(spell_id):
		selected_spell = spell_id

## Brief freeze on connect — the classic fighting-game impact feel.
func _hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.06, true, false, true).timeout
	Engine.time_scale = 1.0

## White crescent slash arc that sweeps and fades.
func _spawn_slash() -> void:
	if _slash != null and is_instance_valid(_slash):
		_slash.queue_free()
	_slash = MeshInstance3D.new()
	_slash.mesh = _build_slash_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash.material_override = mat
	add_child(_slash)
	_slash.position = Vector3(0, 1.1, 0)
	_slash.rotation.y = rig.rotation.y - PI * 0.35
	var tw := _slash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_slash, "rotation:y", _slash.rotation.y + PI * 0.7, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(_slash.queue_free)

## A flat 100-degree crescent fan, 1.6m radius.
static func _build_slash_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var steps := 10
	var radius := 1.6
	var inner := 0.7
	var arc := deg_to_rad(100.0)
	for i in range(steps + 1):
		var a := -arc * 0.5 + arc * float(i) / float(steps)
		var dir := Vector3(sin(a), 0, cos(a))
		verts.append(dir * inner)
		verts.append(dir * radius)
		if i < steps:
			var b := i * 2
			indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## ATB dodge: quick dash with i-frames. Direction of movement, else facing.
func try_dodge() -> void:
	if dead or _dodge_cd > 0.0 or _dodge_timer > 0.0 or _attack_timer > 0.0 or _hit_timer > 0.0:
		return
	if atb < 1.0:
		return
	atb = 0.0
	atb_changed.emit(atb)
	_dodge_cd = 0.9
	_dodge_timer = DODGE_TIME
	_iframes = DODGE_IFRAMES
	AudioMan.play("dodge", 1.0, -4.0)
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	var joystick := get_tree().get_first_node_in_group("virtual_joystick")
	if joystick != null:
		input_dir += joystick.output
	if input_dir.length() > 0.2:
		_dodge_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		_dodge_dir = Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	rig.rotation.y = atan2(_dodge_dir.x, _dodge_dir.z)
	_play(ANIM_DODGE)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead or _iframes > 0.0:
		return
	amount *= damage_taken_multiplier()
	hp -= amount
	hp_changed.emit(hp, max_hp)
	AudioMan.play("hit", 0.7, -2.0)
	# Red damage number above the player.
	HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 1.8, 0), "-%d" % int(amount), Color(1.0, 0.3, 0.25))
	if hp <= 0.0:
		_die()
	else:
		_hit_timer = 0.35
		_play(ANIM_HIT)
		var away: Vector3 = global_position - from_pos
		away.y = 0.0
		if away.length() > 0.01:
			velocity = away.normalized() * 6.0

func _die() -> void:
	dead = true
	deaths += 1
	hp = 0.0
	atb = 0.0
	velocity = Vector3.ZERO
	if sprinting:
		toggle_sprint()
	_play(ANIM_DEATH)
	# Death costs a cut of your purse; the rest of you wakes at the well.
	var lost := int(floor(gold * DEATH_GOLD_LOSS))
	if lost > 0:
		gold -= lost
		gold_changed.emit(gold)
		HitEffects.damage_number(get_tree().current_scene,
			global_position + Vector3(0, 2.4, 0), "-%d G" % lost, Color(1.0, 0.75, 0.2))
	died.emit()
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(_respawn)

func _respawn() -> void:
	global_position = RESPAWN_POS
	velocity = Vector3.ZERO
	# The party comes back with you. Left behind, companions kept fighting
	# a boss that had just healed to full, went down, and stayed down for
	# half a minute — and a sleeping region has no floor to stand on.
	PartyMan.teleport_with(RESPAWN_POS)
	hp = max_hp
	mp = max_mp
	atb = 1.0
	_attack_timer = 0.0
	_hit_timer = 0.0
	_dodge_timer = 0.0
	_dodge_cd = 0.0
	_iframes = 0.0
	dead = false
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	atb_changed.emit(atb)
	_play(ANIM_IDLE)

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		anim.speed_scale = 1.45 if (clip == ANIM_WALK and sprinting) else 1.0
		anim.play(clip)
