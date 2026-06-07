class_name World
extends Node3D
## Builds the shared world: a torchlit HUB TOWN at the origin and a DUNGEON far to
## the north (-Z) reached through a glowing descent portal. Returns spawn data for
## main. Everything is one continuous coordinate space so multiplayer peers line up.

const DUNGEON_CTR := Vector3(0, 0, -140)
const TOWN_SPAWN := Vector3(0, 0, 8)
const TOWN_PORTAL := Vector3(0, 0, -26)
const DUNGEON_SPAWN := Vector3(0, 0, -120)
const DUNGEON_PORTAL := Vector3(0, 0, -108)

var skeleton_points: Array[Vector3] = []
var loot_points: Array[Vector3] = []
var npc_specs: Array = []

var _torch_lights: Array[OmniLight3D] = []
var _torch_t := 0.0


func build() -> void:
	_build_town()
	_build_dungeon()


func _process(delta: float) -> void:
	_torch_t += delta
	for i in range(_torch_lights.size()):
		var l := _torch_lights[i]
		l.light_energy = 2.4 + sin(_torch_t * 6.0 + float(i)) * 0.5 + randf() * 0.1


# ----------------------------- TOWN -----------------------------
func _build_town() -> void:
	_ground(Vector3.ZERO, Vector2(110, 110), "res://textures/grass.png", 30, Color(0.62, 0.66, 0.42))
	# stone plaza
	var plaza := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 14.0
	cyl.bottom_radius = 14.0
	cyl.height = 0.2
	plaza.mesh = cyl
	plaza.material_override = _tex_mat("res://textures/stone_floor.png", 6, Color(0.8, 0.8, 0.82))
	plaza.position = Vector3(0, 0.06, 0)
	add_child(plaza)

	var buildings := [
		["res://models/props/building_blacksmith_blue.glb", 0.0],
		["res://models/props/building_tavern_blue.glb", 51.0],
		["res://models/props/building_market_blue.glb", 102.0],
		["res://models/props/building_home_B_blue.glb", 154.0],
		["res://models/props/building_church_blue.glb", 205.0],
		["res://models/props/building_tower_B_blue.glb", 257.0],
		["res://models/props/building_well_blue.glb", 308.0],
	]
	var ring := 19.0
	for b in buildings:
		var ang: float = deg_to_rad(b[1])
		var pos := Vector3(cos(ang) * ring, 0, sin(ang) * ring)
		var face := atan2(-pos.x, -pos.z)
		var sc := 2.0 if str(b[0]).contains("well") else 4.2
		_prop(str(b[0]), pos, sc, face, true, Vector3(5.2, 7, 5.2))

	# blacksmith forge: anvil + warm light
	var smith_pos := Vector3(cos(0) * (ring - 6.0), 0, sin(0) * (ring - 6.0))
	_prop("res://models/props/anvil.glb", smith_pos, 1.6, deg_to_rad(180), false, Vector3.ZERO)
	_torch(smith_pos + Vector3(0.6, 0.0, 0.0), Color(1.0, 0.5, 0.2), 3.2)

	# torch lanterns around the plaza
	for i in range(8):
		var a := deg_to_rad(i * 45.0 + 22.5)
		var p := Vector3(cos(a) * 12.5, 0, sin(a) * 12.5)
		_prop("res://models/props/lantern.glb", p, 1.4, 0, false, Vector3.ZERO)
		_torch(p + Vector3(0, 1.2, 0), Color(1.0, 0.66, 0.32), 2.4)

	# bushes scattered around the edges
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(18):
		var a := rng.randf() * TAU
		var r := rng.randf_range(24.0, 46.0)
		var bp := Vector3(cos(a) * r, 0, sin(a) * r)
		var bush := "res://models/props/Bush_1_A_Color1.glb" if i % 2 == 0 else "res://models/props/Bush_2_B_Color1.glb"
		_prop(bush, bp, rng.randf_range(1.4, 2.4), rng.randf() * TAU, false, Vector3.ZERO)

	# crates / barrels near the market
	_prop("res://models/props/crate.glb", Vector3(8, 0, 6), 1.4, 0.3, false, Vector3.ZERO)
	_prop("res://models/props/crate.glb", Vector3(9, 0, 7), 1.4, 1.1, false, Vector3.ZERO)
	_prop("res://models/props/Fuel_A_Barrel.glb", Vector3(7.5, 0, 7.5), 1.4, 0, false, Vector3.ZERO)

	# NPC specs (placed in town)
	npc_specs = [
		{
			"pos": smith_pos + Vector3(2.2, 0, 0.5),
			"yaw": deg_to_rad(200),
			"model": "res://models/kk_Knight.glb",
			"name": "Doran the Blacksmith",
			"tint": Color(0.7, 0.6, 0.55),
			"persona": "You are Doran, a gruff but warm-hearted dwarven-built blacksmith in the town of Emberhold, the last safe hold above a haunted dungeon full of skeletons. You forge weapons and armor for raiders who descend. You speak plainly, with pride in your craft, and you tease adventurers who come back with dented gear. You know the dungeon is dangerous and you respect anyone brave enough to fight the bonewalkers below. Keep replies to 1-3 short sentences, in character.",
		},
		{
			"pos": Vector3(-6, 0, -4),
			"yaw": deg_to_rad(40),
			"model": "res://models/kk_Mage.glb",
			"name": "Pip the Quest-Giver",
			"tint": Color(0.85, 0.85, 0.95),
			"persona": "You are Pip, a nervous, jittery quest-giver in the town of Emberhold who sends raiders down into the skeleton-haunted dungeon below. You are anxious, you stammer a little, you worry about the adventurers' safety and about the rising dead, but you desperately need someone to clear the dungeon. You offer rumors and quests about loot and skeleton lords below. Keep replies to 1-3 short, anxious sentences, in character.",
		},
	]

	_portal(TOWN_PORTAL, "Descend to the Dungeon", Color(0.6, 0.3, 0.9))


# ----------------------------- DUNGEON -----------------------------
func _build_dungeon() -> void:
	var c := DUNGEON_CTR
	_ground(c, Vector2(72, 72), "res://textures/stone_floor.png", 18, Color(0.5, 0.5, 0.55))
	# perimeter walls
	var half := 36.0
	var wh := 9.0
	_wall(c + Vector3(0, wh * 0.5, -half), Vector3(72, wh, 1.5))
	_wall(c + Vector3(0, wh * 0.5, half), Vector3(72, wh, 1.5))
	_wall(c + Vector3(-half, wh * 0.5, 0), Vector3(1.5, wh, 72))
	_wall(c + Vector3(half, wh * 0.5, 0), Vector3(1.5, wh, 72))
	# a couple of interior pillars / low walls for cover
	for off in [Vector3(-12, 0, -8), Vector3(14, 0, 6), Vector3(-6, 0, 16), Vector3(10, 0, -18)]:
		_wall(c + off + Vector3(0, 2.5, 0), Vector3(3, 5, 3))

	# torches along the walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(8):
		var a := deg_to_rad(i * 45.0)
		var p := c + Vector3(cos(a) * 30.0, 0, sin(a) * 30.0)
		_prop("res://models/props/lantern.glb", p, 1.5, 0, false, Vector3.ZERO)
		_torch(p + Vector3(0, 1.4, 0), Color(1.0, 0.45, 0.18), 3.0)

	# banners on the far wall
	_prop("res://models/props/banner_patternA_red.glb", c + Vector3(-8, 3.2, -34.5), 3.0, 0, false, Vector3.ZERO)
	_prop("res://models/props/banner_blue.glb", c + Vector3(8, 3.2, -34.5), 3.0, 0, false, Vector3.ZERO)

	# crates / barrels
	for i in range(8):
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, 28.0)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var which := "res://models/props/crate.glb" if i % 2 == 0 else "res://models/props/Fuel_A_Barrel.glb"
		_prop(which, p, 1.5, rng.randf() * TAU, false, Vector3.ZERO)

	# loot piles
	loot_points = [
		c + Vector3(-20, 0, -20), c + Vector3(22, 0, -14),
		c + Vector3(0, 0, 24), c + Vector3(18, 0, 20),
	]

	# skeleton spawn points
	skeleton_points = [
		c + Vector3(-14, 0, -6), c + Vector3(12, 0, -2), c + Vector3(-4, 0, 12),
		c + Vector3(8, 0, 14), c + Vector3(-18, 0, 4), c + Vector3(16, 0, -16),
	]

	_portal(DUNGEON_PORTAL, "Return to Town", Color(0.3, 0.8, 0.6))


# ----------------------------- helpers -----------------------------
func _ground(center: Vector3, size: Vector2, tex: String, tiles: int, tint: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	add_child(body)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	mi.material_override = _tex_mat(tex, tiles, tint)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 0.4, size.y)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	body.add_child(col)


func _wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	add_child(body)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _tex_mat("res://textures/brick_wall.png", maxi(1, int(maxf(size.x, size.z) / 4.0)), Color(0.42, 0.4, 0.46))
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)


func _prop(path: String, pos: Vector3, sc: float, yaw: float, collide: bool, col_size: Vector3) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var n: Node3D = packed.instantiate()
	n.position = pos
	n.scale = Vector3(sc, sc, sc)
	n.rotation.y = yaw
	add_child(n)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos + Vector3(0, col_size.y * 0.5, 0)
		add_child(body)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col_size
		col.shape = box
		body.add_child(col)
	return n


func _torch(pos: Vector3, color: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 14.0
	l.shadow_enabled = false
	add_child(l)
	_torch_lights.append(l)
	# tiny emissive flame core
	var flame := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	flame.mesh = sp
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = color
	fm.emission_enabled = true
	fm.emission = color
	fm.emission_energy_multiplier = 4.0
	flame.mesh.material = fm
	flame.position = pos
	add_child(flame)


func _portal(pos: Vector3, label: String, color: Color) -> void:
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.2
	cyl.height = 0.25
	pad.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = color
	pm.emission_enabled = true
	pm.emission = color
	pm.emission_energy_multiplier = 2.0
	pad.mesh.material = pm
	pad.position = pos + Vector3(0, 0.14, 0)
	add_child(pad)

	var beam := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 1.9
	bcyl.bottom_radius = 1.9
	bcyl.height = 6.0
	beam.mesh = bcyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(color.r, color.g, color.b, 0.22)
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.mesh.material = bm
	beam.position = pos + Vector3(0, 3.0, 0)
	add_child(beam)

	var pl := OmniLight3D.new()
	pl.position = pos + Vector3(0, 1.5, 0)
	pl.light_color = color
	pl.light_energy = 3.0
	pl.omni_range = 10.0
	pl.shadow_enabled = false
	add_child(pl)

	var lab := Label3D.new()
	lab.text = label
	lab.position = pos + Vector3(0, 3.4, 0)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.fixed_size = false
	lab.pixel_size = 0.016
	lab.font_size = 40
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 14
	add_child(lab)


func _tex_mat(tex: String, tiles: int, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var t: Texture2D = load(tex)
	m.albedo_texture = t
	m.albedo_color = tint
	m.uv1_scale = Vector3(tiles, tiles, 1)
	m.roughness = 0.95
	return m
