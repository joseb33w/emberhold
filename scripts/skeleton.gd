class_name Skeleton
extends CharacterBody3D
## Dungeon enemy. On the HOST client it runs full AI (patrol / chase / attack) and
## owns its health; on other clients it's a `replica` driven by network state.
## Player-damage is resolved centrally in main via the `did_swing` signal so a
## host-simulated skeleton can also hurt a remote peer standing next to it.

const MAX_HP := 60.0
const PATROL_SPEED := 2.4
const CHASE_SPEED := 4.2
const GRAVITY := 18.0
const DETECT := 13.0
const ATTACK_RANGE := 2.3
const ATTACK_CD := 1.7
const DAMAGE := 10.0

signal did_swing(origin: Vector3)

var eid := ""
var replica := false
var hp := MAX_HP
var dead := false
var spawn_point := Vector3.ZERO

var rig: CharacterRig
var bar: HealthBar3D

var _state := "patrol"
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _attack_cd := 0.0
var _respawn_t := 0.0
var _swing_pending := false
var _net_target := Vector3.ZERO
var _net_yaw := 0.0
var _have_net := false
var _swing_pulse := false
var _swing_announce := false


func setup(model_path: String, tint_col: Color, sc: float) -> void:
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	rig = CharacterRig.new()
	rig.scale = Vector3(sc, sc, sc)
	add_child(rig)
	rig.setup(model_path, Color(0.04, 0.03, 0.05))
	rig.tint(tint_col)
	rig.seek_random()
	rig.oneshot_finished.connect(_on_rig_oneshot)

	bar = HealthBar3D.new()
	bar.position = Vector3(0, 2.15 * sc, 0)
	bar.scale = Vector3(0.6, 0.6, 0.6)
	add_child(bar)
	bar.setup()


func _physics_process(delta: float) -> void:
	if replica:
		_replica_step(delta)
		return
	_host_step(delta)


func _host_step(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	if dead:
		_respawn_t -= delta
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		if _respawn_t <= 0.0:
			_revive()
		return

	var target := _nearest_target()
	var planar := Vector3.ZERO
	if target != null:
		var to_t: Vector3 = target.global_position - global_position
		var dist := Vector2(to_t.x, to_t.z).length()
		if dist <= ATTACK_RANGE:
			_state = "attack"
			planar = Vector3.ZERO
			_face_to(to_t, delta)
			if _attack_cd <= 0.0:
				_attack_cd = ATTACK_CD
				rig.play_attack(false)
				_swing_pending = true
				_swing_announce = true
				get_tree().create_timer(0.32).timeout.connect(_do_swing)
		elif dist <= DETECT:
			_state = "chase"
			var dir := to_t
			dir.y = 0
			dir = dir.normalized()
			planar = dir * CHASE_SPEED
			_face_to(to_t, delta)
		else:
			target = null
	if target == null:
		_state = "patrol"
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.5, 3.5)
			var ang := randf() * TAU
			_wander = (spawn_point + Vector3(cos(ang), 0, sin(ang)) * randf_range(2.0, 6.0))
		var to_w := _wander - global_position
		to_w.y = 0
		if to_w.length() > 0.6:
			var d := to_w.normalized()
			planar = d * PATROL_SPEED
			_face_to(to_w, delta)

	velocity.x = planar.x
	velocity.z = planar.z
	move_and_slide()
	if not rig.is_dead():
		rig.update_locomotion(Vector2(velocity.x, velocity.z).length())


func _replica_step(delta: float) -> void:
	if not _have_net:
		return
	global_position = global_position.lerp(_net_target, clampf(delta * 12.0, 0, 1))
	if not rig.is_dead():
		rig.rotation.y = lerp_angle(rig.rotation.y, _net_yaw, clampf(delta * 12.0, 0, 1))
		var spd := (_net_target - global_position).length() / maxf(delta, 0.0001)
		rig.update_locomotion(clampf(spd, 0.0, 6.0))


func _face_to(to_t: Vector3, delta: float) -> void:
	if to_t.length() < 0.05:
		return
	var yaw := atan2(to_t.x, to_t.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, clampf(delta * 10.0, 0, 1))


func _do_swing() -> void:
	if dead or not _swing_pending:
		return
	_swing_pending = false
	did_swing.emit(global_position + Vector3(0, 1.0, 0))


func _nearest_target() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for n in get_tree().get_nodes_in_group("targets"):
		var t := n as Node3D
		if t == null:
			continue
		if t.has_method("is_targetable") and not t.is_targetable():
			continue
		var d := t.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = t
	return best


func apply_damage(amount: float) -> bool:
	# returns true if this hit killed the skeleton (host authority)
	if dead:
		return false
	hp = maxf(0.0, hp - amount)
	bar.set_fraction(hp / MAX_HP)
	if hp <= 0.0:
		_die()
		return true
	rig.play_hit()
	return false


func _die() -> void:
	dead = true
	_respawn_t = 6.0
	rig.die()


func _revive() -> void:
	dead = false
	hp = MAX_HP
	global_position = spawn_point
	bar.set_fraction(1.0)
	rig.revive()


func local_hit_flash() -> void:
	# immediate feedback on the client that landed the hit (juice before net confirm)
	if not dead:
		rig.play_hit()


func apply_net(pos: Vector3, ry: float, nhp: float, ndead: bool, swing: bool) -> void:
	_net_target = pos
	_net_yaw = ry
	_have_net = true
	hp = nhp
	if bar != null:
		bar.set_fraction(nhp / MAX_HP)
	if ndead and not dead:
		dead = true
		rig.die()
	elif not ndead and dead:
		dead = false
		rig.revive()
	if swing and not dead:
		rig.play_attack(false)
		_swing_pulse = true
		get_tree().create_timer(0.32).timeout.connect(func() -> void:
			if not dead and _swing_pulse:
				_swing_pulse = false
				did_swing.emit(global_position + Vector3(0, 1.0, 0)))


func net_state() -> Dictionary:
	var swing := 1 if _swing_announce else 0
	_swing_announce = false
	return {
		"id": eid,
		"x": snappedf(global_position.x, 0.01),
		"z": snappedf(global_position.z, 0.01),
		"ry": snappedf(rig.rotation.y, 0.01),
		"hp": snappedf(hp, 0.1),
		"d": 1 if dead else 0,
		"sw": swing,
	}


func _on_rig_oneshot(_n: String) -> void:
	pass
