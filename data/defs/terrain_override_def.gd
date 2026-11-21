class_name TerrainOverrideDef
extends Resource
## Single-hex terrain (and optional fort owner) override for a StageDef (`res://data/defs/`).

@export var hex_pos: Vector2i = Vector2i.ZERO
@export_enum("Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var terrain: int = 0
@export var fort_owner: int = 0


## Constructs a TerrainOverrideDef from a JSON-parsed terrain override dictionary.
static func from_dict(d: Dictionary) -> TerrainOverrideDef:
	var def := TerrainOverrideDef.new()
	def.hex_pos = Vector2i(int(d.get("q", d.get("col", 0))), int(d.get("r", d.get("row", 0))))
	def.terrain = maxi(0, TroopDef.parse_terrain_id(d.get("terrain", "Plains")))
	def.fort_owner = int(d.get("fort_owner", 0))
	return def


## Serializes this override to a dictionary compatible with ScenarioLoader.
func to_dict() -> Dictionary:
	var out: Dictionary = {
		"q": hex_pos.x,
		"r": hex_pos.y,
		"terrain": TroopDef.terrain_to_name(terrain),
	}
	if fort_owner > 0:
		out["fort_owner"] = fort_owner
	return out
