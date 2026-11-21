class_name HexOverlayLayer
extends Node2D
## Crisp vector tactical overlay aligned to TileMapLayer hex centers (`res://game/battle/map/`).

const GRID_COLOR: Color = Color(0.10, 0.14, 0.12, 0.16)
const OBJECTIVE_RIM_COLOR: Color = Color(0.95, 0.78, 0.22, 0.80)
const STAKE_WOOD_COLOR: Color = Color(0.32, 0.20, 0.10, 0.95)
const STAKE_TIP_COLOR: Color = Color(0.82, 0.78, 0.68, 0.95)
const REACHABLE_FILL: Color = Color(0.18, 0.56, 0.95, 0.26)
const REACHABLE_RIM: Color = Color(0.38, 0.80, 1.0, 0.78)
const ATTACKABLE_FILL: Color = Color(0.92, 0.22, 0.20, 0.28)
const ATTACKABLE_RIM: Color = Color(1.0, 0.42, 0.36, 0.88)
const SKILL_FILL_HARM: Color = Color(0.96, 0.62, 0.16, 0.28)
const SKILL_RIM_HARM: Color = Color(1.0, 0.78, 0.28, 0.88)
const SKILL_FILL_HEAL: Color = Color(0.22, 0.86, 0.48, 0.28)
const SKILL_RIM_HEAL: Color = Color(0.45, 1.0, 0.65, 0.88)
const SELECT_RIM_COLOR: Color = Color(1.0, 0.88, 0.28, 0.95)
const HOVER_RIM_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const PATH_COLOR: Color = Color(0.98, 0.86, 0.32, 0.92)
const SHROUD_FILL: Color = Color(0.05, 0.06, 0.08, 0.52)

var _centers: Dictionary[Vector2i, Vector2] = {}
var _hex_poly: PackedVector2Array = PackedVector2Array()
var _inner_poly: PackedVector2Array = PackedVector2Array()
var _cell_size: Vector2 = Vector2(64.0, 48.0)

var _staked_hexes: Array[Vector2i] = []
var _objective_hexes: Array[Vector2i] = []
var _fog_states: Dictionary[Vector2i, int] = {}

var _reachable_hexes: Dictionary[Vector2i, int] = {}
var _attackable_hexes: Array[Vector2i] = []
var _skill_hexes: Array[Vector2i] = []
var _skill_aoe_hexes: Array[Vector2i] = []
var _skill_is_heal: bool = false
var _selected_hex: Vector2i = Vector2i(-999, -999)
var _hover_hex: Vector2i = Vector2i(-999, -999)
var _preview_path: Array[Vector2i] = []


func configure_geometry(center_by_axial: Dictionary[Vector2i, Vector2], cell_world_size: Vector2) -> void:
	_centers = center_by_axial.duplicate()
	_cell_size = Vector2(maxf(8.0, cell_world_size.x), maxf(8.0, cell_world_size.y))
	_hex_poly = _build_hex_polygon(_cell_size, 1.0)
	_inner_poly = _build_hex_polygon(_cell_size, 0.88)
	queue_redraw()


func set_environment_markers(
	staked: Array[Vector2i],
	objectives: Array[Vector2i],
	fog: Dictionary[Vector2i, int] = {}
) -> void:
	_staked_hexes = staked.duplicate()
	_objective_hexes = objectives.duplicate()
	_fog_states = fog.duplicate()
	queue_redraw()


func set_tactical_overlays(
	reachable: Dictionary[Vector2i, int],
	attackable: Array[Vector2i],
	skill_hexes: Array[Vector2i] = [],
	skill_is_heal: bool = false,
	skill_aoe_hexes: Array[Vector2i] = []
) -> void:
	_reachable_hexes = reachable.duplicate()
	_attackable_hexes = attackable.duplicate()
	_skill_hexes = skill_hexes.duplicate()
	_skill_aoe_hexes = skill_aoe_hexes.duplicate()
	_skill_is_heal = skill_is_heal
	queue_redraw()


func set_skill_area_hexes(
	range_hexes: Array[Vector2i],
	aoe_hexes: Array[Vector2i] = [],
	is_heal: bool = false
) -> void:
	_skill_hexes = range_hexes.duplicate()
	_skill_aoe_hexes = aoe_hexes.duplicate()
	_skill_is_heal = is_heal
	queue_redraw()


func clear_skill_area_hexes() -> void:
	_skill_hexes.clear()
	_skill_aoe_hexes.clear()
	queue_redraw()


func get_skill_range_hexes() -> Array[Vector2i]:
	return _skill_hexes.duplicate()


func get_skill_aoe_hexes() -> Array[Vector2i]:
	return _skill_aoe_hexes.duplicate()


func set_selection(selected: Vector2i, hover: Vector2i, path: Array[Vector2i]) -> void:
	_selected_hex = selected
	_hover_hex = hover
	_preview_path = path.duplicate()
	queue_redraw()


func clear_tactical_overlays() -> void:
	_reachable_hexes.clear()
	_attackable_hexes.clear()
	_skill_hexes.clear()
	_skill_aoe_hexes.clear()
	_selected_hex = Vector2i(-999, -999)
	_preview_path.clear()
	queue_redraw()


func _draw() -> void:
	if _hex_poly.size() < 6:
		return

	_draw_grid_and_landmarks()
	_draw_tactical_zones()
	_draw_selection_and_path()
	_draw_fog_shroud()


func _draw_grid_and_landmarks() -> void:
	for center: Vector2 in _centers.values():
		_draw_hex_outline(center, _hex_poly, GRID_COLOR, 1.0)

	for obj_hex: Vector2i in _objective_hexes:
		if _centers.has(obj_hex):
			_draw_hex_outline(_centers[obj_hex], _inner_poly, OBJECTIVE_RIM_COLOR, 2.0)

	for stake_hex: Vector2i in _staked_hexes:
		if _centers.has(stake_hex):
			_draw_ironwood_stakes(_centers[stake_hex])


func _draw_tactical_zones() -> void:
	for hex: Vector2i in _reachable_hexes.keys():
		if _centers.has(hex):
			_draw_hex_filled(_centers[hex], _inner_poly, REACHABLE_FILL, REACHABLE_RIM, 1.8)

	for hex: Vector2i in _attackable_hexes:
		if _centers.has(hex):
			_draw_hex_filled(_centers[hex], _inner_poly, ATTACKABLE_FILL, ATTACKABLE_RIM, 2.0)

	var s_fill: Color = SKILL_FILL_HEAL if _skill_is_heal else SKILL_FILL_HARM
	var s_rim: Color = SKILL_RIM_HEAL if _skill_is_heal else SKILL_RIM_HARM
	for hex: Vector2i in _skill_hexes:
		if _centers.has(hex):
			_draw_hex_filled(_centers[hex], _inner_poly, s_fill, s_rim, 2.0)

	for hex: Vector2i in _skill_aoe_hexes:
		if _centers.has(hex):
			_draw_hex_filled(_centers[hex], _hex_poly, Color(s_rim.r, s_rim.g, s_rim.b, 0.34), SELECT_RIM_COLOR, 2.2)


func _draw_selection_and_path() -> void:
	if _centers.has(_hover_hex):
		_draw_hex_outline(_centers[_hover_hex], _inner_poly, HOVER_RIM_COLOR, 1.6)

	if _centers.has(_selected_hex):
		_draw_hex_outline(_centers[_selected_hex], _hex_poly, SELECT_RIM_COLOR, 2.6)

	if _preview_path.size() >= 2:
		var pts: PackedVector2Array = PackedVector2Array()
		for h: Vector2i in _preview_path:
			if _centers.has(h):
				pts.append(_centers[h])
		if pts.size() >= 2:
			draw_polyline(pts, PATH_COLOR, 3.0, true)
			draw_circle(pts[pts.size() - 1], 4.5, PATH_COLOR)


func _draw_fog_shroud() -> void:
	for hex: Vector2i in _fog_states.keys():
		var state_val: int = int(_fog_states[hex])
		if state_val < 2 and _centers.has(hex):
			_draw_hex_filled(_centers[hex], _hex_poly, SHROUD_FILL, Color(0, 0, 0, 0), 0.0)


func _draw_ironwood_stakes(center: Vector2) -> void:
	var s: float = _cell_size.y * 0.22
	var offsets: Array[Vector2] = [Vector2(-s, s * 0.4), Vector2(0.0, -s * 0.15), Vector2(s, s * 0.35)]
	for o: Vector2 in offsets:
		var base: Vector2 = center + o + Vector2(-s * 0.25, s * 0.45)
		var tip: Vector2 = center + o + Vector2(s * 0.35, -s * 0.55)
		draw_line(base, tip, STAKE_WOOD_COLOR, 2.6, true)
		draw_circle(tip, 1.6, STAKE_TIP_COLOR)


func _draw_hex_filled(center: Vector2, base_poly: PackedVector2Array, fill: Color, rim: Color, width: float) -> void:
	var pts: PackedVector2Array = _offset_poly(center, base_poly)
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	if width > 0.0 and rim.a > 0.0:
		_draw_closed_poly(pts, rim, width)


func _draw_hex_outline(center: Vector2, base_poly: PackedVector2Array, rim: Color, width: float) -> void:
	_draw_closed_poly(_offset_poly(center, base_poly), rim, width)


func _draw_closed_poly(pts: PackedVector2Array, rim: Color, width: float) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, rim, width, true)


static func _offset_poly(center: Vector2, base_poly: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(base_poly.size())
	for i: int in range(base_poly.size()):
		out[i] = center + base_poly[i]
	return out


static func _build_hex_polygon(cell_size: Vector2, shrink: float) -> PackedVector2Array:
	var hw: float = cell_size.x * 0.5 * shrink
	var hh: float = cell_size.y * 0.5 * shrink
	var qh: float = hh * 0.5
	return PackedVector2Array([
		Vector2(0.0, -hh),
		Vector2(hw, -qh),
		Vector2(hw, qh),
		Vector2(0.0, hh),
		Vector2(-hw, qh),
		Vector2(-hw, -qh),
	])


static func collect_objectives(stage_def: StageDef) -> Array[Vector2i]:
	var objectives: Array[Vector2i] = []
	if stage_def == null:
		return objectives
	for area_def: NamedAreaDef in stage_def.areas:
		if area_def != null and area_def.is_objective:
			for odd_r: Vector2i in area_def.hexes:
				objectives.append(HexMath.odd_r_to_axial(odd_r))
	return objectives


static func compute_world_bounds(
	centers: Dictionary[Vector2i, Vector2],
	cell_sz: Vector2,
	map_state: BattleMapState,
	fallback_hex_size: float
) -> Rect2:
	if centers.is_empty():
		var w: int = map_state.width if map_state != null else 12
		var h: int = map_state.height if map_state != null else 10
		return HexMath.compute_map_world_bounds(w, h, fallback_hex_size)
	var min_pt: Vector2 = Vector2(INF, INF)
	var max_pt: Vector2 = Vector2(-INF, -INF)
	for center: Vector2 in centers.values():
		min_pt.x = minf(min_pt.x, center.x - cell_sz.x * 0.5)
		min_pt.y = minf(min_pt.y, center.y - cell_sz.y * 0.5)
		max_pt.x = maxf(max_pt.x, center.x + cell_sz.x * 0.5)
		max_pt.y = maxf(max_pt.y, center.y + cell_sz.y * 0.5)
	return Rect2(min_pt, max_pt - min_pt).grow(cell_sz.x * 0.5)


static func collect_staked_hexes(map_state: BattleMapState) -> Array[Vector2i]:
	var staked: Array[Vector2i] = []
	if map_state == null:
		return staked
	for row: int in range(map_state.height):
		for col: int in range(map_state.width):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if map_state.get_terrain(ax) == BattleMapState.TerrainType.STAKED_WATER:
				staked.append(ax)
	return staked


static func collect_hostile_attack_hexes(
	map_state: BattleMapState,
	navigator: HexGridNavigator,
	unit: BattleUnit
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit == null or map_state == null or navigator == null:
		return out
	for cand: Vector2i in navigator.get_attackable_hexes(map_state, unit, unit.hex_position):
		var occ: BattleUnit = map_state.get_unit_at(cand)
		if occ != null and map_state.is_hostile(unit.faction_id, occ.faction_id):
			out.append(cand)
	return out


static func build_axial_centers(
	map_node: Node2D,
	ground: TileMapLayer,
	w: int,
	h: int,
	fallback_hex_size: float
) -> Dictionary[Vector2i, Vector2]:
	var centers: Dictionary[Vector2i, Vector2] = {}
	for row: int in range(h):
		for col: int in range(w):
			var odd_r: Vector2i = Vector2i(col, row)
			var axial: Vector2i = HexMath.odd_r_to_axial(odd_r)
			centers[axial] = map_node.to_local(ground.to_global(ground.map_to_local(odd_r))) if ground != null else HexMath.axial_to_world(axial, fallback_hex_size)
	return centers

