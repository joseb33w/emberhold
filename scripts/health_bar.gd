class_name HealthBar3D
extends Node3D
## A small camera-facing health bar (background + fill) floated above an actor.

const W := 1.1
const H := 0.16

var _fill_pivot: Node3D
var _fill_mat: StandardMaterial3D
var _frac := 1.0


func setup(fill_color: Color = Color(0.35, 0.85, 0.35)) -> void:
	var bg := MeshInstance3D.new()
	var bgq := QuadMesh.new()
	bgq.size = Vector2(W + 0.08, H + 0.06)
	bg.mesh = bgq
	bg.material_override = _mat(Color(0.05, 0.04, 0.06), -0.001)
	add_child(bg)

	_fill_pivot = Node3D.new()
	_fill_pivot.position = Vector3(-W * 0.5, 0, 0)
	add_child(_fill_pivot)
	var fill := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(W, H)
	fill.mesh = fq
	fill.position = Vector3(W * 0.5, 0, 0.001)
	_fill_mat = _mat(fill_color, 0.0)
	fill.material_override = _fill_mat
	_fill_pivot.add_child(fill)


func set_fraction(frac: float) -> void:
	_frac = clampf(frac, 0.0, 1.0)
	_fill_pivot.scale.x = max(_frac, 0.001)
	_fill_mat.albedo_color = Color(0.85, 0.25, 0.2) if _frac < 0.34 else (Color(0.9, 0.75, 0.25) if _frac < 0.6 else Color(0.35, 0.85, 0.35))


func _mat(c: Color, _z: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = 2
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return m
