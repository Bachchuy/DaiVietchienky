class_name UnitAnimatorComponent
extends Node
## Builds SpriteFrames/AnimationPlayer clips from 32x32 sprite sheets and drives unit playback.

signal animation_finished(anim_name: String)

const FRAME_DURATION_IDLE: float = 0.65
const FRAME_DURATION_WALK: float = 0.16
const FRAME_DURATION_ATTACK: float = 0.12
const FRAME_DURATION_HURT: float = 0.15
const FRAME_DURATION_DEATH: float = 0.18

@export var sprite: Sprite2D
@export var anim_player: AnimationPlayer
@export var cell_size: int = 32

var _current_anim: String = ""
var _is_dead: bool = false


func _ready() -> void:
	_resolve_nodes()
	if sprite != null and sprite.texture != null:
		setup_sprite_texture(sprite.texture)


func _resolve_nodes() -> void:
	var owner_node: Node = get_parent()
	if sprite == null and owner_node != null:
		sprite = owner_node.get_node_or_null("Sprite2D") as Sprite2D
	if anim_player == null and owner_node != null:
		anim_player = owner_node.get_node_or_null("AnimationPlayer") as AnimationPlayer


## Configures Sprite2D frame grid and generates idle/walk/attack/hurt/death clips.
func setup_sprite_texture(tex: Texture2D) -> void:
	_resolve_nodes()
	if sprite == null or tex == null:
		return

	sprite.texture = tex
	var tw: int = maxi(cell_size, tex.get_width())
	var th: int = maxi(cell_size, tex.get_height())
	@warning_ignore("integer_division")
	var cols: int = maxi(1, tw / maxi(1, cell_size))
	@warning_ignore("integer_division")
	var rows: int = maxi(1, th / maxi(1, cell_size))

	sprite.hframes = cols
	sprite.vframes = rows
	var tex_name: String = tex.resource_path.get_file().to_lower() if not tex.resource_path.is_empty() else ""
	var is_mounted: bool = tex_name.contains("cavalier") or tex_name.contains("horse") or tex_name.contains("knight") or tex_name.contains("rider")
	sprite.scale = Vector2(1.2, 1.2) if is_mounted else Vector2(1.5, 1.5)
	sprite.offset = Vector2(0.0, -9.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_build_animation_library(cols, rows, tex_name)
	_is_dead = false
	_current_anim = ""
	play_anim("idle")


func _resolve_row_layout(rows: int, tex_name: String) -> Dictionary:
	if tex_name.contains("king"):
		return {"idle": 0, "walk": 2, "attack": 4, "hurt": 5, "death": 6}
	if tex_name.contains("knight") or tex_name.contains("cavalier") or tex_name.contains("rider") or tex_name.contains("horse"):
		return {"idle": 0, "walk": 1, "attack": 4, "hurt": 5, "death": 6}
	if tex_name.contains("arch_mage") or tex_name.contains("archmage") or tex_name.contains("mage"):
		return {
			"idle": 0,
			"walk": 1,
			"attack": 6 if rows >= 7 else (3 if rows >= 4 else maxi(0, rows - 1)),
			"hurt": 5 if rows >= 6 else (4 if rows >= 5 else maxi(0, rows - 2)),
			"death": maxi(0, rows - 1),
		}
	return {
		"idle": 0,
		"walk": 1 if rows >= 2 else 0,
		"attack": 3 if rows >= 4 else maxi(0, rows - 1),
		"hurt": 4 if rows >= 5 else maxi(0, rows - 2),
		"death": maxi(0, rows - 1),
	}


func _build_animation_library(cols: int, rows: int, tex_name: String) -> void:
	if anim_player == null:
		return
	if not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)

	var layout: Dictionary = _resolve_row_layout(rows, tex_name)
	var library := AnimationLibrary.new()
	var clip_specs: Array[Dictionary] = [
		{"name": "idle", "row": int(layout["idle"]), "count": mini(cols, 4), "loop": true, "dur": FRAME_DURATION_IDLE},
		{"name": "walk", "row": int(layout["walk"]), "count": mini(cols, 6), "loop": true, "dur": FRAME_DURATION_WALK},
		{"name": "attack", "row": int(layout["attack"]), "count": mini(cols, 6), "loop": false, "dur": FRAME_DURATION_ATTACK},
		{"name": "hurt", "row": int(layout["hurt"]), "count": mini(cols, 4), "loop": false, "dur": FRAME_DURATION_HURT},
		{"name": "death", "row": int(layout["death"]), "count": mini(cols, 6), "loop": false, "dur": FRAME_DURATION_DEATH},
	]
	for spec: Dictionary in clip_specs:
		var frames: Array[int] = _get_row_frames(clampi(int(spec["row"]), 0, rows - 1), cols, int(spec["count"]))
		library.add_animation(str(spec["name"]), _create_clip(frames, bool(spec["loop"]), float(spec["dur"])))

	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", library)


func _get_row_frames(row_idx: int, cols: int, count: int) -> Array[int]:
	var frames: Array[int] = []
	var start_idx: int = row_idx * cols
	var max_count: int = clampi(count, 1, cols)

	if sprite != null and sprite.texture != null:
		var img: Image = sprite.texture.get_image()
		if img != null and not img.is_empty():
			var valid_frames: Array[int] = []
			for i: int in range(cols):
				if _is_cell_non_empty(img, i * cell_size, row_idx * cell_size):
					valid_frames.append(start_idx + i)
			if not valid_frames.is_empty():
				var take_n: int = mini(max_count, valid_frames.size())
				for k: int in range(take_n):
					frames.append(valid_frames[k])
				return frames

	for i: int in range(max_count):
		frames.append(start_idx + i)
	return frames


func _is_cell_non_empty(img: Image, x: int, y: int) -> bool:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for cx: int in range(x, mini(x + cell_size, w)):
		for cy: int in range(y, mini(y + cell_size, h)):
			if img.get_pixel(cx, cy).a > 0.05:
				return true
	return false


func _create_clip(frame_indices: Array[int], is_looping: bool, frame_dur: float) -> Animation:
	var anim := Animation.new()
	var track_idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "Sprite2D:frame")
	anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)

	var t: float = 0.0
	for f: int in frame_indices:
		anim.track_insert_key(track_idx, t, f)
		t += frame_dur
	anim.length = maxf(frame_dur, t)
	anim.loop_mode = Animation.LOOP_LINEAR if is_looping else Animation.LOOP_NONE
	return anim


## Plays an animation clip if available, locking into death when defeated.
func play_anim(anim_name: String, force_restart: bool = false) -> void:
	_resolve_nodes()
	if _is_dead and anim_name != "death":
		return
	if anim_player == null or not anim_player.has_animation(anim_name):
		return
	if _current_anim == anim_name and not force_restart and anim_player.is_playing():
		return

	if anim_name == "death":
		_is_dead = true
	_current_anim = anim_name
	if force_restart:
		anim_player.stop()
	anim_player.play(anim_name)


## Clears death state and returns playback to idle.
func reset_alive() -> void:
	_is_dead = false
	_current_anim = ""
	play_anim("idle", true)


## Flips the sprite horizontally based on facing side.
func set_facing_left(face_left: bool) -> void:
	_resolve_nodes()
	if sprite != null:
		sprite.flip_h = face_left


## Returns the active animation clip name.
func get_current_anim() -> String:
	return _current_anim


## Returns true if the given animation clip exists in the AnimationPlayer library.
func has_anim(anim_name: String) -> bool:
	_resolve_nodes()
	return anim_player != null and anim_player.has_animation(anim_name)


func _on_anim_finished(anim_name: StringName) -> void:
	var anim_str: String = str(anim_name)
	animation_finished.emit(anim_str)
	if not _is_dead and anim_str in ["attack", "hurt"]:
		play_anim("idle")
