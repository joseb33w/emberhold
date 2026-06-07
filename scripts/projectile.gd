class_name Projectile
extends Node3D
## A traveling bow arrow / magic bolt. Moves forward each physics frame, queries the
## "skeletons" and "targets" groups for a hit (skipping the shooter and the dead), and
## emits `struck(pos, node)` so main can route it through the shared damage + juice path.
## Self-frees on hit or when its range is spent.

signal struck(pos: Vector3, node: Node)

var _vel := Vector3.ZERO
var _life := 1.0
var _radius := 1.1
var shooter: Node = null


func setup(origin: Vector3, dir: Vector3, speed: float, rng: float, color: Color, is_spell: bool, shooter_node: Node) -> void:
	global_position = origin
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	_vel = d * speed
	_life = clampf(rng / maxf(speed, 0.01), 0.2, 3.0)
	shooter = shooter_node

	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.5
	if is_spell:
		var sm := SphereMesh.new()
		sm.radius = 0.24
		sm.height = 0.48
		mi.mesh = sm
	else:
		var cm := CapsuleMesh.new()
		cm.radius = 0.06
		cm.height = 0.95
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
	mi.material_override = mat
	add_child(mi)
	look_at(global_position + d, Vector3.UP)

	var trail := CPUParticles3D.new()
	trail.amount = 14
	trail.lifetime = 0.32
	trail.local_coords = false
	trail.direction = Vector3.ZERO
	trail.spread = 12.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.4
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.22
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = color
	tmat.emission_enabled = true
	tmat.emission = color
	tmat.emission_energy_multiplier = 3.0
	trail.mesh = SphereMesh.new()
	trail.material_override = tmat
	trail.emitting = true
	add_child(trail)


func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var hit := _scan()
	if hit != null:
		struck.emit(global_position, hit)
		queue_free()


func _scan() -> Node:
	var here := global_position
	for s in get_tree().get_nodes_in_group("skeletons"):
		var sk := s as Skeleton
		if sk == null or sk.dead:
			continue
		if here.distance_to(sk.global_position + Vector3(0, 1.0, 0)) <= _radius:
			return sk
	for t in get_tree().get_nodes_in_group("targets"):
		if t == shooter:
			continue
		var rp := t as RemotePlayer
		if rp == null or not rp.is_targetable():
			continue
		if here.distance_to(rp.global_position + Vector3(0, 1.0, 0)) <= _radius:
			return rp
	return null
