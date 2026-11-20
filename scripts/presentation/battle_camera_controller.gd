class_name BattleCameraController
extends Camera2D

signal strategic_lod_changed(use_strategic_tokens: bool)
signal clean_right_clicked(screen_pos: Vector2)

const ZOOM_TACTICAL: float = 1.2
const ZOOM_DEFAULT: float = 1.0
const ZOOM_STRATEGIC: float = 0.5
const DEFAULT_STRATEGIC_THRESHOLD: float = 0.65
const DRAG_THRESHOLD_PX: float = 6.0

@export_group("Navigation & Bounds")
@export var smooth_speed: float = 10.0
@export var zoom_smooth_speed: float = 12.0
@export var keyboard_pan_speed: float = 680.0
@export var zoom_step: float = 0.12
@export var strategic_token_threshold: float = DEFAULT_STRATEGIC_THRESHOLD
@export var map_world_bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1400.0)

@export_group("Trauma Screen Shake")
@export var trauma_decay: float = 1.2
@export var max_shake_offset: Vector2 = Vector2(14.0, 10.0)
@export_range(0.0, 1.0, 0.05) var shake_user_scale: float = 1.0

var camera_locked: bool = false

var _focus_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: float = ZOOM_DEFAULT
var _current_zoom: float = ZOOM_DEFAULT
var _is_strategic_mode: bool = false
var _trauma: float = 0.0
var _is_mouse_dragging: bool = false
var _drag_button: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_accumulated: Vector2 = Vector2.ZERO
var _drag_exceeded_threshold: bool = false

## Visual-only RNG strictly isolated from core battle simulation RNG.
var _fx_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_fx_rng.randomize()
	_focus_position = global_position
	_target_position = global_position
	zoom = Vector2(_current_zoom, _current_zoom)
	make_current()


func _unhandled_input(event: InputEvent) -> void:
	if camera_locked:
		_reset_drag_state()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if (
			mb.button_index == MOUSE_BUTTON_MIDDLE
			or mb.button_index == MOUSE_BUTTON_RIGHT
			or mb.button_index == MOUSE_BUTTON_LEFT
		):
			if mb.pressed:
				_drag_button = mb.button_index
				_drag_start_pos = mb.position
				_drag_accumulated = Vector2.ZERO
				_drag_exceeded_threshold = false
				_is_mouse_dragging = false
			elif mb.button_index == _drag_button:
				var btn: int = _drag_button
				var was_drag: bool = _drag_exceeded_threshold
				_reset_drag_state()
				if was_drag:
					if get_viewport() != null:
						get_viewport().set_input_as_handled()
				elif btn == MOUSE_BUTTON_RIGHT:
					clean_right_clicked.emit(mb.position)
					if get_viewport() != null:
						get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom_level(_target_zoom + zoom_step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_level(_target_zoom - zoom_step)
	elif event is InputEventMouseMotion and _drag_button != -1:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_drag_accumulated += mm.relative
		var dist: float = maxf(mm.position.distance_to(_drag_start_pos), _drag_accumulated.length())
		if not _drag_exceeded_threshold and dist > DRAG_THRESHOLD_PX:
			_drag_exceeded_threshold = true
			_is_mouse_dragging = true
		if _is_mouse_dragging:
			_target_position = _clamp_to_map_bounds(_target_position - mm.relative / maxf(_current_zoom, 0.1))
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		_target_position = _clamp_to_map_bounds(_target_position - sd.relative / maxf(_current_zoom, 0.1))
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		set_zoom_level(_target_zoom * mg.factor)
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			match ke.keycode:
				KEY_1:
					set_zoom_level(ZOOM_TACTICAL)
				KEY_2:
					set_zoom_level(ZOOM_DEFAULT)
				KEY_3:
					set_zoom_level(ZOOM_STRATEGIC)
				KEY_EQUAL, KEY_KP_ADD:
					set_zoom_level(_target_zoom + zoom_step)
				KEY_MINUS, KEY_KP_SUBTRACT:
					set_zoom_level(_target_zoom - zoom_step)
				_:
					pass


func _process(delta: float) -> void:
	if not camera_locked:
		_poll_keyboard_pan(delta)

	# 1. FPS-independent exponential zoom interpolation & StrategicToken LOD threshold
	var zoom_t: float = 1.0 - exp(-zoom_smooth_speed * delta)
	_current_zoom = lerpf(_current_zoom, _target_zoom, zoom_t)
	zoom = Vector2(_current_zoom, _current_zoom)

	var should_use_tokens: bool = _current_zoom < strategic_token_threshold
	if should_use_tokens != _is_strategic_mode:
		_is_strategic_mode = should_use_tokens
		strategic_lod_changed.emit(_is_strategic_mode)

	# 2. FPS-independent exponential focus follow & zoom-aware viewport clamping
	_target_position = _clamp_to_map_bounds(_target_position)
	var move_t: float = 1.0 - exp(-smooth_speed * delta)
	_focus_position = _focus_position.lerp(_target_position, move_t)
	global_position = _clamp_to_map_bounds(_focus_position)

	# 3. Non-linear Trauma Shake (trauma^2) written strictly to visual offset
	if _trauma > 0.0:
		var real_dt: float = delta / maxf(Engine.time_scale, 0.0001)
		var shake: float = _trauma * _trauma * shake_user_scale
		if shake > 0.0:
			var angle: float = _fx_rng.randf_range(0.0, TAU)
			var dir := Vector2(cos(angle), sin(angle))
			offset = Vector2(dir.x * max_shake_offset.x, dir.y * max_shake_offset.y) * shake
		else:
			offset = Vector2.ZERO
		_trauma = maxf(_trauma - trauma_decay * real_dt, 0.0)
		if _trauma == 0.0:
			offset = Vector2.ZERO
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


func _poll_keyboard_pan(delta: float) -> void:
	var pan_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_dir.y += 1.0
	if pan_dir != Vector2.ZERO:
		var velocity: Vector2 = pan_dir.normalized() * (keyboard_pan_speed / maxf(_current_zoom, 0.1))
		_target_position = _clamp_to_map_bounds(_target_position + velocity * delta)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_trauma() -> float:
	return _trauma


func is_strategic_mode() -> bool:
	return _is_strategic_mode


func is_mouse_dragging() -> bool:
	return _is_mouse_dragging


func _reset_drag_state() -> void:
	_drag_button = -1
	_drag_start_pos = Vector2.ZERO
	_drag_accumulated = Vector2.ZERO
	_drag_exceeded_threshold = false
	_is_mouse_dragging = false


func pan_to_world_pos(world_pos: Vector2, instant: bool = false) -> void:
	_target_position = _clamp_to_map_bounds(world_pos)
	if instant:
		_focus_position = _target_position
		global_position = _focus_position


func set_zoom_level(new_zoom: float, instant: bool = false) -> void:
	_target_zoom = clampf(new_zoom, ZOOM_STRATEGIC, ZOOM_TACTICAL)
	if instant:
		_current_zoom = _target_zoom
		zoom = Vector2(_current_zoom, _current_zoom)
		var should_use_tokens: bool = _current_zoom < strategic_token_threshold
		if should_use_tokens != _is_strategic_mode:
			_is_strategic_mode = should_use_tokens
			strategic_lod_changed.emit(_is_strategic_mode)


func _clamp_to_map_bounds(pos: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)
	var half_view: Vector2 = (vp_size * 0.5) / maxf(_current_zoom, 0.1)
	var clamped: Vector2 = pos

	if map_world_bounds.size.x <= half_view.x * 2.0:
		clamped.x = map_world_bounds.get_center().x
	else:
		clamped.x = clampf(
			pos.x,
			map_world_bounds.position.x + half_view.x,
			map_world_bounds.end.x - half_view.x
		)

	if map_world_bounds.size.y <= half_view.y * 2.0:
		clamped.y = map_world_bounds.get_center().y
	else:
		clamped.y = clampf(
			pos.y,
			map_world_bounds.position.y + half_view.y,
			map_world_bounds.end.y - half_view.y
		)

	return clamped
