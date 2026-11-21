class_name StageFacilityDef
extends Resource
## Pre-placed battlefield economy facility instance in a StageDef (`res://data/defs/`).

@export var facility_instance_id: String = ""
@export var owner_faction_id: int = 1
@export_enum("Farm", "Market", "Mine", "Temple", "Granary", "Academy", "Fort") var facility_type: String = "Farm"
@export_range(1, 3) var level: int = 1
@export_range(0, 7) var turns_unrobbed: int = 1
@export var has_granary: bool = false
@export var hex_pos: Vector2i = Vector2i(-1, -1)


## Constructs a StageFacilityDef from a JSON-parsed economy facility dictionary.
static func from_dict(d: Dictionary) -> StageFacilityDef:
	var def := StageFacilityDef.new()
	def.facility_instance_id = str(d.get("id", ""))
	def.owner_faction_id = int(d.get("owner", 1))
	def.facility_type = str(d.get("type", "Farm"))
	def.level = clampi(int(d.get("level", 1)), 1, 3)
	def.turns_unrobbed = clampi(int(d.get("turns_unrobbed", 1)), 0, 7)
	def.has_granary = bool(d.get("has_granary", false))
	if d.has("hex_pos") and d["hex_pos"] is Vector2i:
		def.hex_pos = d["hex_pos"] as Vector2i
	elif d.has("q") or d.has("r"):
		def.hex_pos = Vector2i(int(d.get("q", -1)), int(d.get("r", -1)))
	return def


## Serializes this facility placement to a dictionary compatible with ScenarioLoader.
func to_dict() -> Dictionary:
	return {
		"id": facility_instance_id,
		"owner": owner_faction_id,
		"type": facility_type,
		"level": level,
		"turns_unrobbed": turns_unrobbed,
		"has_granary": has_granary,
		"q": hex_pos.x,
		"r": hex_pos.y,
	}
