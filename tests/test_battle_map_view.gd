extends "res://tests/test_case.gd"

const VIEW_PATH: String = "res://game/battle/map/battle_map.tscn"
const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const NavScript = preload("res://sim/rules/hex_grid_navigator.gd")


func _make_view() -> BattleMap:
	var packed: PackedScene = load(VIEW_PATH) as PackedScene
	assert_not_null(packed, "BattleMap scene must exist at " + VIEW_PATH)
	if packed == null:
		return null
	var node: BattleMap = packed.instantiate() as BattleMap
	add_child_autofree(node)
	return node


func test_battle_map_five_layers_structure_and_z_order() -> void:
	var view: BattleMap = _make_view()
	if view == null:
		return

	var expected_layers: Dictionary = {
		"StageMapSlot": 0,
		"HexOverlayLayer": 12,
		"BuildingsLayer": 24,
		"UnitsLayer": 36,
		"EffectsLayer": 44,
	}

	assert_eq(view.get_child_count(), 5, "BattleMap must own 5 scene render layers")
	for layer_name: String in expected_layers.keys():
		var child: Node2D = view.get_node_or_null(layer_name) as Node2D
		assert_not_null(child, "Missing BattleMap layer: " + layer_name)
		if child != null:
			assert_eq(child.z_index, int(expected_layers[layer_name]), "Wrong z_index on " + layer_name)


func test_select_unit_populates_reachable_blue_and_attackable_red_overlays() -> void:
	var view: BattleMap = _make_view()
	if view == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var nav := NavScript.new()

	var archer := UnitScript.new()
	archer.unit_id = 1
	archer.faction_id = 1
	archer.display_name = "Cung Nỏ Đại Việt"
	archer.command_branch = UnitScript.CommandBranch.ARCHER
	archer.hex_position = HexMathScript.odd_r_to_axial(Vector2i(3, 5))
	archer.max_mp = 6
	archer.state.current_mp = 6
	archer.min_range = 1
	archer.max_range = 2
	map_state.place_unit(archer)

	var enemy := UnitScript.new()
	enemy.unit_id = 2
	enemy.faction_id = 3
	enemy.display_name = "Bộ Binh Nguyên"
	enemy.hex_position = archer.hex_position + Vector2i(2, 0)
	map_state.place_unit(enemy)

	view.reset_for_procedural_map()
	view.bind_battle_state(map_state, nav)
	view.select_hex(archer.hex_position)

	assert_eq(view.get_selected_unit(), archer)
	var expected_reach: Dictionary = nav.get_reachable_hexes(map_state, archer)
	var actual_reach: Dictionary = view.get_reachable_overlay_hexes()
	assert_eq(actual_reach.size(), expected_reach.size(), "Reachable hex count must match navigator")
	for h: Vector2i in expected_reach.keys():
		assert_has(actual_reach, h)

	var actual_atk: Array[Vector2i] = view.get_attackable_overlay_hexes()
	assert_has(actual_atk, enemy.hex_position, "Enemy in range 2 with clear LOS must appear in attackable overlay")

	var dest_hex: Vector2i = archer.hex_position + Vector2i(0, 1)
	view.preview_path_to(dest_hex)
	var preview_path: Array[Vector2i] = view.get_preview_path()
	assert_eq(preview_path.size(), 2)
	assert_eq(preview_path[1], dest_hex)

	view.clear_selection()
	assert_null(view.get_selected_unit())
	assert_eq(view.get_reachable_overlay_hexes().size(), 0)
	assert_eq(view.get_attackable_overlay_hexes().size(), 0)


func test_strategic_lod_toggle_propagates_to_unit_views() -> void:
	var view: BattleMap = _make_view()
	if view == null:
		return

	var map_state := MapStateScript.new(12, 10)
	var u := UnitScript.new()
	u.unit_id = 11
	u.faction_id = 1
	u.troop_id = 40101
	u.hex_position = HexMathScript.odd_r_to_axial(Vector2i(2, 2))
	map_state.place_unit(u)

	view.reset_for_procedural_map()
	view.bind_battle_state(map_state, NavScript.new())
	var uv: UnitView = view.get_unit_view(11)
	assert_not_null(uv)
	if uv == null:
		return
	assert_false(uv.is_strategic_lod())
	view.set_strategic_lod(true)
	assert_true(uv.is_strategic_lod(), "BattleMap must propagate strategic LOD=true to UnitViews")
	view.set_strategic_lod(false)
	assert_false(uv.is_strategic_lod(), "BattleMap must propagate strategic LOD=false to UnitViews")


func test_r3_t3_stage_10101_map_scene_loads_cells_markers_and_no_cyclic_dep() -> void:
	var stage: StageDef = ResourceLoader.load(
		"res://data/stages/10101_bach_dang/stage_10101.tres",
		"StageDef",
		ResourceLoader.CACHE_MODE_REPLACE
	) as StageDef
	assert_not_null(stage)
	assert_not_null(stage.map_scene, "stage_10101.tres must wire map_scene")
	if stage == null or stage.map_scene == null:
		return

	assert_eq(stage.map_scene.resource_path, "res://data/stages/10101_bach_dang/stage_10101_map.tscn")

	var tscn_text: String = FileAccess.get_file_as_string("res://data/stages/10101_bach_dang/stage_10101_map.tscn")
	assert_false(
		tscn_text.contains("ext_resource type=\"Resource\" path=\"res://data/stages/10101_bach_dang/stage_10101.tres\""),
		"stage_10101_map.tscn must not hold StageDef as ExtResource (cyclic dependency forbidden)"
	)

	var map_node: StageMapTool = stage.map_scene.instantiate() as StageMapTool
	assert_not_null(map_node, "stage_10101_map.tscn root must be StageMapTool")
	if map_node == null:
		return
	add_child_autofree(map_node)

	assert_not_null(map_node.ground_layer)
	assert_eq(map_node.ground_layer.get_used_cells().size(), stage.map_width * stage.map_height)
	assert_eq(map_node.get_terrain_at_odd_r(Vector2i(9, 4)), 6, "Fort hex (9,4) must resolve to TerrainType.FORT (6)")
	assert_eq(int(map_node.fort_owners.get(Vector2i(9, 4), 0)), 2)

	var markers: Array[UnitPlacementMarker] = map_node.get_placement_markers()
	assert_eq(markers.size(), stage.placements.size(), "Marker count must match stage_10101 placements")
	for marker: UnitPlacementMarker in markers:
		assert_eq(
			map_node.marker_local_to_odd_r(marker.position),
			marker.hex_pos,
			"Marker pixel position must round-trip cleanly to its odd-r hex_pos"
		)


func test_r3_t3_stage_map_tool_bidirectional_sync_roundtrip() -> void:
	var orig_stage: StageDef = ResourceLoader.load(
		"res://data/stages/10101_bach_dang/stage_10101.tres",
		"StageDef",
		ResourceLoader.CACHE_MODE_REPLACE
	) as StageDef
	assert_not_null(orig_stage)
	var stage_copy: StageDef = orig_stage.duplicate(true) as StageDef

	var packed: PackedScene = load("res://data/stages/10101_bach_dang/stage_10101_map.tscn") as PackedScene
	var editor_map: StageMapTool = packed.instantiate() as StageMapTool
	add_child_autofree(editor_map)

	editor_map.set_terrain_at_odd_r(Vector2i(1, 1), 3)
	var markers: Array[UnitPlacementMarker] = editor_map.get_placement_markers()
	assert_true(markers.size() > 0)
	var first_id: int = markers[0].unit_id
	markers[0].position = editor_map.odd_r_to_marker_local(Vector2i(3, 7))

	assert_true(editor_map.save_to_stage_def(stage_copy, false))

	var found_updated_pos: bool = false
	for p: UnitPlacementDef in stage_copy.placements:
		if p != null and p.unit_id == first_id:
			assert_eq(p.hex_pos, Vector2i(3, 7), "Saving StageMapTool must capture dragged marker hex_pos")
			found_updated_pos = true
	assert_true(found_updated_pos)

	var reload_map: StageMapTool = packed.instantiate() as StageMapTool
	add_child_autofree(reload_map)
	assert_true(reload_map.load_from_stage_def(stage_copy))
	assert_eq(reload_map.get_terrain_at_odd_r(Vector2i(1, 1)), 3, "Reloaded TileMapLayer must show edited Swamp tile")

	var reloaded_marker_found: bool = false
	for m: UnitPlacementMarker in reload_map.get_placement_markers():
		if m.unit_id == first_id:
			assert_eq(m.hex_pos, Vector2i(3, 7))
			reloaded_marker_found = true
	assert_true(reloaded_marker_found)


func test_r3_t3_battle_map_scene_binds_session_tide_fall_and_lod() -> void:
	var battle_map_packed: PackedScene = load("res://game/battle/map/battle_map.tscn") as PackedScene
	assert_not_null(battle_map_packed, "battle_map.tscn must load")
	var bmap: BattleMap = battle_map_packed.instantiate() as BattleMap
	assert_not_null(bmap)
	if bmap == null:
		return
	add_child_autofree(bmap)

	var registry: DataRegistry = StaticDataLoader.load_registry()
	var stage: StageDef = ResourceLoader.load(
		"res://data/stages/10101_bach_dang/stage_10101.tres",
		"StageDef",
		ResourceLoader.CACHE_MODE_REPLACE
	) as StageDef

	var session: BattleSession = BattleSession.new()
	session.registry = registry
	session.stage_def = stage
	add_child_autofree(session)
	assert_true(session.start_stage(10101, 12880409))

	bmap.bind_session(session)
	assert_false(bmap.stage_map.markers_layer.visible, "Editor MarkersLayer must hide during live battle")
	assert_eq(bmap.get_unit_view_count(), 12, "All 12 stage units must spawn as UnitViews")
	assert_eq(bmap.buildings_layer.get_child_count(), 1, "Fort at (9,4) must spawn 1 fort tower sprite")

	var tqt_axial: Vector2i = HexMathScript.odd_r_to_axial(Vector2i(2, 8))
	var world_pt: Vector2 = bmap.axial_to_world(tqt_axial)
	assert_eq(bmap.world_to_axial(world_pt), tqt_axial, "TileMapLayer world_to_axial must match axial_to_world")

	bmap.select_hex(tqt_axial)
	assert_not_null(bmap.get_selected_unit())
	assert_true(bmap.get_reachable_overlay_hexes().size() > 0)

	bmap.set_strategic_lod(true)
	assert_true(bmap.is_strategic_lod())
	var u101_view: UnitView = bmap.get_unit_view(101)
	assert_not_null(u101_view)
	assert_true(u101_view.is_strategic_lod(), "BattleMap must propagate strategic LOD to UnitViews")

	var ctrl: BattleGameController = session.get_controller()
	while ctrl.current_round < 4:
		var active_f: int = ctrl.current_faction_id
		ctrl.submit_command(BattleCommands.EndTurnCommand.new(active_f))
	session.state_refreshed.emit()

	var ground: TileMapLayer = bmap.get_ground_layer()
	for r: int in range(stage.map_height):
		for c: int in range(stage.map_width):
			var cell: Vector2i = Vector2i(c, r)
			assert_eq(ground.local_to_map(ground.map_to_local(cell)), cell, "Pointy-top map_to_local/local_to_map must round-trip at %s" % str(cell))

	assert_eq(
		ground.get_cell_atlas_coords(Vector2i(5, 4)),
		StageMapTool.terrain_to_atlas(int(MapStateScript.TerrainType.STAKED_WATER)),
		"Round 4 TideFall event must swap TileMapLayer cell (5,4) to StakedWater atlas coords"
	)
	assert_eq(
		bmap.stage_map.structure_layer.get_cell_atlas_coords(Vector2i(5, 4)),
		Vector2i(1, 4),
		"Round 4 TideFall event must place wooden stakes prop on StructureLayer cell (5,4)"
	)


func test_r3_t3_scripts_under_400_lines_and_canonical_tileset_data() -> void:
	var script_paths: Array[String] = [
		"res://game/battle/map/unit_placement_marker.gd",
		"res://game/battle/map/stage_map_tool.gd",
		"res://game/battle/map/hex_overlay_layer.gd",
		"res://game/battle/map/battle_map.gd",
	]
	for sp: String in script_paths:
		var text: String = FileAccess.get_file_as_string(sp)
		var line_count: int = text.split("\n").size()
		assert_lte(line_count, 400, "%s exceeds 400-line architecture cap (%d)" % [sp, line_count])

	var tileset: TileSet = load("res://assets_clean/hexcrown/tiles/hexcrown_hex_tileset.tres") as TileSet
	assert_not_null(tileset)
	assert_eq(tileset.tile_shape, TileSet.TILE_SHAPE_HEXAGON)
	assert_eq(tileset.tile_offset_axis, TileSet.TILE_OFFSET_AXIS_HORIZONTAL)
	assert_eq(tileset.tile_size, Vector2i(32, 22))
	assert_eq(StageMapTool.terrain_to_atlas(4), Vector2i(0, 5), "SHALLOW_RIVER must point to pale cyan water tile (0,5)")

	var atlas_src: TileSetAtlasSource = tileset.get_source(0) as TileSetAtlasSource
	assert_not_null(atlas_src)
	for terrain_id: int in range(9):
		var atlas_pos: Vector2i = StageMapTool.terrain_to_atlas(terrain_id)
		var alt_id: int = StageMapTool.terrain_to_alt(terrain_id)
		var tile_data: TileData = atlas_src.get_tile_data(atlas_pos, alt_id)
		assert_not_null(tile_data)
		if tile_data != null:
			assert_eq(tile_data.texture_origin, Vector2i(0, -4), "Pointy-top ground texture_origin must be (0, -4) for %d" % terrain_id)
			assert_eq(int(tile_data.get_custom_data("terrain_id")), terrain_id, "Custom data terrain_id mismatch for %d" % terrain_id)

