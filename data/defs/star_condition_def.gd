class_name StarConditionDef
extends Resource
## Stage 1-3 star rating condition definition editable in Godot Inspector (`res://data/defs/`).

@export_range(1, 3) var star: int = 1
@export_enum("Victory", "MaxRoundLimit", "CasualtyHpPercentLimit", "MaxRounds", "MaxHpLossPercent") var condition_type: String = "Victory"
@export_range(0, 50) var max_rounds: int = 8
@export_range(0.0, 100.0, 0.5) var max_loss_percent: float = 20.0
@export_multiline var description: String = ""


## Constructs a StarConditionDef from a JSON-parsed star condition dictionary.
static func from_dict(d: Dictionary) -> StarConditionDef:
	var def := StarConditionDef.new()
	def.star = clampi(int(d.get("star", 1)), 1, 3)
	def.condition_type = str(d.get("type", "Victory"))
	def.max_rounds = int(d.get("max_rounds", 8))
	def.max_loss_percent = float(d.get("max_loss_percent", 20.0))
	def.description = str(d.get("description", ""))
	return def


## Serializes this StarConditionDef to a dictionary compatible with ScenarioVictoryEvaluator.
func to_dict() -> Dictionary:
	var out: Dictionary = {
		"star": star,
		"type": condition_type,
		"description": description,
	}
	if condition_type in ["MaxRoundLimit", "MaxRounds"]:
		out["max_rounds"] = max_rounds
	elif condition_type in ["CasualtyHpPercentLimit", "MaxHpLossPercent"]:
		out["max_loss_percent"] = max_loss_percent
	return out
