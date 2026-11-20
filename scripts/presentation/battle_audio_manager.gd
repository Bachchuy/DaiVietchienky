class_name BattleAudioManager
extends Node

const BUS_NAMES: Array[String] = ["Master", "BGM", "SFX", "Voice/Horn", "UI"]
const POOL_2D_COUNT: int = 24
const POOL_UI_COUNT: int = 6

const SFX_PATHS: Dictionary[String, String] = {
	"sword_hit": "res://assets_clean/audio/sfx_sword_hit.wav",
	"sfx_sword_hit": "res://assets_clean/audio/sfx_sword_hit.wav",
	"arrow_shot": "res://assets_clean/audio/sfx_arrow_shot.wav",
	"sfx_arrow_shot": "res://assets_clean/audio/sfx_arrow_shot.wav",
	"horn_charge": "res://assets_clean/audio/sfx_horn_charge.wav",
	"sfx_horn_charge": "res://assets_clean/audio/sfx_horn_charge.wav",
	"water_splash": "res://assets_clean/audio/sfx_water_splash.wav",
	"sfx_water_splash": "res://assets_clean/audio/sfx_water_splash.wav",
	"fire_ignite": "res://assets_clean/audio/sfx_fire_ignite.wav",
	"sfx_fire_ignite": "res://assets_clean/audio/sfx_fire_ignite.wav",
	"ui_click": "res://assets_clean/audio/sfx_ui_click.wav",
	"sfx_ui_click": "res://assets_clean/audio/sfx_ui_click.wav",
	"bgm_bach_dang": "res://assets_clean/audio/bgm_bach_dang_ambient.wav",
}

var _players_2d: Array[AudioStreamPlayer2D] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _cursor_2d: int = 0
var _cursor_ui: int = 0
var _bgm_state: StringName = &"player_turn"


func _ready() -> void:
	setup()


func setup() -> void:
	_ensure_audio_buses()
	_preload_streams()
	_ensure_player_pools()


func _ensure_audio_buses() -> void:
	for b_name: String in BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(b_name)
		if idx == -1:
			AudioServer.add_bus()
			var new_idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(new_idx, b_name)
			if b_name != "Master":
				AudioServer.set_bus_send(new_idx, "Master")

	var has_limiter: bool = false
	for i: int in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.3
		AudioServer.add_bus_effect(0, limiter)


func _preload_streams() -> void:
	for k: String in SFX_PATHS.keys():
		var path: String = SFX_PATHS[k]
		if not _streams.has(k) and ResourceLoader.exists(path):
			var st: AudioStream = load(path) as AudioStream
			if st != null:
				_streams[k] = st


func _ensure_player_pools() -> void:
	if _players_2d.size() == POOL_2D_COUNT and _players_ui.size() >= POOL_UI_COUNT:
		return
	for child: Node in get_children():
		child.queue_free()
	_players_2d.clear()
	_players_ui.clear()

	for i: int in range(POOL_2D_COUNT):
		var p2d := AudioStreamPlayer2D.new()
		p2d.name = "AudioPool2D_%02d" % i
		p2d.bus = "SFX"
		add_child(p2d)
		_players_2d.append(p2d)

	for j: int in range(POOL_UI_COUNT):
		var pui := AudioStreamPlayer.new()
		pui.name = "AudioPoolUI_%02d" % j
		pui.bus = "UI" if j < 4 else "BGM"
		add_child(pui)
		_players_ui.append(pui)


func set_bus_linear_volume(bus_name: String, linear_val: float) -> void:
	_ensure_audio_buses()
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped: float = clampf(linear_val, 0.0, 1.0)
	if clamped <= 0.0001:
		AudioServer.set_bus_volume_db(idx, -80.0)
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))


func get_bus_linear_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1 or AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)


func play_sfx(
	sfx_key: String,
	world_pos: Vector2 = Vector2.ZERO,
	era: String = "Tran_Nguyen"
) -> bool:
	var k_low: String = sfx_key.to_lower()
	var era_low: String = era.to_lower()
	if k_low.contains("gun") or k_low.contains("cannon") or k_low.contains("musket"):
		if era_low.contains("tran") or era_low.contains("1288") or era_low.contains("ly"):
			return false
	if not _streams.has(sfx_key):
		return false
	if _players_2d.is_empty():
		_ensure_player_pools()
	if _players_2d.is_empty():
		return false

	var p: AudioStreamPlayer2D = _players_2d[_cursor_2d % _players_2d.size()]
	_cursor_2d = (_cursor_2d + 1) % _players_2d.size()
	p.bus = "Voice/Horn" if k_low.contains("horn") else "SFX"
	p.position = world_pos
	p.stream = _streams[sfx_key] as AudioStream
	p.play()
	return true


func play_ui_sfx(sfx_key: String = "ui_click") -> bool:
	if not _streams.has(sfx_key):
		return false
	if _players_ui.is_empty():
		_ensure_player_pools()
	if _players_ui.is_empty():
		return false

	var p: AudioStreamPlayer = _players_ui[_cursor_ui % _players_ui.size()]
	_cursor_ui = (_cursor_ui + 1) % _players_ui.size()
	p.bus = "UI"
	p.stream = _streams[sfx_key] as AudioStream
	p.play()
	return true


func set_bgm_state(new_state: StringName) -> void:
	_bgm_state = new_state


func get_bgm_state() -> StringName:
	return _bgm_state
