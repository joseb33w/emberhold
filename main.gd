extends Node3D
## Emberhold orchestrator: world + environment, local player, HUD (joystick / look /
## attack / dodge / emote / mute / room-share / NPC chat), tap-to-start + hero select,
## combat juice (spark + flash + screen-shake), and Supabase-Realtime multiplayer with
## host-elected dungeon skeletons. Mobile-web (nothreads, Compatibility/WebGL2).

const MELEE_RANGE := 2.9
const MELEE_DMG := 22.0
const SPELL_RANGE := 8.5
const SPELL_DMG := 18.0
const ENEMY_DMG := 10.0
const NPC_URL := "https://npc.myapping.com/chat"

var world: World
var we: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var player: Player
var menu_cam: Camera3D

var started := false
var area := "town"
var _env_blend := 0.0
var _portal_cd := 0.0

# input state
var _move_index := -1
var _move_origin := Vector2.ZERO
var _move_vec := Vector2.ZERO
var _look_index := -1
var _hero_choice := "knight"

# multiplayer
var _remotes := {}
var _peer_seen := {}
var _known_ids := {}
var _am_host := false
var _connect_msec := 0
var _host_skeletons: Array = []
var _replicas := {}
var _replica_seen := {}
var _state_t := 0.0
var _enemy_t := 0.0
var _host_t := 0.0

# HUD
var _hud: CanvasLayer
var _joy_base: TextureRect
var _joy_knob: TextureRect
var _hp_fill: ColorRect
var _hp_label: Label
var _room_label: Label
var _toast: Label
var _talk_btn: Button
var _mute_btn: Button
var _menu_layer: CanvasLayer
var _hero_btns := {}

# chat
var _chat_panel: Panel
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_think: Label
var _chat_title: Label
var _chat_send: Button
var _chips: Array = []
var _http: HTTPRequest
var _active_npc: NPC
var _chat_open := false
var _chat_busy := false
var _think_t := 0.0
var _think_n := 0

var _npcs: Array = []


func _ready() -> void:
	randomize()
	_build_environment()
	world = World.new()
	add_child(world)
	world.build()
	_spawn_npcs()

	menu_cam = Camera3D.new()
	menu_cam.position = Vector3(0, 7, 26)
	menu_cam.rotation_degrees = Vector3(-14, 0, 0)
	menu_cam.fov = 64
	add_child(menu_cam)
	menu_cam.current = true

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

	if has_node("/root/Net"):
		Net.message.connect(_on_net_message)
		Net.connected.connect(_on_net_connected)

	_build_hud()
	_show_start_menu()


# ----------------------------- ENVIRONMENT -----------------------------
func _build_environment() -> void:
	we = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.45, 0.72)
	sm.sky_horizon_color = Color(0.7, 0.65, 0.6)
	sm.ground_bottom_color = Color(0.2, 0.18, 0.16)
	sm.ground_horizon_color = Color(0.5, 0.45, 0.4)
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.85)
	env.fog_density = 0.008
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -52, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

	get_viewport().msaa_3d = Viewport.MSAA_2X


func _apply_env(u: float) -> void:
	env.fog_density = lerpf(0.008, 0.06, u)
	env.fog_light_color = Color(0.7, 0.75, 0.85).lerp(Color(0.06, 0.05, 0.08), u)
	env.ambient_light_energy = lerpf(0.95, 0.32, u)
	env.ambient_light_color = Color(0.8, 0.82, 0.9).lerp(Color(0.25, 0.22, 0.32), u)
	env.tonemap_exposure = lerpf(1.0, 0.92, u)
	sun.light_energy = lerpf(1.15, 0.28, u)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.5, 0.55, 0.8), u)


# ----------------------------- PLAYER -----------------------------
func _spawn_player() -> void:
	var heroes := {
		"knight": ["res://models/kk_Knight.glb", false],
		"mage": ["res://models/kk_Mage.glb", true],
		"rogue": ["res://models/kk_Rogue.glb", false],
	}
	var hero: Array = heroes[_hero_choice]
	player = Player.new()
	player.configure(str(hero[0]), Net.local_name if has_node("/root/Net") else "Hero", bool(hero[1]))
	player.spawn_point = World.TOWN_SPAWN
	add_child(player)
	player.global_position = World.TOWN_SPAWN
	player.set_active_camera()
	player.melee_swing.connect(_on_player_swing)
	player.health_changed.connect(_on_player_health)
	player.died.connect(_on_player_died)
	_on_player_health(player.hp, Player.MAX_HP)


# ----------------------------- START / MENU -----------------------------
func _show_start_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 50
	add_child(_menu_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.05, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed():
			_start_game())
	_menu_layer.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(box)

	var title := Label.new()
	title.text = "EMBERHOLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "A co-op + PvP dungeon raid"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	box.add_child(sub)

	var pick := Label.new()
	pick.text = "Choose your hero"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_size_override("font_size", 20)
	pick.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(pick)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for h in [["knight", "KNIGHT"], ["mage", "MAGE"], ["rogue", "ROGUE"]]:
		var b := _styled_button(str(h[1]), Vector2(150, 64), Color(0.2, 0.18, 0.26))
		var key := str(h[0])
		b.pressed.connect(func() -> void: _select_hero(key))
		row.add_child(b)
		_hero_btns[key] = b
	_select_hero("knight")

	var enter := _styled_button("ENTER EMBERHOLD", Vector2(320, 76), Color(0.6, 0.3, 0.12))
	enter.add_theme_font_size_override("font_size", 26)
	enter.pressed.connect(_start_game)
	box.add_child(enter)

	var hint := Label.new()
	hint.text = "Tap anywhere to begin  -  move: left joystick / WASD  -  attack: J  -  dodge: K"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(hint)


func _select_hero(key: String) -> void:
	_hero_choice = key
	for k in _hero_btns.keys():
		var b: Button = _hero_btns[k]
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		if sb != null:
			sb.bg_color = Color(0.7, 0.45, 0.15) if k == key else Color(0.2, 0.18, 0.26)


func _start_game() -> void:
	if started:
		return
	started = true
	_spawn_player()
	if _menu_layer != null:
		_menu_layer.queue_free()
		_menu_layer = null
	if menu_cam != null:
		menu_cam.current = false
	Audio.play_music("town")
	# connect-path marker (verifier checks this fired before going online)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__gogi_connect_called=true;", true)
	_connect_msec = Time.get_ticks_msec()
	if has_node("/root/Net"):
		_known_ids[Net.local_id] = true
		Net.connect_room()
	_update_room_label()


# ----------------------------- HUD -----------------------------
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var vp := get_viewport().get_visible_rect().size

	# joystick (dynamic, left half)
	_joy_base = TextureRect.new()
	_joy_base.texture = _circle_tex(150, Color(1, 1, 1, 0.16))
	_joy_base.size = Vector2(150, 150)
	_joy_base.visible = false
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_joy_base)
	_joy_knob = TextureRect.new()
	_joy_knob.texture = _circle_tex(70, Color(1, 1, 1, 0.34))
	_joy_knob.size = Vector2(70, 70)
	_joy_knob.visible = false
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_joy_knob)

	# action buttons (right)
	var atk := _styled_button("ATTACK", Vector2(132, 132), Color(0.7, 0.22, 0.18))
	atk.position = vp - Vector2(160, 170)
	atk.add_theme_font_size_override("font_size", 22)
	atk.pressed.connect(func() -> void: _do_attack())
	_hud.add_child(atk)

	var dodge := _styled_button("DODGE", Vector2(104, 104), Color(0.2, 0.42, 0.7))
	dodge.position = vp - Vector2(290, 150)
	dodge.pressed.connect(func() -> void:
		if player != null: player.do_dodge())
	_hud.add_child(dodge)

	var wave := _styled_button("WAVE", Vector2(96, 70), Color(0.35, 0.3, 0.5))
	wave.position = vp - Vector2(160, 250)
	wave.pressed.connect(func() -> void: _do_emote("wave"))
	_hud.add_child(wave)

	var cheer := _styled_button("CHEER", Vector2(96, 70), Color(0.35, 0.3, 0.5))
	cheer.position = vp - Vector2(290, 270)
	cheer.pressed.connect(func() -> void: _do_emote("cheer"))
	_hud.add_child(cheer)

	# health bar (top-left)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.05, 0.04, 0.06, 0.85)
	hp_bg.position = Vector2(20, 20)
	hp_bg.size = Vector2(300, 34)
	_hud.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.35, 0.85, 0.35)
	_hp_fill.position = Vector2(24, 24)
	_hp_fill.size = Vector2(292, 26)
	_hud.add_child(_hp_fill)
	_hp_label = Label.new()
	_hp_label.text = "Hero"
	_hp_label.position = Vector2(30, 24)
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hud.add_child(_hp_label)

	# room code + share (top center)
	_room_label = Label.new()
	_room_label.text = "Connecting..."
	_room_label.position = Vector2(vp.x * 0.5 - 120, 22)
	_room_label.size = Vector2(240, 28)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 18)
	_room_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_hud.add_child(_room_label)
	var share := _styled_button("SHARE LINK", Vector2(150, 36), Color(0.2, 0.4, 0.3))
	share.position = Vector2(vp.x * 0.5 - 75, 54)
	share.add_theme_font_size_override("font_size", 16)
	share.pressed.connect(_share_link)
	_hud.add_child(share)

	# mute (top right)
	_mute_btn = _styled_button("SOUND ON", Vector2(120, 40), Color(0.25, 0.25, 0.32))
	_mute_btn.position = Vector2(vp.x - 140, 20)
	_mute_btn.add_theme_font_size_override("font_size", 15)
	_mute_btn.pressed.connect(_toggle_mute)
	_hud.add_child(_mute_btn)

	# talk button (hidden until near an NPC)
	_talk_btn = _styled_button("TALK", Vector2(200, 56), Color(0.3, 0.5, 0.7))
	_talk_btn.position = Vector2(vp.x * 0.5 - 100, vp.y - 150)
	_talk_btn.visible = false
	_talk_btn.pressed.connect(_talk_to_nearest)
	_hud.add_child(_talk_btn)

	# toast
	_toast = Label.new()
	_toast.position = Vector2(vp.x * 0.5 - 160, 96)
	_toast.size = Vector2(320, 28)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)

	_build_chat(vp)
	_hud.visible = false


func _build_chat(vp: Vector2) -> void:
	_chat_panel = Panel.new()
	_chat_panel.size = Vector2(min(vp.x - 40, 620), 300)
	_chat_panel.position = Vector2((vp.x - _chat_panel.size.x) * 0.5, vp.y - 320)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.09, 0.95)
	psb.set_corner_radius_all(14)
	psb.set_border_width_all(2)
	psb.border_color = Color(1.0, 0.7, 0.3, 0.7)
	_chat_panel.add_theme_stylebox_override("panel", psb)
	_chat_panel.visible = false
	_hud.add_child(_chat_panel)

	_chat_title = Label.new()
	_chat_title.text = "NPC"
	_chat_title.position = Vector2(16, 10)
	_chat_title.add_theme_font_size_override("font_size", 20)
	_chat_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	_chat_panel.add_child(_chat_title)

	var close := _styled_button("CLOSE", Vector2(90, 32), Color(0.4, 0.2, 0.2))
	close.position = Vector2(_chat_panel.size.x - 104, 8)
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(_close_chat)
	_chat_panel.add_child(close)

	_chat_log = RichTextLabel.new()
	_chat_log.position = Vector2(16, 46)
	_chat_log.size = Vector2(_chat_panel.size.x - 32, 150)
	_chat_log.scroll_following = true
	_chat_log.bbcode_enabled = true
	_chat_log.add_theme_font_size_override("normal_font_size", 16)
	_chat_panel.add_child(_chat_log)

	_chat_think = Label.new()
	_chat_think.position = Vector2(16, 200)
	_chat_think.add_theme_font_size_override("font_size", 16)
	_chat_think.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_chat_think.visible = false
	_chat_panel.add_child(_chat_think)

	var chiprow := HBoxContainer.new()
	chiprow.position = Vector2(16, 222)
	chiprow.add_theme_constant_override("separation", 8)
	_chat_panel.add_child(chiprow)
	for q in ["Hello", "What's down there?", "Any advice?", "Got work for me?"]:
		var c := _styled_button(str(q), Vector2(0, 34), Color(0.22, 0.3, 0.4))
		c.add_theme_font_size_override("font_size", 14)
		var msg := str(q)
		c.pressed.connect(func() -> void: _send_chat(msg))
		chiprow.add_child(c)
		_chips.append(c)

	_chat_input = LineEdit.new()
	_chat_input.position = Vector2(16, 262)
	_chat_input.size = Vector2(_chat_panel.size.x - 130, 32)
	_chat_input.placeholder_text = "Type a message..."
	_chat_input.text_submitted.connect(func(t: String) -> void: _send_chat(t))
	_chat_panel.add_child(_chat_input)
	_chat_send = _styled_button("SEND", Vector2(90, 32), Color(0.25, 0.45, 0.3))
	_chat_send.position = Vector2(_chat_panel.size.x - 106, 262)
	_chat_send.add_theme_font_size_override("font_size", 14)
	_chat_send.pressed.connect(func() -> void: _send_chat(_chat_input.text))
	_chat_panel.add_child(_chat_send)


# ----------------------------- NPCs -----------------------------
func _spawn_npcs() -> void:
	for spec in world.npc_specs:
		var n := NPC.new()
		add_child(n)
		n.global_position = spec["pos"]
		n.configure(str(spec["model"]), str(spec["name"]), str(spec["persona"]), spec["tint"])
		n.rotation.y = float(spec.get("yaw", 0.0))
		_npcs.append(n)


func _talk_to_nearest() -> void:
	var n := _nearest_npc()
	if n != null:
		_open_chat(n)


func _nearest_npc() -> NPC:
	if player == null:
		return null
	for n in _npcs:
		var npc := n as NPC
		if npc.near(player.global_position):
			return npc
	return null


func _open_chat(npc: NPC) -> void:
	_active_npc = npc
	_chat_open = true
	_chat_panel.visible = true
	_chat_title.text = npc.npc_name
	_chat_log.clear()
	for m in npc.history:
		var who := "You" if str(m["role"]) == "user" else npc.npc_name
		_chat_log.append_text("[b]%s:[/b] %s\n" % [who, str(m["content"])])
	if npc.history.is_empty():
		_chat_log.append_text("[i]Walk up and say hello.[/i]\n")
	npc.emote()
	Audio.play_sfx("ui")


func _close_chat() -> void:
	_chat_open = false
	_chat_panel.visible = false
	_active_npc = null
	Audio.play_sfx("ui")


func _send_chat(text: String) -> void:
	text = text.strip_edges()
	if text == "" or _chat_busy or _active_npc == null:
		return
	_chat_busy = true
	_set_chat_enabled(false)
	_chat_input.text = ""
	_active_npc.push("user", text)
	_chat_log.append_text("[b]You:[/b] %s\n" % text)
	_chat_think.visible = true
	_think_t = 0.0
	_think_n = 0
	var msgs: Array = []
	for m in _active_npc.history:
		msgs.append({"role": str(m["role"]), "content": str(m["content"])})
	var payload := {"persona": _active_npc.persona, "messages": msgs}
	var headers := PackedStringArray(["content-type: application/json"])
	var err := _http.request(NPC_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_chat_reply_failed()


func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_chat_think.visible = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_chat_reply_failed()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_chat_reply_failed()
		return
	var data: Dictionary = parsed
	var reply: String = str(data.get("reply", "")).strip_edges()
	if reply == "":
		_chat_reply_failed()
		return
	if _active_npc != null:
		_active_npc.push("assistant", reply)
		_chat_log.append_text("[b]%s:[/b] %s\n" % [_active_npc.npc_name, reply])
		_active_npc.emote()
	Audio.play_sfx("npc")
	_chat_busy = false
	_set_chat_enabled(true)


func _chat_reply_failed() -> void:
	if _active_npc != null:
		_chat_log.append_text("[i]%s seems lost in thought...[/i]\n" % _active_npc.npc_name)
	_chat_busy = false
	_chat_think.visible = false
	_set_chat_enabled(true)


func _set_chat_enabled(on: bool) -> void:
	_chat_send.disabled = not on
	_chat_input.editable = on
	for c in _chips:
		(c as Button).disabled = not on


# ----------------------------- COMBAT -----------------------------
func _do_attack() -> void:
	if player != null and not _chat_open:
		player.do_attack()
		_net_act("attack")


func _do_emote(which: String) -> void:
	if player != null and not _chat_open:
		player.do_emote(which)
		_net_act(which)


func _on_player_swing(origin: Vector3, fwd: Vector3, is_spell: bool) -> void:
	var rng := SPELL_RANGE if is_spell else MELEE_RANGE
	var dmg := SPELL_DMG if is_spell else MELEE_DMG
	var hit_any := false

	# skeletons (host + replicas)
	var skels: Array = []
	skels.append_array(_host_skeletons)
	for k in _replicas.keys():
		skels.append(_replicas[k])
	for s in skels:
		var sk := s as Skeleton
		if sk == null or sk.dead:
			continue
		var to: Vector3 = sk.global_position + Vector3(0, 1.0, 0) - origin
		if to.length() <= rng and fwd.dot(to.normalized()) > 0.25:
			hit_any = true
			_spark(sk.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.85, 0.3))
			sk.rig.flash(Color(1, 0.4, 0.3))
			if _am_host:
				sk.apply_damage(dmg)
			else:
				sk.local_hit_flash()
				Net.send({"t": "ehit", "id": sk.eid, "dmg": dmg})

	# PvP: remote players
	for id in _remotes.keys():
		var rp := _remotes[id] as RemotePlayer
		if rp == null or not rp.is_targetable():
			continue
		var to2: Vector3 = rp.global_position + Vector3(0, 1.0, 0) - origin
		if to2.length() <= rng and fwd.dot(to2.normalized()) > 0.25:
			hit_any = true
			_spark(rp.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.4, 0.4))
			rp.rig.flash(Color(1, 0.5, 0.4))
			Net.send({"t": "phit", "target": str(id), "dmg": dmg})

	if hit_any:
		Audio.play_sfx("hit")
		if player != null:
			player.add_shake(0.18)


func _on_skeleton_swing(origin: Vector3) -> void:
	if player == null or player.dead or player.invulnerable():
		return
	var to: Vector3 = player.global_position + Vector3(0, 1.0, 0) - origin
	if to.length() <= 2.6:
		player.apply_damage(ENEMY_DMG)
		player.add_shake(0.28)
		_flash_screen(Color(0.8, 0.1, 0.1, 0.35))


# ----------------------------- JUICE -----------------------------
func _spark(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 90.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.26
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	p.mesh = SphereMesh.new()
	p.material_override = mat
	add_child(p)
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _flash_screen(c: Color) -> void:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)


# ----------------------------- PROCESS -----------------------------
func _process(delta: float) -> void:
	# torch flicker handled inside World; env blend toward area
	var target := 1.0 if area == "dungeon" else 0.0
	_env_blend = move_toward(_env_blend, target, delta * 1.2)
	_apply_env(_env_blend)

	if not started:
		return
	_hud.visible = true

	# feed movement
	if player != null:
		if _chat_open:
			player.move_input = Vector2.ZERO
		else:
			player.move_input = _keyboard_vector() + _move_vec

	_update_portals()
	_update_npc_prompt()
	_animate_thinking(delta)
	_update_toast(delta)

	# host election + AI run even when offline so solo PvE works; only broadcast
	# state/enemies when actually connected to a room.
	_host_t -= delta
	if _host_t <= 0.0:
		_host_t = 0.5
		_update_host()
	if _am_host:
		_enemy_t -= delta
		if _enemy_t <= 0.0:
			_enemy_t = 0.12
			if Net.online:
				_broadcast_enemies()
	if has_node("/root/Net") and Net.online:
		_state_t -= delta
		if _state_t <= 0.0:
			_state_t = 0.1
			_broadcast_state()
		_cull_peers()


func _update_portals() -> void:
	if player == null or player.dead:
		return
	if _portal_cd > 0.0:
		_portal_cd -= get_process_delta_time()
		return
	var p := player.global_position
	if area == "town" and p.distance_to(World.TOWN_PORTAL) < 2.6:
		_enter_area("dungeon", World.DUNGEON_SPAWN)
	elif area == "dungeon" and p.distance_to(World.DUNGEON_PORTAL) < 2.6:
		_enter_area("town", World.TOWN_SPAWN)


func _enter_area(a: String, where: Vector3) -> void:
	area = a
	player.global_position = where
	player.spawn_point = where
	_portal_cd = 1.5
	Audio.play_music("dungeon" if a == "dungeon" else "town")
	Audio.play_sfx("ui")
	_flash_screen(Color(0, 0, 0, 0.6))


func _update_npc_prompt() -> void:
	if _chat_open:
		_talk_btn.visible = false
		return
	var n := _nearest_npc()
	if n != null and area == "town":
		_talk_btn.visible = true
		_talk_btn.text = "TALK: " + n.npc_name
	else:
		_talk_btn.visible = false


func _animate_thinking(delta: float) -> void:
	if not _chat_think.visible:
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.4
		_think_n = (_think_n + 1) % 4
		_chat_think.text = _active_npc.npc_name + " is thinking" + ".".repeat(_think_n) if _active_npc != null else "..."


func _update_toast(delta: float) -> void:
	if _toast.modulate.a > 0.0:
		_toast.modulate.a = maxf(0.0, _toast.modulate.a - delta * 0.5)


func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.modulate.a = 1.6


# ----------------------------- MULTIPLAYER -----------------------------
func _on_net_connected(room: String, _you: String) -> void:
	_known_ids[Net.local_id] = true
	_update_room_label()
	_show_toast("Online - room " + room)


func _broadcast_state() -> void:
	if player == null:
		return
	var s := player.net_state()
	s["t"] = "state"
	s["area"] = area
	Net.send(s)


func _broadcast_enemies() -> void:
	var list: Array = []
	for s in _host_skeletons:
		list.append((s as Skeleton).net_state())
	Net.send({"t": "enemies", "list": list})


func _net_act(a: String) -> void:
	if has_node("/root/Net") and Net.online:
		Net.send({"t": "act", "a": a})


func _on_net_message(d: Dictionary) -> void:
	var from := str(d.get("from", ""))
	if from != "" and from != Net.local_id:
		_known_ids[from] = true
		_peer_seen[from] = Time.get_ticks_msec()
	match str(d.get("t", "")):
		"state":
			_apply_peer_state(from, d)
		"act":
			if _remotes.has(from):
				(_remotes[from] as RemotePlayer).play_act(str(d.get("a", "")))
		"phit":
			if str(d.get("target", "")) == Net.local_id and player != null:
				player.apply_damage(float(d.get("dmg", 0.0)))
				player.add_shake(0.28)
				_flash_screen(Color(0.8, 0.1, 0.1, 0.35))
		"ehit":
			if _am_host:
				var sk := _find_host_skel(str(d.get("id", "")))
				if sk != null:
					sk.apply_damage(float(d.get("dmg", 0.0)))
		"enemies":
			if not _am_host:
				_apply_enemy_list(d.get("list", []))


func _apply_peer_state(from: String, d: Dictionary) -> void:
	if from == "" or from == Net.local_id:
		return
	var rp: RemotePlayer
	if _remotes.has(from):
		rp = _remotes[from]
	else:
		rp = RemotePlayer.new()
		rp.configure(str(d.get("hero", "res://models/kk_Rogue.glb")), str(d.get("name", "Hero")))
		add_child(rp)
		_remotes[from] = rp
	var pos := Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
	rp.apply_state(pos, float(d.get("ry", 0)), float(d.get("hp", 100.0)), bool(d.get("dead", false)))


func _apply_enemy_list(list: Variant) -> void:
	if not (list is Array):
		return
	var now := Time.get_ticks_msec()
	for item in (list as Array):
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		var id := str(e.get("id", ""))
		if id == "":
			continue
		var sk: Skeleton
		if _replicas.has(id):
			sk = _replicas[id]
		else:
			sk = _make_skeleton(id, true)
			_replicas[id] = sk
		_replica_seen[id] = now
		var pos := Vector3(float(e.get("x", 0)), 0.0, float(e.get("z", 0)))
		sk.apply_net(pos, float(e.get("ry", 0)), float(e.get("hp", 60.0)), int(e.get("d", 0)) == 1, int(e.get("sw", 0)) == 1)


func _update_host() -> void:
	var min_id := Net.local_id
	for id in _known_ids.keys():
		if str(id) < min_id:
			min_id = str(id)
	var should_host := (min_id == Net.local_id) and (Time.get_ticks_msec() - _connect_msec > 1200)
	if should_host and not _am_host:
		_become_host()
	elif not should_host and _am_host:
		_relinquish_host()


func _become_host() -> void:
	_am_host = true
	# clear any replicas; we now own the enemies
	for k in _replicas.keys():
		(_replicas[k] as Skeleton).queue_free()
	_replicas.clear()
	_replica_seen.clear()
	# idempotent: drop any host skeletons we already own before respawning
	for s in _host_skeletons:
		(s as Skeleton).queue_free()
	_host_skeletons.clear()
	_spawn_host_skeletons()


func _relinquish_host() -> void:
	_am_host = false
	for s in _host_skeletons:
		(s as Skeleton).queue_free()
	_host_skeletons.clear()


func _spawn_host_skeletons() -> void:
	var pts := world.skeleton_points
	for i in range(pts.size()):
		var sk := _make_skeleton(Net.local_id + "_e" + str(i), false)
		sk.spawn_point = pts[i]
		sk.global_position = pts[i]
		_host_skeletons.append(sk)


func _make_skeleton(id: String, replica: bool) -> Skeleton:
	var models := [
		["res://models/kk_Skeleton_Minion.glb", Color(0.95, 0.95, 0.9)],
		["res://models/kk_Skeleton_Warrior.glb", Color(0.8, 0.85, 0.95)],
		["res://models/kk_Skeleton_Rogue.glb", Color(0.85, 0.9, 0.8)],
	]
	var h := absi(hash(id))
	var pick: Array = models[h % models.size()]
	var sk := Skeleton.new()
	sk.eid = id
	sk.replica = replica
	add_child(sk)
	var sc := 0.92 + float(h % 100) / 100.0 * 0.22
	sk.setup(str(pick[0]), pick[1], sc)
	sk.did_swing.connect(_on_skeleton_swing)
	return sk


func _find_host_skel(id: String) -> Skeleton:
	for s in _host_skeletons:
		if (s as Skeleton).eid == id:
			return s
	return null


func _cull_peers() -> void:
	var now := Time.get_ticks_msec()
	for id in _remotes.keys().duplicate():
		if now - int(_peer_seen.get(id, 0)) > 4000:
			(_remotes[id] as RemotePlayer).queue_free()
			_remotes.erase(id)
			_known_ids.erase(id)
	if not _am_host:
		for id in _replicas.keys().duplicate():
			if now - int(_replica_seen.get(id, 0)) > 2500:
				(_replicas[id] as Skeleton).queue_free()
				_replicas.erase(id)
				_replica_seen.erase(id)


# ----------------------------- player HUD callbacks -----------------------------
func _on_player_health(hp: float, maxhp: float) -> void:
	if _hp_fill != null:
		_hp_fill.size.x = 292.0 * (hp / maxhp)
		_hp_fill.color = Color(0.85, 0.25, 0.2) if hp / maxhp < 0.34 else (Color(0.9, 0.75, 0.25) if hp / maxhp < 0.6 else Color(0.35, 0.85, 0.35))
	if _hp_label != null and player != null:
		_hp_label.text = "%s  %d" % [player.hero_name, int(hp)]


func _on_player_died() -> void:
	_show_toast("You fell - respawning...")
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if player != null:
			player.spawn_point = World.DUNGEON_SPAWN if area == "dungeon" else World.TOWN_SPAWN
			player.respawn())


func _update_room_label() -> void:
	if _room_label == null:
		return
	if has_node("/root/Net"):
		var code := Net.get_room_code()
		_room_label.text = ("Room  " + code) if code != "" else "Solo"
	else:
		_room_label.text = "Solo"


func _share_link() -> void:
	var url := ""
	if has_node("/root/Net"):
		url = Net.get_room_url()
	if url != "":
		DisplayServer.clipboard_set(url)
		_show_toast("Room link copied to clipboard")
	Audio.play_sfx("ui")


func _toggle_mute() -> void:
	var m := not Audio.muted
	Audio.set_muted(m)
	_mute_btn.text = "SOUND OFF" if m else "SOUND ON"


# ----------------------------- INPUT -----------------------------
func _input(event: InputEvent) -> void:
	if not started:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_start_game()
		return
	if _chat_open:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J, KEY_SPACE:
				_do_attack()
			KEY_K, KEY_SHIFT:
				if player != null: player.do_dodge()
			KEY_E:
				_do_emote("wave")
			KEY_Q:
				_do_emote("cheer")
		return

	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < half and _move_index == -1:
				_move_index = event.index
				_move_origin = event.position
				_move_vec = Vector2.ZERO
				_joy_base.visible = true
				_joy_knob.visible = true
				_joy_base.position = event.position - _joy_base.size * 0.5
				_joy_knob.position = event.position - _joy_knob.size * 0.5
			elif event.position.x >= half and _look_index == -1:
				_look_index = event.index
		else:
			if event.index == _move_index:
				_move_index = -1
				_move_vec = Vector2.ZERO
				_joy_base.visible = false
				_joy_knob.visible = false
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		if event.index == _move_index:
			_move_vec = ((event.position - _move_origin) / 80.0).limit_length(1.0)
			_joy_knob.position = _move_origin + _move_vec * 50.0 - _joy_knob.size * 0.5
		elif event.index == _look_index and player != null:
			player.add_look(event.relative.x, event.relative.y)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) and player != null:
		player.add_look(event.relative.x, event.relative.y)


func _keyboard_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v


# ----------------------------- UI helpers -----------------------------
func _styled_button(text: String, size: Vector2, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	if size.x > 0:
		b.custom_minimum_size = size
		b.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = col.lightened(0.15)
	b.add_theme_stylebox_override("hover", hb)
	var pb := sb.duplicate() as StyleBoxFlat
	pb.bg_color = col.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pb)
	var db := sb.duplicate() as StyleBoxFlat
	db.bg_color = col.darkened(0.4)
	b.add_theme_stylebox_override("disabled", db)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	return b


func _circle_tex(d: int, col: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5
	var r := d * 0.5
	for y in range(d):
		for x in range(d):
			var dist := Vector2(x, y).distance_to(c)
			if dist <= r:
				var a: float = col.a * clampf(1.0 - (dist / r) * 0.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
