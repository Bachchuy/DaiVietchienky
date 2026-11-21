@tool
class_name UnitPlacementMarker
extends Node2D
## Editor-draggable placement marker synced with UnitPlacementDef (`res://game/battle/map/`).

@export_group("Unit")
@export var unit_id: int = 0
@export var faction_id: int = 1:
	set(value):
		faction_id = value
		queue_redraw()
@export var troop_id: int = 40101
@export_range(1, 3) var troop_stack: int = 1
@export var hex_pos: Vector2i = Vector2i.ZERO:
	set(value):
		if hex_pos == value:
			return
		hex_pos = value
		if not _suppress_pos_sync and is_inside_tree():
			var map_tool: Node = _find_stage_map_tool()
			if map_tool != null and map_tool.has_method("odd_r_to_marker_local"):
				_suppress_pos_sync = true
				position = map_tool.call("odd_r_to_marker_local", hex_pos)
				_suppress_pos_sync = false
		queue_redraw()
@export var display_name_override: String = ""
@export_range(0, 5) var facing: int = 0
@export_enum("CHAOS", "LOW", "NORMAL", "HIGH") var initial_morale: String = "NORMAL"
@export var is_invisible: bool = false
@export var is_morale_locked: bool = false
@export_enum("None:-1", "Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var fond_terrain_override: int = -1
@export var max_hp_override: int = 0
@export var current_hp_override: int = 0

@export_group("Commander")
@export var general_id: int = 0
@export var general_name: String = "":
	set(value):
		general_name = value
		queue_redraw()
@export var is_commander_in_chief: bool = false:
	set(value):
		is_commander_in_chief = value
		queue_redraw()
@export_range(0, 100) var general_command_stat: int = 0
@export_range(0, 100) var general_luck: int = 0
@export_range(0.5, 2.0, 0.01) var m_command: float = 1.0
@export_range(0, 6) var aura_radius_hex: int = 0
@export_range(0, 100) var aura_damage_deepen: int = 0
@export_range(0, 100) var aura_damage_resist: int = 0
@export var grants_dead_mate_immunity: bool = false

@export_group("Historical Metadata")
@export_enum("historical_claim", "fixture", "abstraction", "what_if") var modeling_type: String = "fixture"
@export_multiline var source_ref: String = ""

var _suppress_pos_sync: bool = false


func _ready() -> void:
	set_notify_transform(Engine.is_editor_hint())
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _suppress_pos_sync:
		sync_hex_from_position()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var fill_color: Color = Color(0.18, 0.48, 0.92, 0.85)
	if faction_id == 2:
		fill_color = Color(0.86, 0.22, 0.20, 0.85)
	elif faction_id >= 3:
		fill_color = Color(0.24, 0.72, 0.36, 0.85)

	draw_circle(Vector2.ZERO, 6.5, fill_color)
	var rim_color: Color = Color(0.98, 0.84, 0.28, 1.0) if is_commander_in_chief else Color(1.0, 1.0, 1.0, 0.95)
	draw_arc(Vector2.ZERO, 6.8, 0.0, TAU, 16, rim_color, 1.2)
	if is_commander_in_chief:
		draw_circle(Vector2(0.0, -7.5), 2.0, Color(0.98, 0.84, 0.28, 1.0))

	var font: Font = ThemeDB.fallback_font
	if font != null:
		var short_label: String = str(unit_id) if general_name.is_empty() else "%d:%s" % [unit_id, general_name]
		draw_string(font, Vector2(-12.0, 14.0), short_label, HORIZONTAL_ALIGNMENT_CENTER, 24.0, 7, Color(1.0, 0.98, 0.88, 0.95))


func apply_from_def(def: UnitPlacementDef) -> void:
	if def == null:
		return
	_suppress_pos_sync = true
	unit_id = def.unit_id
	faction_id = def.faction_id
	troop_id = def.troop_id
	troop_stack = def.troop_stack
	hex_pos = def.hex_pos
	display_name_override = def.display_name_override
	facing = def.facing
	initial_morale = def.initial_morale
	is_invisible = def.is_invisible
	is_morale_locked = def.is_morale_locked
	fond_terrain_override = def.fond_terrain_override
	max_hp_override = def.max_hp_override
	current_hp_override = def.current_hp_override
	general_id = def.general_id
	general_name = def.general_name
	is_commander_in_chief = def.is_commander_in_chief
	general_command_stat = def.general_command_stat
	general_luck = def.general_luck
	m_command = def.m_command
	aura_radius_hex = def.aura_radius_hex
	aura_damage_deepen = def.aura_damage_deepen
	aura_damage_resist = def.aura_damage_resist
	grants_dead_mate_immunity = def.grants_dead_mate_immunity
	modeling_type = def.modeling_type
	source_ref = def.source_ref
	_suppress_pos_sync = false
	queue_redraw()


func to_placement_def() -> UnitPlacementDef:
	var out: UnitPlacementDef = UnitPlacementDef.new()
	out.unit_id = unit_id
	out.faction_id = faction_id
	out.troop_id = troop_id
	out.troop_stack = troop_stack
	out.hex_pos = hex_pos
	out.display_name_override = display_name_override
	out.facing = facing
	out.initial_morale = initial_morale
	out.is_invisible = is_invisible
	out.is_morale_locked = is_morale_locked
	out.fond_terrain_override = fond_terrain_override
	out.max_hp_override = max_hp_override
	out.current_hp_override = current_hp_override
	out.general_id = general_id
	out.general_name = general_name
	out.is_commander_in_chief = is_commander_in_chief
	out.general_command_stat = general_command_stat
	out.general_luck = general_luck
	out.m_command = m_command
	out.aura_radius_hex = aura_radius_hex
	out.aura_damage_deepen = aura_damage_deepen
	out.aura_damage_resist = aura_damage_resist
	out.grants_dead_mate_immunity = grants_dead_mate_immunity
	out.modeling_type = modeling_type
	out.source_ref = source_ref
	return out


func sync_hex_from_position() -> Vector2i:
	var map_tool: Node = _find_stage_map_tool()
	if map_tool != null and map_tool.has_method("marker_local_to_odd_r"):
		var sampled: Vector2i = map_tool.call("marker_local_to_odd_r", position)
		if sampled != hex_pos:
			_suppress_pos_sync = true
			hex_pos = sampled
			_suppress_pos_sync = false
			queue_redraw()
	return hex_pos


func snap_to_hex(target_hex: Vector2i) -> void:
	_suppress_pos_sync = true
	hex_pos = target_hex
	var map_tool: Node = _find_stage_map_tool()
	if map_tool != null and map_tool.has_method("odd_r_to_marker_local"):
		position = map_tool.call("odd_r_to_marker_local", target_hex)
	_suppress_pos_sync = false
	queue_redraw()


func _find_stage_map_tool() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("marker_local_to_odd_r"):
			return cursor
		cursor = cursor.get_parent()
	return null
