class_name StageFactionDef
extends Resource
## Faction alliance, AI profile, and starting economy configuration for a StageDef (`res://data/defs/`).

@export_group("Faction")
@export var faction_id: int = 1
@export var display_name: String = ""
@export var team_id: int = 1
@export var is_player: bool = false
@export_enum("easy", "normal", "hard", "nightmare") var ai_profile: String = "normal"
@export var target_generals: Array[int] = []
@export var protected_generals: Array[int] = []

@export_group("Initial Economy")
@export var start_coin: int = 300
@export var start_food: int = 300
@export var start_tech: int = 150
@export var start_mana: int = 100


static func _to_int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for item: Variant in raw:
			out.append(int(item))
	return out


## Constructs a StageFactionDef from battle faction & optional economy dictionaries.
static func from_dict(d: Dictionary, eco_dict: Dictionary = {}) -> StageFactionDef:
	var def := StageFactionDef.new()
	def.faction_id = int(d.get("faction_id", 1))
	def.display_name = str(d.get("name", ""))
	def.team_id = int(d.get("team_id", def.faction_id))
	def.is_player = bool(d.get("is_player", false))
	var profile_raw: String = str(d.get("ai_profile", "normal")).to_lower()
	def.ai_profile = profile_raw if profile_raw in ["easy", "normal", "hard", "nightmare"] else "normal"
	def.target_generals = _to_int_array(d.get("target_generals", []))
	def.protected_generals = _to_int_array(d.get("protected_generals", []))
	if not eco_dict.is_empty():
		def.start_coin = int(eco_dict.get("coin", 300))
		def.start_food = int(eco_dict.get("food", 300))
		def.start_tech = int(eco_dict.get("tech", 150))
		def.start_mana = int(eco_dict.get("mana", 100))
	return def


## Serializes faction alliance and AI general targets matching battle JSON `factions`.
func to_dict() -> Dictionary:
	return {
		"faction_id": faction_id,
		"name": display_name,
		"team_id": team_id,
		"is_player": is_player,
		"ai_profile": ai_profile,
		"target_generals": Array(target_generals),
		"protected_generals": Array(protected_generals),
	}


## Serializes initial economy resources matching battle JSON `economy.factions[id]`.
func to_economy_dict() -> Dictionary:
	return {
		"coin": start_coin,
		"food": start_food,
		"tech": start_tech,
		"mana": start_mana,
	}
