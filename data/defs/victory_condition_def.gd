class_name VictoryConditionDef
extends Resource
## Stage victory condition definition editable in Godot Inspector (`res://data/defs/`).

@export_enum("DefeatGeneralWhileHoldingArea", "HoldAreaAndEnemyCasualtyAtMaxRound", "DefeatGeneral", "HoldAreaAndAttrition") var condition_type: String = "DefeatGeneralWhileHoldingArea"
@export var target_general_id: int = 0
@export var required_area_id: String = ""
@export var required_owner: int = 0
@export var instant: bool = true
@export_range(0.0, 100.0, 0.5) var min_enemy_defeated_percent: float = 75.0
@export_range(0, 50) var at_round: int = 0


## Constructs a VictoryConditionDef from a JSON-parsed victory condition dictionary.
static func from_dict(d: Dictionary) -> VictoryConditionDef:
	var def := VictoryConditionDef.new()
	def.condition_type = str(d.get("type", "DefeatGeneralWhileHoldingArea"))
	def.target_general_id = int(d.get("target_general_id", 0))
	def.required_area_id = str(d.get("required_area_id", d.get("area_id", "")))
	def.required_owner = int(d.get("required_owner", 0))
	def.instant = bool(d.get("instant", true))
	def.min_enemy_defeated_percent = float(d.get("min_enemy_defeated_percent", 75.0))
	def.at_round = int(d.get("at_round", 0))
	return def


## Serializes this VictoryConditionDef to a dictionary compatible with ScenarioVictoryEvaluator.
func to_dict() -> Dictionary:
	var out: Dictionary = {"type": condition_type}
	match condition_type:
		"DefeatGeneralWhileHoldingArea":
			out["target_general_id"] = target_general_id
			out["required_area_id"] = required_area_id
			out["instant"] = instant
		"HoldAreaAndEnemyCasualtyAtMaxRound":
			out["required_area_id"] = required_area_id
			out["min_enemy_defeated_percent"] = min_enemy_defeated_percent
			out["at_round"] = at_round
		"DefeatGeneral":
			out["target_general_id"] = target_general_id
		"HoldAreaAndAttrition":
			out["area_id"] = required_area_id
			out["required_area_id"] = required_area_id
			out["required_owner"] = required_owner
			out["min_enemy_defeated_percent"] = min_enemy_defeated_percent
			out["at_round"] = at_round
		_:
			out["target_general_id"] = target_general_id
			out["required_area_id"] = required_area_id
			out["instant"] = instant
	return out
