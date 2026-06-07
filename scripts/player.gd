class_name Player
extends CharacterBody3D
## Local hero: third-person movement with a SpringArm follow camera, KayKit rig
## with locomotion blend + attack/dodge/emote/hit/death, health and respawn.
## Facing uses atan2(dir.x, dir.z) for the +Z-facing KayKit model (no PI offset),
## so it shows its back walking away from the camera and its face walking toward.

const SPEED := 6.0
const RUN_SPEED := 6.0
const GRAVITY := 18.0
const LOOK_SENS := 0.005
const MAX_HP := 100.0

signal melee_swing(origin: Vector3, forward: Vector3, is_spell: bool)
signal health_changed(hp: float, maxhp: float)
signal died()
signal respawned()

var hp := MAX_HP
var hero_name := "Hero"
var hero_path := "res://models/kk_Knight.glb"
var is_mage := false
var dead := false
var spawn_point := Vector3.ZERO

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


func add_shake(m: float) -> void:
	_shake = minf(0.6, _shake + m)


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
	var weapon := ""
	var shield := ""
	if not is_mage:
		weapon = "res://models/props/axe_A.glb"
		shield = "res://models/props/shield_B.glb"
	rig.setup(hero_path, Color(0.05, 0.04, 0.06), weapon, shield)

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


func is_targetable() -> bool:
	return not dead


func set_active_camera() -> void:
	if camera != null:
		camera.current = true


func add_look(dx: float, dy: float) -> void:
	_cam_yaw -= dx * LOOK_SENS
	_cam_pitch = clampf(_cam_pitch - dy * LOOK_SENS, -0.95, 0.2)


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)

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


func do_attack() -> void:
	if dead or _attack_cd > 0.0:
		return
	_attack_cd = 0.55
	rig.play_attack(is_mage)
	Audio.play_sfx("swing", -3.0)
	var fwd: Vector3 = Basis(Vector3.UP, rig.rotation.y) * Vector3(0, 0, 1)
	var tmr := get_tree().create_timer(0.26)
	tmr.timeout.connect(func() -> void:
		if not dead:
			melee_swing.emit(global_position + Vector3(0, 1.0, 0), fwd, is_mage))


func do_dodge() -> void:
	if dead or _dodge_cd > 0.0:
		return
	_dodge_cd = 0.9
	rig.play_dodge()
	var fwd: Vector3 = Basis(Vector3.UP, rig.rotation.y) * Vector3(0, 0, 1)
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
		"dead": dead,
	}
