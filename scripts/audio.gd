extends Node
## Audio autoload: town music / dungeon ambience + pooled SFX + mute toggle.
## All playback is kicked off from the tap-to-start gesture so iOS Safari unlocks
## the Web Audio context.

const SFX := {
	"footstep": "res://audio/sfx_footstep.ogg",
	"swing": "res://audio/sfx_swing.ogg",
	"hit": "res://audio/sfx_hit.ogg",
	"takehit": "res://audio/sfx_takehit.ogg",
	"death": "res://audio/sfx_death.ogg",
	"loot": "res://audio/sfx_loot.ogg",
	"ui": "res://audio/sfx_ui.ogg",
	"npc": "res://audio/sfx_npc.ogg",
}
const MUSIC := {
	"town": "res://audio/town_music.ogg",
	"dungeon": "res://audio/dungeon_ambience.ogg",
}

var muted := false
var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _sfx_cache := {}
var _cur_track := ""


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = -8.0
	add_child(_music)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)
	for k in SFX.keys():
		_sfx_cache[k] = load(SFX[k])


func play_sfx(name: String, vol_db := 0.0) -> void:
	if muted or not _sfx_cache.has(name):
		return
	var p := _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[name]
	p.volume_db = vol_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func play_music(track: String) -> void:
	if track == _cur_track:
		return
	_cur_track = track
	if not MUSIC.has(track):
		return
	var stream: AudioStream = load(MUSIC[track])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.volume_db = -8.0 if track == "town" else -10.0
	if not muted:
		_music.play()


func set_muted(v: bool) -> void:
	muted = v
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), v)
	if not v and _cur_track != "" and not _music.playing:
		_music.play()
