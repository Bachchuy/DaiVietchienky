class_name DefeatConditionDef
extends Resource
## Stage defeat condition definition editable in Godot Inspector (`res://data/defs/`).

@export_enum("LoseKeyArea", "GeneralDefeated", "AllUnitsEliminated", "MaxRoundsUnfulfilled") var condition_type: String = "LoseKeyArea"
@export var area_id: String = ""
@export var target_general_id: int = 0
@export var faction_id: int = 1
@export_range(0, 50) var max_rounds: int = 0


## Constructs a DefeatConditionDef from a JSON-parsed defeat condition dictionary.
static func from_dict(d: Dictionary) -> DefeatConditionDef:
	var def := DefeatConditionDef.new()
	def.condition_type = str(d.get("type", "LoseKeyArea"))
	def.area_id = str(d.get("area_id", ""))
	def.target_general_id = int(d.get("target_general_id", 0))
	def.faction_id = int(d.get("faction_id", 1))
	def.max_rounds = int(d.get("max_rounds", 0))
	return def


## Serializes this DefeatConditionDef to a dictionary compatible with ScenarioVictoryEvaluator.
func to_dict() -> Dictionary:
	var out: Dictionary = {"type": condition_type}
	match condition_type:
		"LoseKeyArea":
			out["area_id"] = area_id
		"GeneralDefeated":
			out["target_general_id"] = target_general_id
		"AllUnitsEliminated":
			out["faction_id"] = faction_id
		"MaxRoundsUnfulfilled":
			out["max_rounds"] = max_rounds
		_:
			pass
	return out
