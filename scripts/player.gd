class_name Player
extends CharacterBody3D
## Local hero: third-person movement with a SpringArm follow camera, KayKit rig with
## locomotion blend, and a full ARSENAL — each weapon has its own held models, a light
## combo + a heavy attack, distinct damage/reach/arc/cadence, and (for bow/arcane) a
## traveling projectile. Attacks aim-snap toward the nearest enemy so taps never whiff.
## Facing uses atan2(dir.x, dir.z) for the +Z-facing KayKit model (no PI offset).

const SPEED := 6.0
const RUN_SPEED := 6.0
const GRAVITY := 18.0
const LOOK_SENS := 0.005
const MAX_HP := 100.0

signal melee_swing(origin: Vector3, fwd: Vector3, dmg: float, rng: float, arc: float, heavy: bool)
signal ranged_fire(origin: Vector3, dir: Vector3, dmg: float, rng: float, color: Color, speed: float, spell: bool, heavy: bool)
signal health_changed(hp: float, maxhp: float)
signal weapon_changed(index: int, label: String)
signal died()
signal respawned()

var hp := MAX_HP
var hero_name := "Hero"
var hero_path := "res://models/kk_Knight.glb"
var is_mage := false
var dead := false
var spawn_point := Vector3.ZERO

var weapon_index := 0
var weapon: Dictionary = {}

var rig: CharacterRig
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var name_label: Label3D

var move_input := Vector2.ZERO
var _cam_yaw := 0.0
var _cam_pitch := -0.35
var _attack_cd := 0.0
var _dodge_cd := 0.0
var _foot_t := 0.0
var _dodge_dir := Vector3.ZERO
var _dodge_time := 0.0
var _face_yaw := 0.0
var _shake := 0.0
var _combo_i := 0
var _combo_t := 0.0


func add_shake(m: float) -> void:
	_shake = minf(0.8, _shake + m)


func invulnerable() -> bool:
	return _dodge_time > 0.0


func configure(path: String, nm: String, mage: bool) -> void:
	hero_path = path
	hero_name = nm
	is_mage = mage


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	rig = CharacterRig.new()
	add_child(rig)
	rig.setup(hero_path, Color(0.05, 0.04, 0.06))

	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, 1.45, 0)
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 5.2
	spring.collision_mask = 1
	spring.margin = 0.3
	spring.rotation.x = _cam_pitch
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 68.0
	spring.add_child(camera)

	name_label = Label3D.new()
	name_label.text = hero_name
	name_label.position = Vector3(0, 2.45, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.fixed_size = false
	name_label.pixel_size = 0.0095
	name_label.font_size = 40
	name_label.outline_size = 12
	name_label.modulate = Color(0.95, 0.85, 0.55)
	add_child(name_label)
	add_to_group("targets")

	equip_weapon(Weapons.start_for(_hero_key()))


func _hero_key() -> String:
	if hero_path.ends_with("kk_Mage.glb"):
		return "mage"
	if hero_path.ends_with("kk_Rogue.glb"):
		return "rogue"
	return "knight"


func equip_weapon(i: int) -> void:
	weapon_index = posmod(i, Weapons.count())
	weapon = Weapons.get_def(weapon_index)
	if rig != null:
		rig.attach_weapon(str(weapon.get("rhand", "")), str(weapon.get("lhand", "")))
	weapon_changed.emit(weapon_index, str(weapon.get("label", "")))


func cycle_weapon() -> void:
	equip_weapon(weapon_index + 1)
	Audio.play_sfx("ui")


func is_targetable() -> bool:
	return not dead


func set_active_camera() -> void:
	if camera != null:
		camera.current = true


func add_look(dx: float, dy: float) -> void:
	_cam_yaw -= dx * LOOK_SENS
	_cam_pitch = clampf(_cam_pitch - dy * LOOK_SENS, -0.95, 0.2)


func _facing_dir() -> Vector3:
	return Basis(Vector3.UP, rig.rotation.y) * Vector3(0, 0, 1)


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_combo_t = maxf(0.0, _combo_t - delta)
	if _combo_t <= 0.0:
		_combo_i = 0

	cam_pivot.rotation.y = _cam_yaw
	spring.rotation.x = _cam_pitch
	if _shake > 0.001:
		camera.h_offset = randf_range(-_shake, _shake)
		camera.v_offset = randf_range(-_shake, _shake)
		_shake = maxf(0.0, _shake - delta * 2.2)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	if dead:
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
		move_and_slide()
		return

	var planar := Vector3.ZERO
	if _dodge_time > 0.0:
		_dodge_time -= delta
		planar = _dodge_dir * 11.0
	else:
		var v := move_input
		if v.length() > 1.0:
			v = v.normalized()
		var dir: Vector3 = Basis(Vector3.UP, _cam_yaw) * Vector3(v.x, 0, v.y)
		planar = dir * SPEED
		if dir.length() > 0.05 and not rig.is_dead():
			_face_yaw = atan2(dir.x, dir.z)

	velocity.x = planar.x
	velocity.z = planar.z
	move_and_slide()

	rig.rotation.y = lerp_angle(rig.rotation.y, _face_yaw, clampf(delta * 12.0, 0, 1))
	var spd := Vector2(velocity.x, velocity.z).length()
	rig.update_locomotion(spd)

	if spd > 1.0 and is_on_floor():
		_foot_t -= delta
		if _foot_t <= 0.0:
			_foot_t = 0.34
			Audio.play_sfx("footstep", -10.0)


func face_towards(pos: Vector3) -> Vector3:
	var to := pos - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return _facing_dir()
	_face_yaw = atan2(to.x, to.z)
	return to.normalized()


func do_light_attack(aim) -> String:
	return _attack(false, aim)


func do_heavy_attack(aim) -> String:
	return _attack(true, aim)


func _attack(heavy: bool, aim) -> String:
	if dead or _attack_cd > 0.0 or weapon.is_empty():
		return ""
	var cd := float(weapon["heavy_cd"]) if heavy else float(weapon["light_cd"])
	_attack_cd = cd
	var clip := ""
	if heavy:
		clip = str(weapon["heavy"])
	else:
		var combo: Array = weapon["light"]
		clip = str(combo[_combo_i % combo.size()])
		_combo_i = (_combo_i + 1) % maxi(1, combo.size())
		_combo_t = 1.1

	var dir: Vector3
	if aim is Vector3:
		dir = face_towards(aim)
	else:
		dir = _facing_dir()

	rig.play_oneshot(clip, true, float(weapon["speed"]))
	Audio.play_sfx("swing", -3.0)

	var dmg := float(weapon["heavy_dmg"]) if heavy else float(weapon["light_dmg"])
	var rng := float(weapon["range"])
	var arc := float(weapon["heavy_arc"]) if heavy else float(weapon["arc"])
	var ranged := bool(weapon["ranged"])
	var spell := bool(weapon["spell"])
	var color: Color = weapon["proj_color"]
	var pspeed := float(weapon["proj_speed"])
	var fire_dir := dir

	get_tree().create_timer(float(weapon["swing_at"])).timeout.connect(func() -> void:
		if dead:
			return
		var o := global_position + Vector3(0, 1.0, 0)
		if ranged:
			ranged_fire.emit(global_position + Vector3(0, 1.3, 0), fire_dir, dmg, rng, color, pspeed, spell, heavy)
		else:
			melee_swing.emit(o, _facing_dir(), dmg, rng, arc, heavy))
	return clip


func do_dodge() -> void:
	if dead or _dodge_cd > 0.0:
		return
	_dodge_cd = 0.9
	rig.play_dodge()
	var fwd: Vector3 = _facing_dir()
	_dodge_dir = fwd
	_dodge_time = 0.32


func do_emote(which: String) -> void:
	if dead:
		return
	rig.play_emote(which)


func apply_damage(amount: float) -> void:
	if dead or _dodge_time > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	health_changed.emit(hp, MAX_HP)
	Audio.play_sfx("takehit", -2.0)
	if hp <= 0.0:
		_die()
	else:
		rig.play_hit()


func _die() -> void:
	dead = true
	rig.die()
	Audio.play_sfx("death", -4.0)
	died.emit()


func respawn() -> void:
	dead = false
	hp = MAX_HP
	global_position = spawn_point
	velocity = Vector3.ZERO
	rig.revive()
	health_changed.emit(hp, MAX_HP)
	respawned.emit()


func net_state() -> Dictionary:
	return {
		"x": global_position.x, "y": global_position.y, "z": global_position.z,
		"ry": rig.rotation.y, "hp": hp, "name": hero_name, "hero": hero_path,
		"wp": weapon_index, "dead": dead,
	}
