extends SceneTree
## Builds res://data/stages/10101_bach_dang/stage_10101_map.tscn from stage_10101.tres
## and links stage.map_scene without creating cyclic dependencies (`R3-T3`).

const STAGE_TRES_PATH: String = "res://data/stages/10101_bach_dang/stage_10101.tres"
const STAGE_MAP_TSCN_PATH: String = "res://data/stages/10101_bach_dang/stage_10101_map.tscn"
const TILESET_PATH: String = "res://assets_clean/hexcrown/tiles/hexcrown_hex_tileset.tres"


func _init() -> void:
	var stage: StageDef = ResourceLoader.load(STAGE_TRES_PATH, "StageDef", ResourceLoader.CACHE_MODE_REPLACE) as StageDef
	if stage == null:
		push_error("Failed to load StageDef at " + STAGE_TRES_PATH)
		quit(1)
		return

	var tileset: TileSet = ResourceLoader.load(TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	if tileset == null:
		push_error("Failed to load TileSet at " + TILESET_PATH)
		quit(1)
		return

	var root_node: StageMapTool = StageMapTool.new()
	root_node.name = "Stage10101Map"
	root_node.scale = Vector2(2.0, 2.0)
	root_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root_node.stage_tres_path = STAGE_TRES_PATH

	var ground: TileMapLayer = TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.y_sort_enabled = true
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.tile_set = tileset
	root_node.add_child(ground)
	ground.owner = root_node

	var structure: TileMapLayer = TileMapLayer.new()
	structure.name = "StructureLayer"
	structure.z_index = 2
	structure.y_sort_enabled = true
	structure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	structure.tile_set = tileset
	root_node.add_child(structure)
	structure.owner = root_node

	var markers: Node2D = Node2D.new()
	markers.name = "MarkersLayer"
	markers.z_index = 10
	root_node.add_child(markers)
	markers.owner = root_node

	root_node.ground_layer = ground
	root_node.structure_layer = structure
	root_node.markers_layer = markers

	var loaded_ok: bool = root_node.load_from_stage_def(stage)
	if not loaded_ok:
		push_error("StageMapTool.load_from_stage_def failed for " + STAGE_TRES_PATH)
		root_node.free()
		quit(2)
		return

	for child: Node in markers.get_children():
		child.owner = root_node

	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root_node)
	if pack_err != OK:
		push_error("PackedScene.pack failed with error %d" % pack_err)
		root_node.free()
		quit(3)
		return

	var save_map_err: Error = ResourceSaver.save(packed, STAGE_MAP_TSCN_PATH)
	if save_map_err != OK:
		push_error("ResourceSaver.save failed for %s (%d)" % [STAGE_MAP_TSCN_PATH, save_map_err])
		root_node.free()
		quit(4)
		return

	var reloaded_map_scene: PackedScene = ResourceLoader.load(STAGE_MAP_TSCN_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	stage.map_scene = reloaded_map_scene
	var save_stage_err: Error = ResourceSaver.save(stage, STAGE_TRES_PATH)
	if save_stage_err != OK:
		push_error("ResourceSaver.save failed for %s (%d)" % [STAGE_TRES_PATH, save_stage_err])
		root_node.free()
		quit(5)
		return

	print(
		"BUILD OK | cells=%d | markers=%d | forts=%d | map=%s" % [
			ground.get_used_cells().size(),
			markers.get_child_count(),
			root_node.fort_owners.size(),
			STAGE_MAP_TSCN_PATH,
		]
	)
	root_node.free()
	quit(0)
