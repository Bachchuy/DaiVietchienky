class_name BattleMap
extends Node2D
## Presentation map view orchestrating StageMapTool (TileMapLayer), HexOverlayLayer, Buildings, and UnitViews (`res://game/battle/map/`).

signal hex_clicked(axial: Vector2i)
signal hex_hovered(axial: Vector2i)
signal hex_selected(axial: Vector2i, unit: BattleUnit)
signal unit_selected(unit: BattleUnit)
signal selection_cleared()

const UNIT_VIEW_PATH: String = "res://game/battle/units/unit_view.tscn"

@export_group("Scene Layers")
@export var stage_map_slot: Node2D
@export var stage_map: StageMapTool
@export var overlay_layer: HexOverlayLayer
@export var buildings_layer: Node2D
@export var units_layer: Node2D
@export var effects_layer: Node2D
@export var unit_view_scene: PackedScene

var hex_size: float = HexMath.DEFAULT_HEX_SIZE

var _session: BattleSession = null
var _map_state: BattleMapState = null
var _navigator: HexGridNavigator = null
var _registry: DataRegistry = null
var _stage_def: StageDef = null

var _unit_views: Dictionary[int, UnitView] = {}
var _last_unit_hexes: Dictionary[int, Vector2i] = {}
var _fort_signature: String = ""
var _geometry_sig: String = ""
var _axial_centers: Dictionary[Vector2i, Vector2] = {}
var _is_strategic_lod: bool = false

var _selected_unit: BattleUnit = null
var _selected_hex: Vector2i = Vector2i(-999, -999)
var _hover_hex: Vector2i = Vector2i(-999, -999)
var _reachable_hexes: Dictionary[Vector2i, int] = {}
var _attackable_hexes: Array[Vector2i] = []
var _skill_hexes: Array[Vector2i] = []
var _skill_aoe_hexes: Array[Vector2i] = []
var _skill_is_heal: bool = false
var _preview_path: Array[Vector2i] = []


func _ready() -> void:
	_ensure_nodes()
	if stage_map != null:
		stage_map.set_editor_markers_visible(false)
	_sync_terrain_grid_and_markers()


func bind_session(session: BattleSession, p_navigator: HexGridNavigator = null) -> void:
	_set_session_signals(false)
	_session = session
	if _session == null:
		return
	_stage_def = _session.stage_def
	_registry = _session.registry
	_ensure_stage_map_scene(_stage_def)
	var ms: BattleMapState = _session.get_map_state()
	var nav: HexGridNavigator = p_navigator if p_navigator != null else _session.get_navigator()
	if ms != null:
		bind_battle_state(ms, nav, _registry, _stage_def)
	_set_session_signals(true)

func bind_battle_state(
	p_map_state: BattleMapState,
	p_navigator: HexGridNavigator = null,
	p_registry: DataRegistry = null,
	p_stage_def: StageDef = null
) -> void:
	_ensure_nodes()
	_map_state = p_map_state
	_navigator = p_navigator if p_navigator != null else HexGridNavigator.new()
	if p_registry != null:
		_registry = p_registry
	if p_stage_def != null:
		_stage_def = p_stage_def
		_ensure_stage_map_scene(_stage_def)
	if stage_map != null:
		stage_map.set_editor_markers_visible(false)
	sync_all_from_state()

func sync_all_from_state() -> void:
	if _map_state == null:
		return
	_sync_terrain_grid_and_markers()
	_sync_fort_sprites()
	_sync_unit_views()

func axial_to_local_pos(axial: Vector2i) -> Vector2:
	if _axial_centers.has(axial):
		return _axial_centers[axial]
	var ground: TileMapLayer = get_ground_layer()
	if ground != null:
		return to_local(ground.to_global(ground.map_to_local(HexMath.axial_to_odd_r(axial))))
	return HexMath.axial_to_world(axial, hex_size)

func axial_to_world(axial: Vector2i) -> Vector2:
	var local_pt: Vector2 = axial_to_local_pos(axial)
	return to_global(local_pt) if is_inside_tree() else local_pt

func world_to_axial(world_pos: Vector2) -> Vector2i:
	var ground: TileMapLayer = get_ground_layer()
	if ground != null:
		var ground_local: Vector2 = ground.to_local(world_pos) if is_inside_tree() else world_pos
		return HexMath.odd_r_to_axial(ground.local_to_map(ground_local))
	return HexMath.world_to_axial(world_pos, hex_size)

func get_map_world_bounds() -> Rect2:
	return HexOverlayLayer.compute_world_bounds(_axial_centers, _get_scaled_cell_size(), _map_state, hex_size)

func set_strategic_lod(enabled: bool) -> void:
	_is_strategic_lod = enabled
	for uv: UnitView in _unit_views.values():
		if is_instance_valid(uv):
			uv.set_strategic_lod(enabled)

func is_strategic_lod() -> bool: return _is_strategic_lod

func select_hex(axial: Vector2i) -> void:
	hex_clicked.emit(axial)
	if _map_state == null or not _map_state.is_valid_hex(axial):
		clear_selection()
		return
	_selected_hex = axial
	var unit: BattleUnit = _map_state.get_unit_at(axial)
	if unit == null or not unit.state.is_alive():
		_apply_unit_selection(null)
		_reachable_hexes.clear()
		_attackable_hexes.clear()
		_preview_path.clear()
		_sync_overlay_selection()
		hex_selected.emit(axial, null)
		return
	_apply_unit_selection(unit)
	if _navigator != null:
		_reachable_hexes = _navigator.get_reachable_hexes(_map_state, unit)
		_attackable_hexes = HexOverlayLayer.collect_hostile_attack_hexes(_map_state, _navigator, unit)
	_preview_path.clear()
	_sync_overlay_selection()
	unit_selected.emit(unit)
	hex_selected.emit(axial, unit)

func clear_selection() -> void:
	_apply_unit_selection(null)
	_selected_hex = Vector2i(-999, -999)
	_reachable_hexes.clear()
	_attackable_hexes.clear()
	_skill_hexes.clear()
	_skill_aoe_hexes.clear()
	_preview_path.clear()
	_sync_overlay_selection()
	selection_cleared.emit()

func has_selected_hex() -> bool: return _selected_hex.x > -900

func clear_move_and_attack_overlays() -> void:
	_reachable_hexes.clear()
	_attackable_hexes.clear()
	_preview_path.clear()
	_sync_overlay_selection()

func set_post_move_overlays(unit: BattleUnit) -> void:
	_reachable_hexes.clear()
	_preview_path.clear()
	_skill_hexes.clear()
	_skill_aoe_hexes.clear()
	if unit == null or not unit.state.is_alive():
		clear_selection()
		return
	_selected_hex = unit.hex_position
	_apply_unit_selection(unit)
	_attackable_hexes = HexOverlayLayer.collect_hostile_attack_hexes(_map_state, _navigator, unit)
	_sync_overlay_selection()

func set_hover_hex(axial: Vector2i) -> void:
	if _hover_hex == axial:
		return
	_hover_hex = axial
	hex_hovered.emit(axial)
	_sync_overlay_selection()

func preview_path_to(target_hex: Vector2i) -> void:
	_preview_path.clear()
	if _selected_unit != null and _map_state != null and _navigator != null:
		if _reachable_hexes.has(target_hex):
			_preview_path = _navigator.find_path(_map_state, _selected_unit, target_hex)
	_sync_overlay_selection()

func set_skill_area_hexes(range_hexes: Array[Vector2i], aoe_hexes: Array[Vector2i] = [], is_heal: bool = false) -> void:
	_skill_hexes = range_hexes.duplicate()
	_skill_aoe_hexes = aoe_hexes.duplicate()
	_skill_is_heal = is_heal
	_sync_overlay_selection()

func set_skill_target_overlay(hexes: Array[Vector2i], is_heal: bool = false) -> void:
	set_skill_area_hexes(hexes, [], is_heal)

func clear_skill_area_hexes() -> void:
	_skill_hexes.clear()
	_skill_aoe_hexes.clear()
	_sync_overlay_selection()

func refresh_all_layers() -> void: sync_all_from_state()
func refresh_units() -> void: _sync_unit_views()
func get_selected_unit() -> BattleUnit: return _selected_unit
func get_reachable_overlay_hexes() -> Dictionary[Vector2i, int]: return _reachable_hexes.duplicate()
func get_attackable_overlay_hexes() -> Array[Vector2i]: return _attackable_hexes.duplicate()
func get_skill_range_hexes() -> Array[Vector2i]: return _skill_hexes.duplicate()
func get_skill_aoe_hexes() -> Array[Vector2i]: return _skill_aoe_hexes.duplicate()
func get_preview_path() -> Array[Vector2i]: return _preview_path.duplicate()
func get_unit_view(unit_id: int) -> UnitView: return _unit_views.get(unit_id, null) as UnitView
func get_unit_view_count() -> int: return _unit_views.size()
func get_ground_layer() -> TileMapLayer: return stage_map.ground_layer if stage_map != null else null

func get_layer_node(layer_name: String) -> Node2D:
	match layer_name:
		"MapEffectLayer", "EffectsLayer", "WorldSpaceUnitHudAndTextLayer": return effects_layer
		"WaterAndTideLayer", "GroundLayer": return get_ground_layer()
		"UnitsLayer": return units_layer
		"BuildingsLayer": return buildings_layer
		"HexOverlayLayer": return overlay_layer
		_: return get_node_or_null(layer_name) as Node2D

func reset_for_procedural_map() -> void:
	_geometry_sig = ""
	_fort_signature = ""
	if stage_map != null:
		stage_map.ensure_layers_ready()
		stage_map.fort_owners.clear()
		if stage_map.ground_layer != null: stage_map.ground_layer.clear()
		if stage_map.structure_layer != null: stage_map.structure_layer.clear()


func _ensure_stage_map_scene(stage: StageDef) -> void:
	if stage == null or stage.map_scene == null:
		return
	if stage_map != null and stage_map.scene_file_path == stage.map_scene.resource_path:
		return
	if stage_map_slot == null:
		return
	for child: Node in stage_map_slot.get_children():
		stage_map_slot.remove_child(child)
		child.queue_free()
	var instance: Node = stage.map_scene.instantiate()
	stage_map_slot.add_child(instance)
	stage_map = instance as StageMapTool
	if stage_map != null:
		stage_map.set_editor_markers_visible(false)


func _sync_terrain_grid_and_markers() -> void:
	if stage_map != null and _map_state != null:
		stage_map.sync_cells_from_map_state(_map_state)
	var ground: TileMapLayer = get_ground_layer()
	var w: int = _map_state.width if _map_state != null else (stage_map.map_width if stage_map != null else 12)
	var h: int = _map_state.height if _map_state != null else (stage_map.map_height if stage_map != null else 10)
	var next_geo: String = "%dx%d:%d" % [w, h, stage_map.get_instance_id() if stage_map != null else get_instance_id()]
	if next_geo != _geometry_sig:
		_axial_centers = HexOverlayLayer.build_axial_centers(self, ground, w, h, hex_size)
		_geometry_sig = next_geo
		if overlay_layer != null:
			overlay_layer.configure_geometry(_axial_centers, _get_scaled_cell_size())
	if overlay_layer != null and _map_state != null:
		overlay_layer.set_environment_markers(HexOverlayLayer.collect_staked_hexes(_map_state), HexOverlayLayer.collect_objectives(_stage_def))

func _sync_fort_sprites() -> void:
	_fort_signature = StageMapTool.sync_fort_sprites(buildings_layer, _map_state, _axial_centers, _fort_signature)

func _sync_unit_views() -> void:
	if units_layer == null or _map_state == null:
		return
	var scene: PackedScene = unit_view_scene if unit_view_scene != null else ResourceLoader.load(UNIT_VIEW_PATH) as PackedScene
	if scene == null:
		return

	var seen_ids: Dictionary[int, bool] = {}
	for u: BattleUnit in _map_state.get_all_units():
		if u == null or not u.state.is_alive():
			continue
		seen_ids[u.unit_id] = true
		var uv: UnitView = _unit_views.get(u.unit_id, null) as UnitView
		if uv == null or not is_instance_valid(uv):
			uv = scene.instantiate() as UnitView
			uv.name = "UnitView_%d" % u.unit_id
			units_layer.add_child(uv)
			var troop_def: TroopDef = _registry.get_troop(u.troop_id) if _registry != null else null
			uv.bind_unit(u, troop_def)
			uv.set_strategic_lod(_is_strategic_lod)
			uv.position = axial_to_local_pos(u.hex_position)
			_unit_views[u.unit_id] = uv
		else:
			uv.sync_from_unit(u)
			if _last_unit_hexes.get(u.unit_id, Vector2i(-999, -999)) != u.hex_position:
				uv.position = axial_to_local_pos(u.hex_position)
		_last_unit_hexes[u.unit_id] = u.hex_position
		uv.set_selected(_selected_unit != null and _selected_unit.unit_id == u.unit_id)

	var stale_ids: Array[int] = []
	for uid: int in _unit_views.keys():
		if not seen_ids.has(uid):
			stale_ids.append(uid)
	for uid: int in stale_ids:
		if is_instance_valid(_unit_views[uid]): _unit_views[uid].queue_free()
		_unit_views.erase(uid)
		_last_unit_hexes.erase(uid)

func _sync_overlay_selection() -> void:
	if overlay_layer == null:
		return
	overlay_layer.set_tactical_overlays(_reachable_hexes, _attackable_hexes, _skill_hexes, _skill_is_heal, _skill_aoe_hexes)
	overlay_layer.set_selection(_selected_hex, _hover_hex, _preview_path)

func _apply_unit_selection(unit: BattleUnit) -> void:
	for pair: Array in [[_selected_unit, false], [unit, true]]:
		var u: BattleUnit = pair[0] as BattleUnit
		if u != null and _unit_views.has(u.unit_id) and is_instance_valid(_unit_views[u.unit_id]):
			_unit_views[u.unit_id].set_selected(bool(pair[1]))
	_selected_unit = unit

func _get_scaled_cell_size() -> Vector2:
	var ground: TileMapLayer = get_ground_layer()
	if ground != null and ground.tile_set != null:
		var base_sz: Vector2 = Vector2(ground.tile_set.tile_size)
		var sc: Vector2 = ground.global_scale if is_inside_tree() else (stage_map.scale * ground.scale if stage_map != null else Vector2(2.0, 2.0))
		return Vector2(base_sz.x * absf(sc.x), base_sz.y * absf(sc.y))
	return Vector2(hex_size * 1.732, hex_size * 1.5)

func _on_session_battle_started(_stage_id: int) -> void:
	_map_state = _session.get_map_state()
	_navigator = _session.get_navigator()
	sync_all_from_state()

func _on_session_state_refreshed() -> void: sync_all_from_state()
func _on_session_event_triggered(_event_id: String, _action_type: String, _payload: Dictionary) -> void: sync_all_from_state()

func _on_session_unit_moved(unit_id: int, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	_last_unit_hexes[unit_id] = to_hex
	var uv: UnitView = get_unit_view(unit_id)
	if uv != null:
		uv.play_move_to(axial_to_local_pos(to_hex))

func _on_session_combat_resolved(attacker_id: int, defender_id: int, _report: Dictionary) -> void:
	var att_uv: UnitView = get_unit_view(attacker_id)
	var def_uv: UnitView = get_unit_view(defender_id)
	if att_uv != null and def_uv != null:
		att_uv.play_attack(def_uv.position)
	if def_uv != null:
		var def_unit: BattleUnit = _session.get_unit(defender_id) if _session != null else null
		def_uv.play_death() if (def_unit == null or not def_unit.state.is_alive()) else def_uv.play_hurt()

func _set_session_signals(connect_flag: bool) -> void:
	if _session == null:
		return
	for pair: Array in [
		[_session.battle_started, _on_session_battle_started],
		[_session.state_refreshed, _on_session_state_refreshed],
		[_session.unit_moved, _on_session_unit_moved],
		[_session.combat_resolved, _on_session_combat_resolved],
		[_session.scenario_event_triggered, _on_session_event_triggered],
	]:
		var sig: Signal = pair[0] as Signal
		var cb: Callable = pair[1] as Callable
		if connect_flag and not sig.is_connected(cb):
			sig.connect(cb)
		elif not connect_flag and sig.is_connected(cb):
			sig.disconnect(cb)
	if not connect_flag:
		_session = null

func _ensure_nodes() -> void:
	if stage_map_slot == null: stage_map_slot = get_node_or_null("StageMapSlot") as Node2D
	if stage_map == null and stage_map_slot != null and stage_map_slot.get_child_count() > 0:
		stage_map = stage_map_slot.get_child(0) as StageMapTool
	if stage_map == null: stage_map = get_node_or_null("StageMap") as StageMapTool
	if overlay_layer == null: overlay_layer = _get_or_add_child("HexOverlayLayer", 12, true) as HexOverlayLayer
	if buildings_layer == null: buildings_layer = _get_or_add_child("BuildingsLayer", 24, false)
	if units_layer == null: units_layer = _get_or_add_child("UnitsLayer", 36, false)
	if effects_layer == null: effects_layer = _get_or_add_child("EffectsLayer", 44, false)

func _get_or_add_child(node_name: String, z_val: int, is_overlay: bool) -> Node2D:
	var found: Node2D = get_node_or_null(node_name) as Node2D
	if found != null:
		return found
	var created: Node2D = HexOverlayLayer.new() if is_overlay else Node2D.new()
	created.name = node_name
	created.z_index = z_val
	add_child(created)
	return created
