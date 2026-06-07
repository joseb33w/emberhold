class_name NPC
extends Node3D
## A talkable hub-town character. Holds its persona + capped conversation history;
## the chat UI + HTTPRequest live in main. Stands and idles (KayKit rig).

const HISTORY_CAP := 12

var npc_name := "NPC"
var persona := ""
var history: Array = []
var rig: CharacterRig
var _label: Label3D


func configure(model_path: String, nm: String, who: String, tint_col: Color) -> void:
	npc_name = nm
	persona = who
	rig = CharacterRig.new()
	add_child(rig)
	rig.setup(model_path, Color(0.05, 0.04, 0.06))
	rig.tint(tint_col)

	_label = Label3D.new()
	_label.text = nm
	_label.position = Vector3(0, 2.55, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.01
	_label.font_size = 40
	_label.outline_size = 12
	_label.modulate = Color(1.0, 0.78, 0.4)
	add_child(_label)

	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.1
	tor.outer_radius = 1.3
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.7, 0.3)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.6, 0.2)
	rm.emission_energy_multiplier = 2.5
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.mesh.material = rm
	ring.position = Vector3(0, 0.06, 0)
	add_child(ring)


func near(p: Vector3, radius := 3.4) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= radius


func push(role: String, content: String) -> void:
	history.append({"role": role, "content": content})
	while history.size() > HISTORY_CAP:
		history.pop_front()


func emote() -> void:
	if rig != null:
		rig.play_emote("wave")
