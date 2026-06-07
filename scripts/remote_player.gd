class_name RemotePlayer
extends Node3D
## A networked peer's hero: interpolated transform, name tag, health bar, and
## relayed one-shot actions. Snaps to the FIRST received transform so peers don't
## materialize on your face and glide.

const MAX_HP := 100.0

var rig: CharacterRig
var name_label: Label3D
var bar: HealthBar3D
var peer_name := "Hero"
var hero_path := "res://models/kk_Rogue.glb"

var _target := Vector3.ZERO
var _have_first := false
var _target_yaw := 0.0
var _vis_speed := 0.0
var _hp := MAX_HP
var _dead := false


func configure(path: String, nm: String) -> void:
	hero_path = path
	peer_name = nm


func _ready() -> void:
	rig = CharacterRig.new()
	add_child(rig)
	var weapon := ""
	var shield := ""
	if not hero_path.ends_with("kk_Mage.glb"):
		weapon = "res://models/props/axe_A.glb"
		shield = "res://models/props/shield_B.glb"
	rig.setup(hero_path, Color(0.06, 0.05, 0.08), weapon, shield)

	name_label = Label3D.new()
	name_label.text = peer_name
	name_label.position = Vector3(0, 2.45, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.fixed_size = false
	name_label.pixel_size = 0.0095
	name_label.font_size = 40
	name_label.outline_size = 12
	name_label.modulate = Color(0.6, 0.85, 1.0)
	add_child(name_label)

	bar = HealthBar3D.new()
	bar.position = Vector3(0, 2.5, 0)
	bar.scale = Vector3(0.7, 0.7, 0.7)
	add_child(bar)
	bar.setup(Color(0.4, 0.7, 1.0))
	add_to_group("targets")


func is_targetable() -> bool:
	return not _dead


func apply_state(pos: Vector3, ry: float, hp: float, dead: bool) -> void:
	if not _have_first:
		_have_first = true
		global_position = pos
	_target = pos
	_target_yaw = ry
	_hp = hp
	if bar != null:
		bar.set_fraction(hp / MAX_HP)
	if dead and not _dead:
		_dead = true
		rig.die()
	elif not dead and _dead:
		_dead = false
		rig.revive()


func play_act(a: String) -> void:
	match a:
		"attack":
			rig.play_attack(hero_path.ends_with("kk_Mage.glb"))
		"dodge":
			rig.play_dodge()
		"wave":
			rig.play_emote("wave")
		"cheer":
			rig.play_emote("cheer")
		"hit":
			rig.play_hit()


func _process(delta: float) -> void:
	var prev := global_position
	global_position = global_position.lerp(_target, clampf(delta * 12.0, 0, 1))
	if rig != null:
		rig.rotation.y = lerp_angle(rig.rotation.y, _target_yaw, clampf(delta * 12.0, 0, 1))
		var inst := (global_position - prev).length() / maxf(delta, 0.0001)
		_vis_speed = lerpf(_vis_speed, inst, clampf(delta * 8.0, 0, 1))
		rig.update_locomotion(_vis_speed)
