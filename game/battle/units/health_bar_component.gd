class_name HealthBarComponent
extends Node2D
## Draws compact unit HP bar, 100-HP dividers, and active TroopStack banners (no damage preview).

@export var bar_offset: Vector2 = Vector2(-14.0, -24.0)
@export var bar_size: Vector2 = Vector2(28.0, 4.0)
@export var show_when_full: bool = true

var _current_hp: int = 160
var _max_hp: int = 160
var _active_banners: int = 1
var _max_banners: int = 1
var _faction_accent: Color = Color(0.86, 0.18, 0.16, 1.0)


func _ready() -> void:
	z_index = 25
	queue_redraw()


## Updates HP and banner counts and triggers a redraw (hides when HP <= 0).
func set_health(p_current_hp: int, p_max_hp: int, p_active_banners: int = 1, p_max_banners: int = 1) -> void:
	_max_hp = maxi(0, p_max_hp)
	_current_hp = clampi(p_current_hp, 0, maxi(1, _max_hp))
	_max_banners = clampi(p_max_banners, 1, 3)
	_active_banners = clampi(p_active_banners, 0, _max_banners)
	visible = _current_hp > 0 and _max_hp > 0
	queue_redraw()


## Sets the faction color accent strip on the left side of the health bar.
func set_faction_accent(color: Color) -> void:
	_faction_accent = color
	queue_redraw()


## Returns normalized HP ratio in `[0.0, 1.0]`.
func get_hp_ratio() -> float:
	if _max_hp <= 0:
		return 0.0
	return clampf(float(_current_hp) / float(_max_hp), 0.0, 1.0)


## Returns cached current HP.
func get_current_hp() -> int:
	return _current_hp


## Returns cached maximum HP.
func get_max_hp() -> int:
	return _max_hp


## Returns cached active TroopStack banner count.
func get_active_banners() -> int:
	return _active_banners


func _draw() -> void:
	if _max_hp <= 0 or _current_hp <= 0:
		return
	if not show_when_full and _current_hp == _max_hp:
		return

	var ratio: float = get_hp_ratio()
	draw_rect(Rect2(bar_offset, bar_size), Color(0.05, 0.05, 0.07, 0.92), true)
	draw_rect(Rect2(bar_offset, bar_size), Color(0.18, 0.18, 0.22, 0.95), false, 0.5)
	draw_rect(Rect2(bar_offset, Vector2(2.0, bar_size.y)), _faction_accent, true)

	var hp_color: Color = Color(0.22, 0.88, 0.45, 1.0)
	if ratio <= 0.3:
		hp_color = Color(0.95, 0.25, 0.25, 1.0)
	elif ratio <= 0.6:
		hp_color = Color(0.95, 0.75, 0.20, 1.0)

	var inner_origin: Vector2 = bar_offset + Vector2(3.0, 1.0)
	var max_inner_w: float = maxf(2.0, bar_size.x - 4.0)
	var inner_w: float = maxf(1.0, max_inner_w * ratio)
	draw_rect(Rect2(inner_origin, Vector2(inner_w, maxf(1.0, bar_size.y - 2.0))), hp_color, true)

	# 100-HP visual dividers for multi-hundred HP units
	if _max_hp >= 200:
		@warning_ignore("integer_division")
		var step_count: int = _max_hp / 100
		for step_i: int in range(1, step_count):
			var tick_x: float = inner_origin.x + max_inner_w * (float(step_i * 100) / float(_max_hp))
			draw_line(
				Vector2(tick_x, bar_offset.y),
				Vector2(tick_x, bar_offset.y + bar_size.y),
				Color(0.06, 0.06, 0.08, 0.85),
				1.0
			)

	# Banner pips above the bar (DEC-020)
	for b: int in range(_max_banners):
		var pip_pos: Vector2 = bar_offset + Vector2(float(b) * 5.0, -4.0)
		var pip_col: Color = _faction_accent if b < _active_banners else Color(0.22, 0.22, 0.25, 0.65)
		draw_rect(Rect2(pip_pos, Vector2(3.5, 2.5)), pip_col, true)
