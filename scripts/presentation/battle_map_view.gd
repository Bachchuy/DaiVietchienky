class_name BattleMapView
extends Node2D

signal hex_selected(axial: Vector2i, unit: BattleUnit)

const WORLD_LAYER_SPECS: Array[Dictionary] = [
	{"name": "GroundLayer", "z": 0},
	{"name": "WaterAndTideLayer", "z": 2},
	{"name": "GridHexLayer", "z": 4},
	{"name": "FactionBorderLayer", "z": 6},
	{"name": "ReachableAreaLayer", "z": 12},
	{"name": "AttackableAreaLayer", "z": 14},
	{"name": "SkillAreaLayer", "z": 16},
	{"name": "SelectionAndAimLayer", "z": 18},
	{"name": "BuildingAndFortLayer", "z": 28},
	{"name": "UnitBaseAuraLayer", "z": 32},
	{"name": "UnitModelLayer", "z": 36},
	{"name": "StrategicTokenLayer", "z": 38},
	{"name": "MapEffectLayer", "z": 42},
	{"name": "FogOfWarLayer", "z": 48},
	{"name": "WorldSpaceUnitHudAndTextLayer", "z": 55},
]

@export var hex_size: float = HexMath.DEFAULT_HEX_SIZE

var _map_state: BattleMapState = null
var _navigator: HexGridNavigator = null
var _selected_hex: Vector2i = Vector2i(-9999, -9999)
var _has_selection: bool = false
var _selected_unit: BattleUnit = null
var _reachable_hexes: Dictionary[Vector2i, int] = {}
var _attackable_hexes: Array[Vector2i] = []
var _skill_hexes: Array[Vector2i] = []
var _preview_path: Array[Vector2i] = []
var _key_areas: Dictionary[Vector2i, int] = {}
var _strategic_lod: bool = false

var _layers: Dictionary[String, Node2D] = {}
var _hud_canvas_layer: CanvasLayer = null
var _hex_corner_offsets: PackedVector2Array = PackedVector2Array()
var _inner_corner_offsets: PackedVector2Array = PackedVector2Array()
var _branch_icons: Dictionary[int, Texture2D] = {}


class MapCanvasDrawer extends Node2D:
	var owner_view: BattleMapView = null
	var layer_id: String = ""

	func _init(view_ref: BattleMapView, id_name: String, z_val: int) -> void:
		owner_view = view_ref
		layer_id = id_name
		name = id_name
		z_index = z_val
		z_as_relative = false

	func _draw() -> void:
		if owner_view != null:
			owner_view._draw_world_layer(self, layer_id)


func _init() -> void:
	_rebuild_hex_geometry_cache()
	_ensure_layers_created()


func _ready() -> void:
	_ensure_layers_created()
	_load_clean_icons()
	refresh_all_layers()


func _ensure_layers_created() -> void:
	if not _layers.is_empty():
		return
	for spec: Dictionary in WORLD_LAYER_SPECS:
		var l_name: String = str(spec["name"])
		var l_z: int = int(spec["z"])
		var drawer := MapCanvasDrawer.new(self, l_name, l_z)
		if l_name == "StrategicTokenLayer":
			drawer.visible = false
		add_child(drawer)
		_layers[l_name] = drawer

	_hud_canvas_layer = CanvasLayer.new()
	_hud_canvas_layer.name = "ScreenHudCanvasLayer"
	_hud_canvas_layer.layer = 10
	add_child(_hud_canvas_layer)


func _load_clean_icons() -> void:
	var icon_map: Dictionary[int, String] = {
		int(BattleUnit.CommandBranch.INFANTRY): "res://assets_clean/icons/token_infantry.svg",
		int(BattleUnit.CommandBranch.ARCHER): "res://assets_clean/icons/token_archer.svg",
		int(BattleUnit.CommandBranch.CAVALRY): "res://assets_clean/icons/token_cavalry.svg",
		int(BattleUnit.CommandBranch.SIEGE): "res://assets_clean/icons/token_archer.svg",
		int(BattleUnit.CommandBranch.NAVAL_LIGHT): "res://assets_clean/icons/token_naval.svg",
		int(BattleUnit.CommandBranch.NAVAL_HEAVY): "res://assets_clean/icons/token_naval.svg",
	}
	for branch_key: int in icon_map.keys():
		var path: String = icon_map[branch_key]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				_branch_icons[branch_key] = tex


func _rebuild_hex_geometry_cache() -> void:
	_hex_corner_offsets = HexMath.get_hex_corners(Vector2.ZERO, hex_size)
	_inner_corner_offsets = HexMath.get_hex_corners(Vector2.ZERO, hex_size * 0.88)


func bind_battle_state(map_state: BattleMapState, navigator: HexGridNavigator) -> void:
	_map_state = map_state
	_navigator = navigator
	_key_areas.clear()
	clear_selection()
	refresh_all_layers()


func clear_key_areas() -> void:
	_key_areas.clear()
	_queue_layer_redraw("FactionBorderLayer")
	_queue_layer_redraw("BuildingAndFortLayer")


func set_key_area(axial: Vector2i, faction_id: int) -> void:
	_key_areas[axial] = faction_id
	_queue_layer_redraw("FactionBorderLayer")
	_queue_layer_redraw("BuildingAndFortLayer")


func get_screen_hud_layer() -> CanvasLayer:
	return _hud_canvas_layer


func set_strategic_lod(use_tokens: bool) -> void:
	_strategic_lod = use_tokens
	if _layers.has("UnitModelLayer"):
		_layers["UnitModelLayer"].visible = not use_tokens
	if _layers.has("StrategicTokenLayer"):
		_layers["StrategicTokenLayer"].visible = use_tokens
	if _layers.has("WorldSpaceUnitHudAndTextLayer"):
		_layers["WorldSpaceUnitHudAndTextLayer"].queue_redraw()


func is_strategic_lod() -> bool:
	return _strategic_lod


func select_hex(axial: Vector2i) -> void:
	if _map_state == null or _navigator == null or not _map_state.is_valid_hex(axial):
		clear_selection()
		return

	_selected_hex = axial
	_has_selection = true
	_preview_path.clear()
	_selected_unit = _map_state.get_unit_at(axial)

	if _selected_unit != null:
		_reachable_hexes = _navigator.get_reachable_hexes(_map_state, _selected_unit)
		var atk_set: Dictionary[Vector2i, bool] = {}
		for h: Vector2i in _navigator.get_attackable_hexes(_map_state, _selected_unit, _selected_unit.hex_position):
			var occ: BattleUnit = _map_state.get_unit_at(h)
			var is_enemy_here: bool = (occ != null and _map_state.is_hostile(_selected_unit.faction_id, occ.faction_id))
			if is_enemy_here or not _reachable_hexes.has(h):
				atk_set[h] = true
		for eh: Vector2i in _navigator.get_engageable_enemy_hexes(_map_state, _selected_unit, _reachable_hexes):
			atk_set[eh] = true
		_attackable_hexes.clear()
		for k: Vector2i in atk_set.keys():
			_attackable_hexes.append(k)
	else:
		_reachable_hexes.clear()
		_attackable_hexes.clear()

	_refresh_overlay_layers()
	hex_selected.emit(axial, _selected_unit)


func preview_path_to(target_axial: Vector2i) -> void:
	if _map_state == null or _navigator == null or _selected_unit == null:
		_preview_path.clear()
	elif _reachable_hexes.has(target_axial):
		_preview_path = _navigator.find_path(_map_state, _selected_unit, target_axial)
	else:
		_preview_path.clear()
	_queue_layer_redraw("SelectionAndAimLayer")


func clear_selection() -> void:
	_has_selection = false
	_selected_unit = null
	_reachable_hexes.clear()
	_attackable_hexes.clear()
	_skill_hexes.clear()
	_preview_path.clear()
	_refresh_overlay_layers()


func get_selected_unit() -> BattleUnit:
	return _selected_unit


func get_selected_hex() -> Vector2i:
	return _selected_hex


func has_selected_hex() -> bool:
	return _has_selection


func get_reachable_overlay_hexes() -> Dictionary[Vector2i, int]:
	return _reachable_hexes


func get_attackable_overlay_hexes() -> Array[Vector2i]:
	return _attackable_hexes


func get_preview_path() -> Array[Vector2i]:
	return _preview_path


func refresh_all_layers() -> void:
	_rebuild_hex_geometry_cache()
	for drawer: Node2D in _layers.values():
		drawer.queue_redraw()


func refresh_units() -> void:
	_queue_layer_redraw("UnitBaseAuraLayer")
	_queue_layer_redraw("UnitModelLayer")
	_queue_layer_redraw("StrategicTokenLayer")
	_queue_layer_redraw("WorldSpaceUnitHudAndTextLayer")


func _refresh_overlay_layers() -> void:
	_queue_layer_redraw("ReachableAreaLayer")
	_queue_layer_redraw("AttackableAreaLayer")
	_queue_layer_redraw("SkillAreaLayer")
	_queue_layer_redraw("SelectionAndAimLayer")


func _queue_layer_redraw(layer_name: String) -> void:
	if _layers.has(layer_name):
		_layers[layer_name].queue_redraw()


func _append_batched_hex(
	points: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	center: Vector2,
	col: Color,
	inner: bool = false
) -> void:
	var src: PackedVector2Array = _inner_corner_offsets if inner else _hex_corner_offsets
	var base_idx: int = points.size()
	for i: int in range(6):
		points.append(center + src[i])
		colors.append(col)
	# 4 fan triangles per convex hexagon -> 1 single GPU draw call for hundreds of hexes!
	indices.append_array([
		base_idx, base_idx + 1, base_idx + 2,
		base_idx, base_idx + 2, base_idx + 3,
		base_idx, base_idx + 3, base_idx + 4,
		base_idx, base_idx + 4, base_idx + 5,
	])


func _append_batched_hex_rim(
	segments: PackedVector2Array,
	center: Vector2,
	inner: bool = false
) -> void:
	var src: PackedVector2Array = _inner_corner_offsets if inner else _hex_corner_offsets
	for i: int in range(6):
		segments.append(center + src[i])
		segments.append(center + src[(i + 1) % 6])


func _flush_batched_triangles(
	canvas: Node2D,
	points: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if points.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		canvas.get_canvas_item(),
		indices,
		points,
		colors
	)


func _hex_closed_loop_at(center: Vector2, inner: bool = false) -> PackedVector2Array:
	var src: PackedVector2Array = _inner_corner_offsets if inner else _hex_corner_offsets
	var pts := PackedVector2Array()
	pts.resize(7)
	for i: int in range(6):
		pts[i] = center + src[i]
	pts[6] = center + src[0]
	return pts


func _draw_world_layer(canvas: Node2D, layer_id: String) -> void:
	if _map_state == null:
		return

	match layer_id:
		"GroundLayer":
			_draw_ground_layer(canvas)
		"WaterAndTideLayer":
			_draw_water_layer(canvas)
		"GridHexLayer":
			_draw_grid_layer(canvas)
		"FactionBorderLayer":
			_draw_faction_border_layer(canvas)
		"ReachableAreaLayer":
			_draw_reachable_layer(canvas)
		"AttackableAreaLayer":
			_draw_attackable_layer(canvas)
		"SelectionAndAimLayer":
			_draw_selection_and_path_layer(canvas)
		"BuildingAndFortLayer":
			_draw_building_layer(canvas)
		"UnitBaseAuraLayer":
			_draw_unit_aura_layer(canvas)
		"UnitModelLayer":
			_draw_unit_model_layer(canvas)
		"StrategicTokenLayer":
			_draw_strategic_token_layer(canvas)
		"WorldSpaceUnitHudAndTextLayer":
			_draw_unit_hud_layer(canvas)
		_:
			pass


func _draw_ground_layer(canvas: Node2D) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()
	var hill_lines := PackedVector2Array()
	var road_dots := PackedVector2Array()

	for row: int in range(_map_state.height):
		for col: int in range(_map_state.width):
			var axial: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			var terrain: BattleMapState.TerrainType = _map_state.get_terrain(axial)
			if (
				terrain == BattleMapState.TerrainType.SHALLOW_RIVER
				or terrain == BattleMapState.TerrainType.DEEP_WATER
				or terrain == BattleMapState.TerrainType.STAKED_WATER
			):
				continue
			var center: Vector2 = HexMath.axial_to_world(axial, hex_size)
			_append_batched_hex(pts, cols, idxs, center, _terrain_color(terrain), false)

			if terrain == BattleMapState.TerrainType.FOREST:
				for offset: Vector2 in [Vector2(-10.0, 4.0), Vector2(10.0, 6.0), Vector2(0.0, -8.0)]:
					var p: Vector2 = center + offset
					var b: int = pts.size()
					pts.append(p + Vector2(0.0, -11.0))
					pts.append(p + Vector2(9.0, 6.0))
					pts.append(p + Vector2(-9.0, 6.0))
					var tree_col := Color(0.14, 0.36, 0.18, 0.88)
					cols.append(tree_col)
					cols.append(tree_col)
					cols.append(tree_col)
					idxs.append_array([b, b + 1, b + 2])
			elif terrain == BattleMapState.TerrainType.HILLS:
				var p0: Vector2 = center + Vector2(-18.0, 10.0)
				var p1: Vector2 = center + Vector2(-2.0, -12.0)
				var p2: Vector2 = center + Vector2(8.0, -2.0)
				var p3: Vector2 = center + Vector2(18.0, 10.0)
				hill_lines.append_array([p0, p1, p1, p2, p2, p3])
			elif terrain == BattleMapState.TerrainType.ROAD_PORT:
				road_dots.append(center + Vector2(-8.0, 0.0))
				road_dots.append(center + Vector2(8.0, 0.0))

	_flush_batched_triangles(canvas, pts, cols, idxs)
	if not hill_lines.is_empty():
		canvas.draw_multiline(hill_lines, Color(0.36, 0.28, 0.18, 0.85), 3.0)
	if not road_dots.is_empty():
		canvas.draw_multiline(road_dots, Color(0.88, 0.80, 0.62, 0.70), 4.0)


func _draw_water_layer(canvas: Node2D) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()
	var wave_lines := PackedVector2Array()
	var stake_lines := PackedVector2Array()

	for row: int in range(_map_state.height):
		for col: int in range(_map_state.width):
			var axial: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			var terrain: BattleMapState.TerrainType = _map_state.get_terrain(axial)
			if (
				terrain != BattleMapState.TerrainType.SHALLOW_RIVER
				and terrain != BattleMapState.TerrainType.DEEP_WATER
				and terrain != BattleMapState.TerrainType.STAKED_WATER
			):
				continue
			var center: Vector2 = HexMath.axial_to_world(axial, hex_size)
			_append_batched_hex(pts, cols, idxs, center, _terrain_color(terrain), false)
			wave_lines.append(center + Vector2(-16.0, -6.0))
			wave_lines.append(center + Vector2(16.0, -6.0))
			wave_lines.append(center + Vector2(-12.0, 8.0))
			wave_lines.append(center + Vector2(14.0, 8.0))
			if terrain == BattleMapState.TerrainType.STAKED_WATER:
				for sx: float in [-12.0, 0.0, 12.0]:
					stake_lines.append(center + Vector2(sx, 10.0))
					stake_lines.append(center + Vector2(sx, -12.0))

	_flush_batched_triangles(canvas, pts, cols, idxs)
	if not wave_lines.is_empty():
		canvas.draw_multiline(wave_lines, Color(0.75, 0.90, 0.98, 0.34), 2.0)
	if not stake_lines.is_empty():
		canvas.draw_multiline(stake_lines, Color(0.38, 0.21, 0.10), 4.2)


func _draw_grid_layer(canvas: Node2D) -> void:
	var segments := PackedVector2Array()
	for row: int in range(_map_state.height):
		for col: int in range(_map_state.width):
			var axial: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			var center: Vector2 = HexMath.axial_to_world(axial, hex_size)
			_append_batched_hex_rim(segments, center, false)
	if not segments.is_empty():
		canvas.draw_multiline(segments, Color(0.16, 0.13, 0.09, 0.42), 1.4)


func _draw_faction_border_layer(canvas: Node2D) -> void:
	for fort_hex: Vector2i in _map_state.get_fort_hexes():
		var owner_f: int = _map_state.get_fort_owner(fort_hex)
		if owner_f != 0:
			var c: Vector2 = HexMath.axial_to_world(fort_hex, hex_size)
			canvas.draw_polyline(_hex_closed_loop_at(c, true), _faction_primary_color(owner_f), 3.0)

	for area_hex: Vector2i in _key_areas.keys():
		if not _map_state.is_valid_hex(area_hex):
			continue
		var f_id: int = _key_areas[area_hex]
		var center: Vector2 = HexMath.axial_to_world(area_hex, hex_size)
		canvas.draw_polyline(_hex_closed_loop_at(center, true), _faction_primary_color(f_id), 3.5)


func _draw_reachable_layer(canvas: Node2D) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()
	var rims := PackedVector2Array()
	var fill := Color(0.16, 0.58, 0.98, 0.30)

	for hex: Vector2i in _reachable_hexes.keys():
		if _selected_unit != null and hex == _selected_unit.hex_position:
			continue
		var center: Vector2 = HexMath.axial_to_world(hex, hex_size)
		_append_batched_hex(pts, cols, idxs, center, fill, true)
		_append_batched_hex_rim(rims, center, true)

	_flush_batched_triangles(canvas, pts, cols, idxs)
	if not rims.is_empty():
		canvas.draw_multiline(rims, Color(0.45, 0.85, 1.0, 0.88), 2.0)


func _draw_attackable_layer(canvas: Node2D) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()
	var rims := PackedVector2Array()
	var fill := Color(0.94, 0.22, 0.18, 0.34)

	for hex: Vector2i in _attackable_hexes:
		var center: Vector2 = HexMath.axial_to_world(hex, hex_size)
		_append_batched_hex(pts, cols, idxs, center, fill, true)
		_append_batched_hex_rim(rims, center, true)

	_flush_batched_triangles(canvas, pts, cols, idxs)
	if not rims.is_empty():
		canvas.draw_multiline(rims, Color(1.0, 0.44, 0.34, 0.94), 2.4)


func _draw_selection_and_path_layer(canvas: Node2D) -> void:
	if _has_selection and _map_state.is_valid_hex(_selected_hex):
		var sel_center: Vector2 = HexMath.axial_to_world(_selected_hex, hex_size)
		canvas.draw_polyline(_hex_closed_loop_at(sel_center, true), Color(1.0, 0.86, 0.28, 0.98), 3.5)

	if _preview_path.size() >= 2:
		var pts := PackedVector2Array()
		pts.resize(_preview_path.size())
		for i: int in range(_preview_path.size()):
			pts[i] = HexMath.axial_to_world(_preview_path[i], hex_size)
		canvas.draw_polyline(pts, Color(1.0, 0.92, 0.42, 0.95), 4.0)
		var end_pt: Vector2 = pts[pts.size() - 1]
		canvas.draw_circle(end_pt, 7.0, Color(1.0, 0.88, 0.25))


func _draw_building_layer(canvas: Node2D) -> void:
	for fort_hex: Vector2i in _map_state.get_fort_hexes():
		var center: Vector2 = HexMath.axial_to_world(fort_hex, hex_size)
		var rect := Rect2(center - Vector2(16.0, 14.0), Vector2(32.0, 26.0))
		canvas.draw_rect(rect, Color(0.46, 0.41, 0.35), true)
		canvas.draw_rect(rect, Color(0.20, 0.16, 0.12), false, 2.0)

	for area_hex: Vector2i in _key_areas.keys():
		if not _map_state.is_valid_hex(area_hex):
			continue
		var center: Vector2 = HexMath.axial_to_world(area_hex, hex_size)
		canvas.draw_rect(Rect2(center - Vector2(12.0, 12.0), Vector2(24.0, 22.0)), Color(0.68, 0.46, 0.22), true)
		canvas.draw_circle(center + Vector2(0.0, -16.0), 5.5, Color(1.0, 0.78, 0.22))


func _draw_unit_aura_layer(canvas: Node2D) -> void:
	for unit: BattleUnit in _map_state.get_all_units():
		var center: Vector2 = HexMath.axial_to_world(unit.hex_position, hex_size)
		canvas.draw_circle(center + Vector2(0.0, 3.0), hex_size * 0.42, Color(0.05, 0.05, 0.05, 0.36))


func _draw_unit_model_layer(canvas: Node2D) -> void:
	var units: Array[BattleUnit] = _map_state.get_all_units()
	# Pass 1: all untextured circles/pips together -> batched into 1 untextured draw call!
	for unit: BattleUnit in units:
		var center: Vector2 = HexMath.axial_to_world(unit.hex_position, hex_size)
		var f_col: Color = _faction_primary_color(unit.faction_id)
		var trim_col: Color = _faction_trim_color(unit.faction_id)
		if unit.state.has_acted:
			f_col = f_col.darkened(0.42)
			trim_col = trim_col.darkened(0.32)
		canvas.draw_circle(center, hex_size * 0.40, trim_col)
		canvas.draw_circle(center, hex_size * 0.35, f_col)
		var stack_n: int = unit.get_active_banners()
		for s_idx: int in range(stack_n):
			var px: float = (float(s_idx) - float(stack_n - 1) * 0.5) * 9.0
			canvas.draw_circle(center + Vector2(px, hex_size * 0.25), 2.8, trim_col)

	# Pass 2: group textured glyphs by texture -> max 4 draw calls total!
	for branch_key: int in _branch_icons.keys():
		var tex: Texture2D = _branch_icons[branch_key]
		for unit: BattleUnit in units:
			if int(unit.command_branch) == branch_key:
				var center: Vector2 = HexMath.axial_to_world(unit.hex_position, hex_size)
				var icon_size := Vector2(28.0, 28.0)
				canvas.draw_texture_rect(tex, Rect2(center - icon_size * 0.5, icon_size), false)


func _draw_strategic_token_layer(canvas: Node2D) -> void:
	var units: Array[BattleUnit] = _map_state.get_all_units()
	# Pass 1: untextured token plaques batched together
	for unit: BattleUnit in units:
		var center: Vector2 = HexMath.axial_to_world(unit.hex_position, hex_size)
		var f_col: Color = _faction_primary_color(unit.faction_id)
		var trim_col: Color = _faction_trim_color(unit.faction_id)
		canvas.draw_rect(Rect2(center - Vector2(26.0, 22.0), Vector2(52.0, 44.0)), trim_col, true)
		canvas.draw_rect(Rect2(center - Vector2(23.0, 19.0), Vector2(46.0, 38.0)), f_col, true)

	# Pass 2: group icons by texture -> max 4 draw calls total!
	for branch_key: int in _branch_icons.keys():
		var tex: Texture2D = _branch_icons[branch_key]
		for unit: BattleUnit in units:
			if int(unit.command_branch) == branch_key:
				var center: Vector2 = HexMath.axial_to_world(unit.hex_position, hex_size)
				canvas.draw_texture_rect(tex, Rect2(center - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), false)


func _draw_unit_hud_layer(canvas: Node2D) -> void:
	if _strategic_lod:
		return
	for unit: BattleUnit in _map_state.get_all_units():
		var center: Vector2 = HexMath.axial_to_world(unit.hex_position, hex_size)
		var bar_w: float = 42.0
		var bar_h: float = 6.0
		var top_left: Vector2 = center + Vector2(-bar_w * 0.5, -hex_size * 0.58)
		var ratio: float = clampf(
			float(unit.state.current_hp) / maxf(1.0, float(unit.state.max_hp)),
			0.0,
			1.0
		)
		canvas.draw_rect(Rect2(top_left - Vector2(1.0, 1.0), Vector2(bar_w + 2.0, bar_h + 2.0)), Color(0.95, 0.90, 0.78, 0.85), true)
		canvas.draw_rect(Rect2(top_left, Vector2(bar_w, bar_h)), Color(0.08, 0.08, 0.10, 0.92), true)
		var is_ally: bool = (
			_map_state.is_allied(1, unit.faction_id)
			if _map_state != null
			else (unit.faction_id == 1)
		)
		var hp_col := Color(0.24, 0.86, 0.38) if is_ally else Color(0.95, 0.34, 0.28)
		canvas.draw_rect(Rect2(top_left, Vector2(bar_w * ratio, bar_h)), hp_col, true)
		canvas.draw_circle(top_left + Vector2(bar_w + 6.0, bar_h * 0.5), 3.6, _morale_color(unit.state.morale))


func _terrain_color(terrain: BattleMapState.TerrainType) -> Color:
	match terrain:
		BattleMapState.TerrainType.PLAINS:
			return Color(0.56, 0.66, 0.42)
		BattleMapState.TerrainType.FOREST:
			return Color(0.28, 0.48, 0.27)
		BattleMapState.TerrainType.HILLS:
			return Color(0.62, 0.54, 0.38)
		BattleMapState.TerrainType.SWAMP:
			return Color(0.39, 0.44, 0.30)
		BattleMapState.TerrainType.SHALLOW_RIVER:
			return Color(0.26, 0.58, 0.68)
		BattleMapState.TerrainType.DEEP_WATER:
			return Color(0.14, 0.36, 0.52)
		BattleMapState.TerrainType.FORT:
			return Color(0.58, 0.54, 0.48)
		BattleMapState.TerrainType.ROAD_PORT:
			return Color(0.74, 0.66, 0.48)
		BattleMapState.TerrainType.STAKED_WATER:
			return Color(0.18, 0.32, 0.44)
		_:
			return Color(0.5, 0.5, 0.5)


func _faction_primary_color(faction_id: int) -> Color:
	if faction_id == 1:
		return Color(0.76, 0.16, 0.16)
	if _map_state != null and _map_state.is_hostile(1, faction_id):
		return Color(0.18, 0.32, 0.58)
	if faction_id == 2:
		return Color(0.20, 0.58, 0.32)
	if faction_id == 3:
		return Color(0.18, 0.32, 0.58)
	return Color(0.45, 0.45, 0.45)


func _faction_trim_color(faction_id: int) -> Color:
	if faction_id == 1:
		return Color(0.96, 0.80, 0.32)
	return Color(0.82, 0.88, 0.95)


func _morale_color(morale: UnitCombatState.MoraleLevel) -> Color:
	match morale:
		UnitCombatState.MoraleLevel.HIGH:
			return Color(1.0, 0.84, 0.22)
		UnitCombatState.MoraleLevel.NORMAL:
			return Color(0.32, 0.88, 0.48)
		UnitCombatState.MoraleLevel.LOW:
			return Color(0.95, 0.58, 0.18)
		UnitCombatState.MoraleLevel.CHAOS:
			return Color(0.86, 0.20, 0.82)
		_:
			return Color.WHITE
