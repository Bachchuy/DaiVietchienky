class_name ScenarioEventConditionDef
extends Resource
## Trigger evaluation condition for a ScenarioEventDef (`res://data/defs/`).

@export_enum("current_round", "current_faction_id", "event_triggered", "general_alive", "general_defeated", "unit_hp_ratio", "area_owner", "unit_in_area", "general_clash", "enemy_defeated_percent") var field: String = "current_round"
@export_enum("==", "!=", ">=", "<=", ">", "<") var op: String = "=="
@export_enum("Numeric:0", "Bool:1") var value_kind: int = 0
@export var numeric_value: float = 1.0
@export var bool_value: bool = true
@export var event_id: String = ""
@export var general_id: int = 0
@export var other_general_id: int = 0
@export var unit_id: int = 0
@export var area_id: String = ""
@export var faction_id: int = -1


## Constructs a ScenarioEventConditionDef from a JSON-parsed condition dictionary.
static func from_dict(d: Dictionary) -> ScenarioEventConditionDef:
	var def := ScenarioEventConditionDef.new()
	def.field = str(d.get("field", "current_round"))
	def.op = str(d.get("op", "=="))
	var raw_val: Variant = d.get("value", true)
	if raw_val is bool:
		def.value_kind = 1
		def.bool_value = bool(raw_val)
	else:
		def.value_kind = 0
		def.numeric_value = float(raw_val)
	def.event_id = str(d.get("event_id", ""))
	def.general_id = int(d.get("general_id", 0))
	def.other_general_id = int(d.get("other_general_id", 0))
	def.unit_id = int(d.get("unit_id", 0))
	def.area_id = str(d.get("area_id", ""))
	def.faction_id = int(d.get("faction_id", -1))
	return def


## Serializes this condition to a dictionary compatible with ScenarioEventManager.
func to_dict() -> Dictionary:
	var out: Dictionary = {
		"field": field,
		"op": op,
		"value": bool_value if value_kind == 1 else numeric_value,
	}
	if not event_id.is_empty():
		out["event_id"] = event_id
	if general_id > 0:
		out["general_id"] = general_id
	if other_general_id > 0:
		out["other_general_id"] = other_general_id
	if unit_id > 0:
		out["unit_id"] = unit_id
	if not area_id.is_empty():
		out["area_id"] = area_id
	if faction_id != -1:
		out["faction_id"] = faction_id
	return out
