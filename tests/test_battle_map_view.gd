extends "res://tests/test_case.gd"

const VIEW_PATH: String = "res://scripts/presentation/battle_map_view.gd"
const HexMathScript = preload("res://sim/rules/hex_math.gd")
const MapStateScript = preload("res://sim/state/battle_map_state.gd")
const UnitScript = preload("res://sim/state/battle_unit.gd")
const NavScript = preload("res://sim/rules/hex_grid_navigator.gd")


func _make_view() -> Node2D:
	var view_s: GDScript = load(VIEW_PATH) as GDScript
	assert_not_null(view_s, "BattleMapView script must exist at " + VIEW_PATH)
	if view_s == null:
		return null
	var node: Node2D = view_s.new() as Node2D
	add_child_autofree(node)
	return node


func test_sixteen_render_layers_structure_and_z_order() -> void:
	var view: Node2D = _make_view()
	if view == null:
		return

	var expected_world_layers: Dictionary = {
		"GroundLayer": 0,
		"WaterAndTideLayer": 2,
		"GridHexLayer": 4,
		"FactionBorderLayer": 6,
		"ReachableAreaLayer": 12,
		"AttackableAreaLayer": 14,
		"SkillAreaLayer": 16,
		"SelectionAndAimLayer": 18,
		"BuildingAndFortLayer": 28,
		"UnitBaseAuraLayer": 32,
		"UnitModelLayer": 36,
		"StrategicTokenLayer": 38,
		"MapEffectLayer": 42,
		"FogOfWarLayer": 48,
		"WorldSpaceUnitHudAndTextLayer": 55,
	}

	assert_eq(view.get_child_count(), 16, "BattleMapView must own exactly 16 render layers")

	for layer_name: String in expected_world_layers.keys():
		var child: Node2D = view.get_node_or_null(layer_name) as Node2D
		assert_not_null(child, "Missing world layer: " + layer_name)
		if child != null:
			assert_eq(child.z_index, int(expected_world_layers[layer_name]), "Wrong z_index on " + layer_name)
			assert_false(child.z_as_relative, layer_name + " must use absolute z_index")

	var hud_layer: CanvasLayer = view.get_node_or_null("ScreenHudCanvasLayer") as CanvasLayer
	assert_not_null(hud_layer, "Missing ScreenHudCanvasLayer")
	if hud_layer != null:
		assert_eq(hud_layer.layer, 10, "ScreenHudCanvasLayer must sit on CanvasLayer 10")


func test_select_unit_populates_reachable_blue_and_attackable_red_overlays() -> void:
	var view: Node2D = _make_view()
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

	view.call("bind_battle_state", map_state, nav)
	view.call("select_hex", archer.hex_position)

	assert_eq(view.call("get_selected_unit"), archer)
	var expected_reach: Dictionary = nav.get_reachable_hexes(map_state, archer)
	var actual_reach: Dictionary = view.call("get_reachable_overlay_hexes")
	assert_eq(actual_reach.size(), expected_reach.size(), "Blue ReachableAreaLayer count must match navigator")
	for h: Vector2i in expected_reach.keys():
		assert_has(actual_reach, h)

	var actual_atk: Array[Vector2i] = view.call("get_attackable_overlay_hexes")
	assert_has(actual_atk, enemy.hex_position, "Enemy in range 2 with clear LOS must appear in red AttackableAreaLayer")

	var dest_hex: Vector2i = archer.hex_position + Vector2i(0, 1)
	view.call("preview_path_to", dest_hex)
	var preview_path: Array[Vector2i] = view.call("get_preview_path")
	assert_eq(preview_path.size(), 2)
	assert_eq(preview_path[1], dest_hex)

	view.call("clear_selection")
	assert_null(view.call("get_selected_unit"))
	assert_eq((view.call("get_reachable_overlay_hexes") as Dictionary).size(), 0)
	assert_eq((view.call("get_attackable_overlay_hexes") as Array).size(), 0)


func test_strategic_lod_toggle_switches_unit_model_and_token_layers() -> void:
	var view: Node2D = _make_view()
	if view == null:
		return

	var model_layer: Node2D = view.get_node("UnitModelLayer") as Node2D
	var token_layer: Node2D = view.get_node("StrategicTokenLayer") as Node2D
	assert_true(model_layer.visible)
	assert_false(token_layer.visible)

	view.call("set_strategic_lod", true)
	assert_false(model_layer.visible, "UnitModelLayer hides in StrategicZoom")
	assert_true(token_layer.visible, "StrategicTokenLayer shows in StrategicZoom")

	view.call("set_strategic_lod", false)
	assert_true(model_layer.visible)
	assert_false(token_layer.visible)
