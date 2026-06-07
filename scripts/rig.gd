class_name CharacterRig
extends Node3D
## Wraps a KayKit Rig_Medium .glb: drives its AnimationPlayer (locomotion blend +
## one-shots), applies an inverted-hull ink outline, and attaches held weapons/shields.
## KayKit characters model-face +Z, which matches `atan2(dir.x, dir.z)` for facing
## (NO +PI offset). Feet sit at y=0.

const IDLE := "Idle_A"
const WALK := "Walking_C"
const RUN := "Running_A"

var anim: AnimationPlayer
var skeleton: Skeleton3D
var model: Node3D

var _busy := false
var _dead := false
var _cur_loco := ""
var _oneshot := ""
var _attachments: Array[Node] = []

signal oneshot_finished(name: String)

static var _outline_mat: ShaderMaterial


func setup(model_path: String, outline_color: Color = Color(0.05, 0.04, 0.06)) -> void:
	var packed: PackedScene = load(model_path)
	model = packed.instantiate()
	add_child(model)
	anim = _find_anim(model)
	skeleton = _find_skel(model)
	if anim != null:
		for c in [IDLE, WALK, RUN]:
			if anim.has_animation(c):
				anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_anim_finished)
		_play_loco(IDLE)
	_apply_outline(outline_color)


func has_clip(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


func attach_weapon(rhand_path: String, lhand_path: String) -> void:
	# Swap the held models: drop whatever we attached last, then attach the new set.
	for n in _attachments:
		if is_instance_valid(n):
			n.queue_free()
	_attachments.clear()
	if skeleton == null:
		return
	if rhand_path != "":
		_attach(rhand_path, "handslot_r")
	if lhand_path != "":
		_attach(lhand_path, "handslot_l")


func update_locomotion(speed: float) -> void:
	if _busy or _dead or anim == null:
		return
	var target := IDLE
	if speed >= 4.6:
		target = RUN
	elif speed >= 0.35:
		target = WALK
	if target != _cur_loco:
		_play_loco(target)


func play_oneshot(clip: String, lock := true, custom_speed := 1.0) -> void:
	if _dead or anim == null or not anim.has_animation(clip):
		return
	_oneshot = clip
	if lock:
		_busy = true
	anim.play(clip, 0.12, custom_speed)


func play_attack(spell := false) -> void:
	play_oneshot("Ranged_Magic_Spellcasting" if spell else "Melee_1H_Attack_Slice_Horizontal", true, 1.3)


func play_hit() -> void:
	if _dead:
		return
	play_oneshot("Hit_A", true)


func play_dodge() -> void:
	play_oneshot("Dodge_Forward", true, 1.0)


func play_emote(which: String) -> void:
	play_oneshot("Cheering" if which == "cheer" else "Waving", true)


func die() -> void:
	if _dead:
		return
	_dead = true
	_busy = true
	if anim != null and anim.has_animation("Death_A"):
		anim.play("Death_A", 0.15)


func revive() -> void:
	_dead = false
	_busy = false
	_cur_loco = ""
	if anim != null:
		_play_loco(IDLE)


func is_dead() -> bool:
	return _dead


func tint(c: Color) -> void:
	for mi in _meshes(model):
		var m: MeshInstance3D = mi
		for i in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_surface_override_material(i)
			if mat is StandardMaterial3D:
				var sm: StandardMaterial3D = mat
				sm.albedo_color = sm.albedo_color * c


func flash(color: Color = Color(1, 1, 1)) -> void:
	for mi in _meshes(model):
		var m: MeshInstance3D = mi
		for i in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_surface_override_material(i)
			if mat is StandardMaterial3D:
				var sm: StandardMaterial3D = mat
				sm.emission_enabled = true
				sm.emission = color
				var tw := create_tween()
				tw.tween_method(func(e: float) -> void: sm.emission_energy_multiplier = e, 2.2, 0.0, 0.22)


func seek_random() -> void:
	if anim != null and anim.has_animation(_cur_loco):
		anim.seek(randf() * anim.get_animation(_cur_loco).length, true)


func _play_loco(clip: String) -> void:
	_cur_loco = clip
	if anim != null and anim.has_animation(clip):
		anim.play(clip, 0.18)


func _on_anim_finished(name: StringName) -> void:
	if str(name) == _oneshot:
		_oneshot = ""
		if not _dead:
			_busy = false
			_cur_loco = ""
			_play_loco(IDLE)
		oneshot_finished.emit(str(name))


func _attach(path: String, bone: String) -> void:
	var idx := skeleton.find_bone(bone)
	if idx < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var w: Node3D = packed.instantiate()
	ba.add_child(w)
	_attachments.append(ba)


func _apply_outline(col: Color) -> void:
	if _outline_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float outline = 0.02;
uniform vec4 col : source_color = vec4(0.05,0.04,0.06,1.0);
void vertex() { VERTEX += normalize(NORMAL) * outline; }
void fragment() { ALBEDO = col.rgb; }
"""
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = sh
	var mat := _outline_mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter("col", col)
	mat.set_shader_parameter("outline", 0.02)
	for mi in _meshes(model):
		var m: MeshInstance3D = mi
		var surfaces := m.mesh.get_surface_count()
		for i in range(surfaces):
			var src: Material = m.get_active_material(i)
			var dup: Material = src.duplicate() if src != null else StandardMaterial3D.new()
			dup.next_pass = mat
			m.set_surface_override_material(i, dup)


func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null
