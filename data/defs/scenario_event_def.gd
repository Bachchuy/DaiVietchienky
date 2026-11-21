class_name ScenarioEventDef
extends Resource
## Trigger-condition-action scenario script entry (`res://data/defs/`).

@export var event_id: String = ""
@export var event_name: String = ""
@export_enum("OnRoundStart", "OnFactionTurnStart", "OnAfterCommand", "OnRoundEnd") var trigger_type: String = "OnRoundStart"
@export var once: bool = true
@export_enum("AND", "OR") var logic_operator: String = "AND"
@export var conditions: Array[ScenarioEventConditionDef] = []
@export var results: Array[ScenarioEventActionDef] = []


## Constructs a ScenarioEventDef from a JSON-parsed event dictionary.
static func from_dict(d: Dictionary) -> ScenarioEventDef:
	var def := ScenarioEventDef.new()
	def.event_id = str(d.get("event_id", ""))
	def.event_name = str(d.get("name", def.event_id))
	def.trigger_type = str(d.get("trigger_type", "OnRoundStart"))
	def.once = bool(d.get("once", true))
	var op_str: String = str(d.get("logic_operator", "AND")).to_upper()
	def.logic_operator = op_str if op_str in ["AND", "OR"] else "AND"

	var conds: Array[ScenarioEventConditionDef] = []
	var raw_conds: Variant = d.get("conditions", [])
	if raw_conds is Array:
		for c_var: Variant in raw_conds:
			if c_var is Dictionary:
				conds.append(ScenarioEventConditionDef.from_dict(c_var as Dictionary))
	def.conditions = conds

	var res_list: Array[ScenarioEventActionDef] = []
	var raw_res: Variant = d.get("results", [])
	if raw_res is Array:
		for r_var: Variant in raw_res:
			if r_var is Dictionary:
				res_list.append(ScenarioEventActionDef.from_dict(r_var as Dictionary))
	def.results = res_list
	return def


## Serializes this event to a dictionary compatible with ScenarioEventManager.setup().
func to_dict() -> Dictionary:
	var cond_dicts: Array[Dictionary] = []
	for c: ScenarioEventConditionDef in conditions:
		if c != null:
			cond_dicts.append(c.to_dict())
	var res_dicts: Array[Dictionary] = []
	for r: ScenarioEventActionDef in results:
		if r != null:
			res_dicts.append(r.to_dict())
	return {
		"event_id": event_id,
		"name": event_name,
		"trigger_type": trigger_type,
		"once": once,
		"logic_operator": logic_operator,
		"conditions": cond_dicts,
		"results": res_dicts,
	}
