extends Node
## Serverless multiplayer client (Supabase Realtime broadcast via web/bridge.js).
## Autoload named "Net". Web-only; on desktop/editor it no-ops cleanly so the
## single-player game still runs.

signal connected(room: String, you: String)
signal disconnected()
signal message(data: Dictionary)

var local_id: String = ""
var local_name: String = "Hero"
var room: String = ""
var online: bool = false

var _bridge: Variant = null
var _cb: Variant = null


func _ready() -> void:
	if not OS.has_feature("web"):
		local_id = "local_" + str(randi())
		return
	await get_tree().process_frame
	_bridge = JavaScriptBridge.get_interface("gameNet")
	if _bridge == null:
		push_warning("[Net] gameNet bridge missing — is bridge.js in the export head_include?")
		local_id = "local_" + str(randi())
		return
	_cb = JavaScriptBridge.create_callback(_on_js)
	_bridge.setOnMessage(_cb)
	local_id = str(_bridge.getUserId())
	local_name = str(_bridge.getName())


func connect_room(code: String = "") -> void:
	if _bridge != null:
		_bridge.connectRoom(code)


func send(data: Dictionary) -> void:
	if _bridge != null and online:
		_bridge.send(JSON.stringify(data))


func get_room_url() -> String:
	if _bridge != null:
		return str(_bridge.getRoomUrl())
	return ""


func get_room_code() -> String:
	if _bridge != null:
		return str(_bridge.getRoom())
	return room


func _on_js(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	match str(d.get("t", "")):
		"_connected":
			room = str(d.get("room", ""))
			local_id = str(d.get("you", local_id))
			online = true
			connected.emit(room, local_id)
		"_disconnected":
			online = false
			disconnected.emit()
		"_error":
			online = false
		_:
			message.emit(d)
