class_name StatusBadgeComponent
extends Node2D
## Renders compact status and morale badges above a unit without relying on fonts.

@export var badge_offset: Vector2 = Vector2(0.0, -30.0)

var _active_badges: Array[String] = []


func _ready() -> void:
	z_index = 26
	queue_redraw()


## Synchronizes badge state directly from a read-only BattleUnit reference.
func sync_from_unit(unit: BattleUnit) -> void:
	if unit == null or unit.state == null:
		_active_badges.clear()
		queue_redraw()
		return
	set_status(
		int(unit.state.morale),
		unit.state.chaos_turns,
		unit.state.march_disabled_turns,
		unit.state.attack_disabled_turns,
		unit.state.skill_disabled_turns,
		unit.is_commander_in_chief,
		unit.state.has_acted
	)


## Sets explicit status parameters and updates active badge codes deterministically.
func set_status(
	morale_level: int,
	chaos_turns: int,
	march_lock: int,
	attack_lock: int,
	skill_lock: int,
	is_commander: bool,
	has_acted: bool
) -> void:
	_active_badges.clear()
	if is_commander:
		_active_badges.append("COMMANDER")
	if morale_level == 0 or chaos_turns > 0:
		_active_badges.append("MORALE_CHAOS")
	elif morale_level == 3:
		_active_badges.append("MORALE_HIGH")
	elif morale_level == 1:
		_active_badges.append("MORALE_LOW")
	if march_lock > 0:
		_active_badges.append("MARCH_LOCKED")
	if attack_lock > 0:
		_active_badges.append("ATTACK_LOCKED")
	if skill_lock > 0:
		_active_badges.append("SKILL_LOCKED")
	if has_acted:
		_active_badges.append("ACTED")
	queue_redraw()


## Returns a copy of active badge codes for verification and UI inspection.
func get_active_badges() -> Array[String]:
	return _active_badges.duplicate()


func _color_for_badge(badge: String) -> Color:
	match badge:
		"COMMANDER":
			return Color(1.0, 0.84, 0.22, 1.0)
		"MORALE_HIGH":
			return Color(0.24, 0.90, 0.45, 1.0)
		"MORALE_LOW":
			return Color(0.95, 0.65, 0.20, 1.0)
		"MORALE_CHAOS":
			return Color(0.88, 0.20, 0.90, 1.0)
		"MARCH_LOCKED":
			return Color(0.32, 0.72, 0.96, 1.0)
		"ATTACK_LOCKED":
			return Color(0.95, 0.28, 0.28, 1.0)
		"SKILL_LOCKED":
			return Color(0.66, 0.44, 0.92, 1.0)
		"ACTED":
			return Color(0.55, 0.57, 0.62, 1.0)
		_:
			return Color.WHITE


func _draw() -> void:
	if _active_badges.is_empty():
		return
	var pip_size: float = 4.0
	var spacing: float = 2.0
	var total_w: float = float(_active_badges.size()) * (pip_size + spacing) - spacing
	var start_x: float = badge_offset.x - total_w * 0.5

	for i: int in range(_active_badges.size()):
		var badge: String = _active_badges[i]
		var pos := Vector2(start_x + float(i) * (pip_size + spacing), badge_offset.y)
		var rect := Rect2(pos, Vector2(pip_size, pip_size))
		draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2(pip_size + 1.0, pip_size + 1.0)), Color(0.05, 0.05, 0.07, 0.9), true)
		draw_rect(rect, _color_for_badge(badge), true)
