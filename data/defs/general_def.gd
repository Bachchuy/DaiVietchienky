class_name GeneralDef
extends Resource
## Historical or tactical commander definition editable in the Godot Inspector (`res://data/defs/`).

@export_group("Identity")
@export var general_id: int = 0
@export var code: String = ""
@export var display_name: String = ""
@export var faction_id: int = 1
@export var is_commander_in_chief: bool = false
@export var portrait: Texture2D

@export_group("Command Stats")
@export_range(0, 100) var command_stat: int = 20
@export_range(0, 100) var luck: int = 70
@export_range(0.5, 2.0, 0.01) var m_command: float = 1.15

@export_group("Command Profile")
@export_range(0.5, 2.0, 0.01) var infantry_mult: float = 1.0
@export_range(0.5, 2.0, 0.01) var archer_mult: float = 1.0
@export_range(0.5, 2.0, 0.01) var cavalry_mult: float = 1.0
@export_range(0.5, 2.0, 0.01) var naval_mult: float = 1.0

@export_group("Command Aura")
@export_range(0, 6) var aura_radius_hex: int = 1
@export_range(0, 100) var aura_damage_deepen: int = 0
@export_range(0, 100) var aura_damage_resist: int = 0
@export var grants_dead_mate_immunity: bool = false

@export_group("Unique Skill")
@export var unique_skill_id: int = 0
@export var unique_skill_name: String = ""
@export_range(0, 20) var unique_skill_cooldown: int = 3
@export_range(0, 10) var unique_skill_range: int = 2
@export_range(0, 6) var unique_skill_aoe: int = 1

@export_group("Historical Metadata")
@export_enum("historical_claim", "fixture", "abstraction", "what_if") var modeling_type: String = "historical_claim"
@export_multiline var source_ref: String = ""


## Returns the command multiplier for a given troop command branch name.
func get_branch_multiplier(branch_name: String) -> float:
	match branch_name.strip_edges().to_lower():
		"infantry":
			return infantry_mult
		"archer", "archery", "ranged":
			return archer_mult
		"cavalry":
			return cavalry_mult
		"naval", "navallight", "naval_light", "navalheavy", "naval_heavy":
			return naval_mult
		_:
			return 1.0


## Constructs a GeneralDef from a JSON-parsed general dictionary.
static func from_dict(d: Dictionary) -> GeneralDef:
	var def := GeneralDef.new()
	def.general_id = int(d.get("general_id", d.get("id", 0)))
	def.code = str(d.get("code", ""))
	def.display_name = str(d.get("display_name", d.get("name", def.code)))
	def.faction_id = int(d.get("faction_id", 1))
	def.is_commander_in_chief = bool(d.get("is_commander_in_chief", false))
	def.command_stat = int(d.get("command_stat", 20))
	def.luck = int(d.get("luck", 70))
	def.m_command = float(d.get("m_command", 1.15))

	var raw_profile: Variant = d.get("command_profile", {})
	if raw_profile is Dictionary:
		var prof: Dictionary = raw_profile as Dictionary
		def.infantry_mult = float(prof.get("Infantry", 1.0))
		def.archer_mult = float(prof.get("Archer", 1.0))
		def.cavalry_mult = float(prof.get("Cavalry", 1.0))
		def.naval_mult = float(prof.get("Naval", 1.0))

	var raw_aura: Variant = d.get("command_aura", {})
	if raw_aura is Dictionary:
		var aura: Dictionary = raw_aura as Dictionary
		def.aura_radius_hex = int(aura.get("radius_hex", 1))
		def.aura_damage_deepen = int(aura.get("damage_deepen", 0))
		def.aura_damage_resist = int(aura.get("damage_resist", 0))
		def.grants_dead_mate_immunity = bool(aura.get("dead_mate_immunity", false))

	var raw_skill: Variant = d.get("unique_skill", {})
	if raw_skill is Dictionary:
		var skill: Dictionary = raw_skill as Dictionary
		def.unique_skill_id = int(skill.get("skill_id", 0))
		def.unique_skill_name = str(skill.get("name", ""))
		def.unique_skill_cooldown = int(skill.get("cooldown", 3))
		def.unique_skill_range = int(skill.get("range", 2))
		def.unique_skill_aoe = int(skill.get("aoe", 1))

	def.modeling_type = str(d.get("modeling_type", "historical_claim"))
	def.source_ref = str(d.get("source_ref", ""))
	return def


## Serializes this GeneralDef to a dictionary matching general_settings.json structure.
func to_dict() -> Dictionary:
	return {
		"id": general_id,
		"code": code,
		"name": display_name,
		"faction_id": faction_id,
		"is_commander_in_chief": is_commander_in_chief,
		"command_stat": command_stat,
		"luck": luck,
		"m_command": m_command,
		"command_profile": {
			"Infantry": infantry_mult,
			"Archer": archer_mult,
			"Cavalry": cavalry_mult,
			"Naval": naval_mult,
		},
		"command_aura": {
			"radius_hex": aura_radius_hex,
			"damage_deepen": aura_damage_deepen,
			"damage_resist": aura_damage_resist,
			"dead_mate_immunity": grants_dead_mate_immunity,
		},
		"unique_skill": {
			"skill_id": unique_skill_id,
			"name": unique_skill_name,
			"cooldown": unique_skill_cooldown,
			"range": unique_skill_range,
			"aoe": unique_skill_aoe,
		},
		"modeling_type": modeling_type,
		"source_ref": source_ref,
	}
