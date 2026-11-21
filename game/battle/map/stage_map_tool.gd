@tool
class_name StageMapTool
extends Node2D
## Bidirectional @tool TileMapLayer + placement-marker controller bound to a StageDef .tres (`res://game/battle/map/`).

const TILESET_PATH: String = "res://assets_clean/hexcrown/tiles/hexcrown_hex_tileset.tres"
const BLUE_TOWER_PATH: String = "res://assets_clean/hexcrown/buildings/blue/tower.png"
const RED_TOWER_PATH: String = "res://assets_clean/hexcrown/buildings/red/tower.png"

## Canonical TerrainType (0..8) -> TileSetAtlasSource cell coords & alternative ID inside tileset_atlas.png.
const TERRAIN_TO_ATLAS: Dictionary[int, Vector2i] = {
	0: Vector2i(0, 2), ## PLAINS
	1: Vector2i(0, 2), ## FOREST (alt 1)
	2: Vector2i(0, 3), ## HILLS
	3: Vector2i(0, 2), ## SWAMP (alt 2)
	4: Vector2i(0, 5), ## SHALLOW_RIVER
	5: Vector2i(0, 4), ## DEEP_WATER
	6: Vector2i(0, 0), ## FORT
	7: Vector2i(0, 7), ## ROAD_PORT
	8: Vector2i(0, 1), ## STAKED_WATER
}

const TERRAIN_TO_ALT: Dictionary[int, int] = {
	1: 1,
	3: 2,
}

## Canonical TerrainType -> optional decorative prop tile in TileSet source 1 (map_elements.png).
const TERRAIN_TO_PROP: Dictionary[int, Vector2i] = {
	1: Vector2i(0, 3), ## Forest trees
	2: Vector2i(0, 2), ## Green hills
	3: Vector2i(0, 4), ## Swamp pond
	6: Vector2i(2, 2), ## Stone citadel
	7: Vector2i(2, 3), ## Riverbank dock/village
	8: Vector2i(1, 4), ## Wooden stakes (Bai Coc)
}

const ATLAS_TO_TERRAIN: Dictionary[Vector2i, int] = {
	Vector2i(0, 2): 0,
	Vector2i(0, 3): 2,
	Vector2i(0, 5): 4,
	Vector2i(0, 4): 5,
	Vector2i(0, 0): 6,
	Vector2i(0, 7): 7,
	Vector2i(0, 1): 8,
}

@export_file("*.tres") var stage_tres_path: String = "res://data/stages/10101_bach_dang/stage_10101.tres"

@export_tool_button("Load From Stage .tres") var btn_load_stage: Callable = _on_editor_load_pressed
@export_tool_button("Save To Stage .tres") var btn_save_stage: Callable = _on_editor_save_pressed
@export_tool_button("Snap Markers To Grid") var btn_snap_markers: Callable = snap_all_markers

@export_group("Scene Nodes")
@export var ground_layer: TileMapLayer
@export var structure_layer: TileMapLayer
@export var markers_layer: Node2D

@export_group("Map Metadata")
@export_range(6, 60) var map_width: int = 12
@export_range(6, 60) var map_height: int = 10
@export_enum("Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var default_terrain: int = 0
@export var fort_owners: Dictionary[Vector2i, int] = {}


func _ready() -> void:
	_ensure_layers()
	set_editor_markers_visible(Engine.is_editor_hint())


func _on_editor_load_pressed() -> void:
	load_from_stage_def()


func _on_editor_save_pressed() -> void:
	save_to_stage_def(null, true)


static func terrain_to_atlas(terrain_id: int) -> Vector2i:
	return TERRAIN_TO_ATLAS.get(terrain_id, Vector2i(0, 2))


static func terrain_to_alt(terrain_id: int) -> int:
	return TERRAIN_TO_ALT.get(terrain_id, 0)


static func terrain_to_prop(terrain_id: int) -> Vector2i:
	return TERRAIN_TO_PROP.get(terrain_id, Vector2i(-1, -1))


func atlas_to_terrain(atlas_coords: Vector2i, odd_r: Vector2i = Vector2i(-1, -1), alt_id: int = 0) -> int:
	if ground_layer != null and odd_r.x >= 0 and odd_r.y >= 0:
		var td: TileData = ground_layer.get_cell_tile_data(odd_r)
		if td != null:
			var custom_val: Variant = td.get_custom_data("terrain_id")
			if custom_val is int:
				return int(custom_val)
	if atlas_coords == Vector2i(0, 2):
		if alt_id == 1:
			return 1
		if alt_id == 2:
			return 3
		return 0
	if ATLAS_TO_TERRAIN.has(atlas_coords):
		return int(ATLAS_TO_TERRAIN[atlas_coords])
	return default_terrain


func ensure_layers_ready() -> void:
	_ensure_layers()


func set_editor_markers_visible(visible_flag: bool) -> void:
	_ensure_layers()
	if markers_layer != null:
		markers_layer.visible = visible_flag


func set_terrain_at_odd_r(odd_r: Vector2i, terrain_id: int, fort_owner: int = -1) -> void:
	_ensure_layers()
	if ground_layer == null:
		return
	ground_layer.set_cell(odd_r, 0, terrain_to_atlas(terrain_id), terrain_to_alt(terrain_id))
	if structure_layer != null:
		var prop: Vector2i = terrain_to_prop(terrain_id)
		if prop.x >= 0 and prop.y >= 0:
			structure_layer.set_cell(odd_r, 1, prop, 0)
		else:
			structure_layer.erase_cell(odd_r)
	if fort_owner > 0:
		fort_owners[odd_r] = fort_owner
	elif fort_owner == 0 and fort_owners.has(odd_r):
		fort_owners.erase(odd_r)


func get_terrain_at_odd_r(odd_r: Vector2i) -> int:
	_ensure_layers()
	if ground_layer == null or ground_layer.get_cell_source_id(odd_r) < 0:
		return default_terrain
	return atlas_to_terrain(
		ground_layer.get_cell_atlas_coords(odd_r),
		odd_r,
		ground_layer.get_cell_alternative_tile(odd_r)
	)


func odd_r_to_marker_local(odd_r: Vector2i) -> Vector2:
	_ensure_layers()
	if ground_layer == null:
		return Vector2.ZERO
	var ground_local: Vector2 = ground_layer.map_to_local(odd_r)
	if markers_layer == null:
		return ground_local
	return ground_layer.position + ground_local - markers_layer.position


func marker_local_to_odd_r(marker_local_pos: Vector2) -> Vector2i:
	_ensure_layers()
	if ground_layer == null:
		return Vector2i.ZERO
	var in_ground: Vector2 = marker_local_pos
	if markers_layer != null:
		in_ground = marker_local_pos + markers_layer.position - ground_layer.position
	return ground_layer.local_to_map(in_ground)


func snap_all_markers() -> void:
	_ensure_layers()
	if markers_layer == null:
		return
	for child: Node in markers_layer.get_children():
		if child is UnitPlacementMarker:
			var marker: UnitPlacementMarker = child as UnitPlacementMarker
			marker.sync_hex_from_position()
			marker.snap_to_hex(marker.hex_pos)


func load_from_stage_def(stage_override: StageDef = null) -> bool:
	_ensure_layers()
	var stage: StageDef = stage_override if stage_override != null else _load_stage_resource()
	if stage == null or ground_layer == null or markers_layer == null:
		return false

	if ground_layer.tile_set == null:
		var ts: TileSet = load(TILESET_PATH) as TileSet
		ground_layer.tile_set = ts

	map_width = maxi(1, stage.map_width)
	map_height = maxi(1, stage.map_height)
	default_terrain = stage.default_terrain
	fort_owners.clear()
	ground_layer.clear()
	if structure_layer != null:
		structure_layer.clear()

	var default_atlas: Vector2i = terrain_to_atlas(default_terrain)
	for row: int in range(map_height):
		for col: int in range(map_width):
			ground_layer.set_cell(Vector2i(col, row), 0, default_atlas, 0)

	for ov: TerrainOverrideDef in stage.terrain_overrides:
		if ov == null:
			continue
		set_terrain_at_odd_r(ov.hex_pos, ov.terrain, ov.fort_owner if ov.fort_owner != 0 else -1)

	_rebuild_markers_from_stage(stage)
	return true


func save_to_stage_def(stage_override: StageDef = null, write_to_disk: bool = true) -> bool:
	_ensure_layers()
	var stage: StageDef = stage_override if stage_override != null else _load_stage_resource()
	if stage == null or ground_layer == null or markers_layer == null:
		return false

	stage.map_width = map_width
	stage.map_height = map_height
	stage.default_terrain = default_terrain

	var cells: Array[Vector2i] = ground_layer.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	var new_overrides: Array[TerrainOverrideDef] = []
	for cell: Vector2i in cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= map_width or cell.y >= map_height:
			continue
		var terrain_id: int = get_terrain_at_odd_r(cell)
		var f_owner: int = int(fort_owners.get(cell, 0))
		if terrain_id != default_terrain or f_owner != 0:
			var ov: TerrainOverrideDef = TerrainOverrideDef.new()
			ov.hex_pos = cell
			ov.terrain = terrain_id
			ov.fort_owner = f_owner
			new_overrides.append(ov)
	stage.terrain_overrides = new_overrides

	var marker_nodes: Array[UnitPlacementMarker] = get_placement_markers()
	marker_nodes.sort_custom(func(a: UnitPlacementMarker, b: UnitPlacementMarker) -> bool:
		return a.unit_id < b.unit_id
	)
	var new_placements: Array[UnitPlacementDef] = []
	for marker: UnitPlacementMarker in marker_nodes:
		marker.sync_hex_from_position()
		marker.snap_to_hex(marker.hex_pos)
		new_placements.append(marker.to_placement_def())
	stage.placements = new_placements

	if write_to_disk and not stage_tres_path.is_empty():
		return ResourceSaver.save(stage, stage_tres_path) == OK
	return true


func get_placement_markers() -> Array[UnitPlacementMarker]:
	_ensure_layers()
	var out: Array[UnitPlacementMarker] = []
	if markers_layer == null:
		return out
	for child: Node in markers_layer.get_children():
		if child is UnitPlacementMarker:
			out.append(child as UnitPlacementMarker)
	return out


func _rebuild_markers_from_stage(stage: StageDef) -> void:
	for child: Node in markers_layer.get_children():
		markers_layer.remove_child(child)
		child.free()

	var scene_owner: Node = self
	if is_inside_tree() and Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		if get_tree().edited_scene_root == self or get_tree().edited_scene_root.is_ancestor_of(self):
			scene_owner = get_tree().edited_scene_root

	for p: UnitPlacementDef in stage.placements:
		if p == null:
			continue
		var marker: UnitPlacementMarker = UnitPlacementMarker.new()
		marker.name = _build_marker_name(p)
		marker.apply_from_def(p)
		markers_layer.add_child(marker)
		if Engine.is_editor_hint() or owner != null:
			marker.owner = scene_owner if Engine.is_editor_hint() else owner
		marker.position = odd_r_to_marker_local(p.hex_pos)


func _build_marker_name(p: UnitPlacementDef) -> String:
	var base: String = "Unit_%d" % p.unit_id
	if not p.general_name.is_empty():
		var clean: String = p.general_name.replace(" ", "_")
		return "%s_%s" % [base, clean]
	return base


func _load_stage_resource() -> StageDef:
	if stage_tres_path.is_empty() or not ResourceLoader.exists(stage_tres_path):
		return null
	return ResourceLoader.load(stage_tres_path, "StageDef", ResourceLoader.CACHE_MODE_REPLACE) as StageDef


static func sync_fort_sprites(
	buildings_layer: Node2D,
	map_state: BattleMapState,
	centers: Dictionary[Vector2i, Vector2],
	prev_signature: String
) -> String:
	if buildings_layer == null or map_state == null:
		return prev_signature
	var fort_hexes: Array[Vector2i] = map_state.get_fort_hexes()
	var sig_parts: PackedStringArray = []
	for fh: Vector2i in fort_hexes:
		sig_parts.append("%d,%d:%d" % [fh.x, fh.y, map_state.get_fort_owner(fh)])
	var next_sig: String = "|".join(sig_parts)
	if next_sig == prev_signature:
		return prev_signature
	for child: Node in buildings_layer.get_children():
		buildings_layer.remove_child(child)
		child.queue_free()
	var blue_tex: Texture2D = ResourceLoader.load(BLUE_TOWER_PATH) as Texture2D
	var red_tex: Texture2D = ResourceLoader.load(RED_TOWER_PATH) as Texture2D
	for fh: Vector2i in fort_hexes:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = red_tex if map_state.get_fort_owner(fh) >= 2 else blue_tex
		sprite.scale = Vector2(0.16, 0.16)
		sprite.position = centers.get(fh, HexMath.axial_to_world(fh)) + Vector2(0.0, -6.0)
		buildings_layer.add_child(sprite)
	return next_sig


func sync_cells_from_map_state(map_state: BattleMapState) -> void:
	if map_state == null:
		return
	_ensure_layers()
	var resized: bool = map_width != map_state.width or map_height != map_state.height
	map_width = map_state.width
	map_height = map_state.height
	if resized and ground_layer != null:
		ground_layer.clear()
		if structure_layer != null:
			structure_layer.clear()
	for row: int in range(map_height):
		for col: int in range(map_width):
			var odd_r: Vector2i = Vector2i(col, row)
			var axial: Vector2i = HexMath.odd_r_to_axial(odd_r)
			var sim_terrain: int = int(map_state.get_terrain(axial))
			var missing: bool = ground_layer == null or ground_layer.get_cell_source_id(odd_r) < 0
			if missing or get_terrain_at_odd_r(odd_r) != sim_terrain:
				set_terrain_at_odd_r(odd_r, sim_terrain, map_state.get_fort_owner(axial))


func _ensure_layers() -> void:
	if ground_layer == null:
		ground_layer = get_node_or_null("GroundLayer") as TileMapLayer
	if ground_layer == null:
		ground_layer = TileMapLayer.new()
		ground_layer.name = "GroundLayer"
		ground_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground_layer.tile_set = load(TILESET_PATH) as TileSet
		add_child(ground_layer)
	ground_layer.y_sort_enabled = true
	if structure_layer == null:
		structure_layer = get_node_or_null("StructureLayer") as TileMapLayer
	if structure_layer == null:
		structure_layer = TileMapLayer.new()
		structure_layer.name = "StructureLayer"
		structure_layer.z_index = 2
		structure_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		structure_layer.tile_set = ground_layer.tile_set
		add_child(structure_layer)
	if structure_layer.tile_set == null:
		structure_layer.tile_set = ground_layer.tile_set
	structure_layer.y_sort_enabled = true
	if markers_layer == null:
		markers_layer = get_node_or_null("MarkersLayer") as Node2D
	if markers_layer == null:
		markers_layer = Node2D.new()
		markers_layer.name = "MarkersLayer"
		markers_layer.z_index = 10
		add_child(markers_layer)
