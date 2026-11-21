class_name TacticDef
extends Resource
## Active commander skill or battlefield tactic blueprint (`res://data/defs/`).

@export_group("Identity")
@export var tactic_id: int = 0
@export var code: String = ""
@export var display_name: String = ""
@export var owner_general_id: int = 0
@export var icon: Texture2D

@export_group("Effects & Cost")
@export_range(0, 12) var range_hex: int = 2
@export_range(0, 6) var aoe_radius: int = 1
@export_range(0, 20) var cooldown_turns: int = 3
@export_range(0, 500) var mana_cost: int = 0
@export_range(-3, 3) var morale_shift: int = 0
@export var clears_chaos: bool = false
@export_range(0, 10) var mp_bonus: int = 0

@export_group("Historical Metadata")
@export_enum("historical_claim", "fixture", "abstraction", "what_if") var modeling_type: String = "historical_claim"
@export_multiline var source_ref: String = ""


## Constructs a TacticDef from a JSON-parsed tactic dictionary.
static func from_dict(d: Dictionary) -> TacticDef:
	var def := TacticDef.new()
	def.tactic_id = int(d.get("tactic_id", d.get("id", 0)))
	def.code = str(d.get("code", ""))
	def.display_name = str(d.get("display_name", d.get("name", def.code)))
	def.owner_general_id = int(d.get("owner_general_id", 0))
	def.range_hex = int(d.get("range_hex", 2))
	def.aoe_radius = int(d.get("aoe_radius", 1))
	def.cooldown_turns = int(d.get("cooldown_turns", 3))
	def.mana_cost = int(d.get("mana_cost", 0))
	def.morale_shift = int(d.get("morale_shift", 0))
	def.clears_chaos = bool(d.get("clears_chaos", false))
	def.mp_bonus = int(d.get("mp_bonus", 0))
	def.modeling_type = str(d.get("modeling_type", "historical_claim"))
	def.source_ref = str(d.get("source_ref", ""))
	return def


## Serializes this TacticDef to a dictionary matching tactic_settings.json structure.
func to_dict() -> Dictionary:
	return {
		"id": tactic_id,
		"code": code,
		"name": display_name,
		"owner_general_id": owner_general_id,
		"range_hex": range_hex,
		"aoe_radius": aoe_radius,
		"cooldown_turns": cooldown_turns,
		"mana_cost": mana_cost,
		"morale_shift": morale_shift,
		"clears_chaos": clears_chaos,
		"mp_bonus": mp_bonus,
		"modeling_type": modeling_type,
		"source_ref": source_ref,
	}
