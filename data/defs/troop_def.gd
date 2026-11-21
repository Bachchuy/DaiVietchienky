class_name TroopDef
extends Resource
## Static troop-type blueprint editable in the Godot Inspector (`res://data/defs/`).

@export_group("Identity")
@export var troop_id: int = 0
@export var code: String = ""
@export var display_name: String = ""
@export_enum("Land:0", "Naval:1") var domain: int = 0
@export_enum("Infantry:0", "Archer:1", "Cavalry:2", "Siege:3", "NavalLight:4", "NavalHeavy:5") var command_branch: int = 0

@export_group("Combat")
@export_enum("Melee:1", "Charge:2", "Ranged:3", "Siege:4", "Naval:5", "Fire:6") var attack_mode: int = 1
@export_enum("LightArmor:1", "MediumArmor:2", "HeavyArmor:3", "Beast:4", "Fort:5") var defense_mode: int = 2
@export_range(1, 9999) var base_hp: int = 160
@export_range(1, 3) var max_stack: int = 3
@export_range(0, 999) var min_attack: int = 30
@export_range(0, 999) var base_atk: int = 40
@export_range(0, 999) var base_def: int = 12
@export_range(50, 100) var damage_roll_min: int = 80
@export_range(80, 100) var damage_roll_max: int = 100
@export_range(0, 100) var critical_percent: int = 5
@export_range(0, 150) var counter_percent: int = 100
@export_range(1, 6) var min_range: int = 1
@export_range(1, 6) var max_range: int = 1

@export_group("Movement & Traits")
@export_range(1, 16) var mobility: int = 6
@export_range(1, 8) var vision_range: int = 3
@export_enum("None:-1", "Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var fond_terrain: int = -1
@export var ignore_zoc: bool = false
@export var ignore_coc: bool = false
@export var devoid_zoc: bool = false
@export var features: Array[StringName] = []

@export_group("Economy")
@export_range(0, 9999) var cost_coin: int = 40
@export_range(0, 9999) var cost_food: int = 50
@export_range(0, 999) var meal_food: int = 10

@export_group("Presentation")
@export var sprite_sheet: Texture2D
@export var unit_scene: PackedScene
@export var attack_sound: AudioStream


## Parses a raw domain value (string or int) into `0` (Land) or `1` (Naval).
static func parse_domain(raw: Variant) -> int:
	if raw is int or raw is float:
		return 1 if int(raw) == 1 else 0
	return 1 if str(raw).strip_edges().to_lower() in ["1", "naval"] else 0


## Parses a raw command branch value (string or int) into `0..5`.
static func parse_command_branch(raw: Variant) -> int:
	if raw is int or raw is float:
		return clampi(int(raw), 0, 5)
	match str(raw).strip_edges().to_lower():
		"0", "infantry":
			return 0
		"1", "archer", "archery", "ranged":
			return 1
		"2", "cavalry":
			return 2
		"3", "siege":
			return 3
		"4", "navallight", "naval_light":
			return 4
		"5", "navalheavy", "naval_heavy", "naval":
			return 5
		_:
			return 0


## Parses an attack mode value, matching BattleUnit's branch-aware legacy mapping.
static func parse_attack_mode(raw: Variant, branch: int) -> int:
	if raw is int or raw is float:
		return clampi(int(raw), 1, 6)
	match str(raw).strip_edges().to_lower():
		"1", "melee", "piercing":
			return 1
		"2", "charge", "slashing", "blunt":
			return 2 if branch == 2 else 1
		"3", "ranged", "archery":
			return 5 if (branch == 4 or branch == 5) else 3
		"4", "siege", "cannon":
			return 4
		"5", "naval":
			return 5
		"6", "fire":
			return 6
		_:
			match branch:
				2:
					return 2
				1:
					return 3
				3:
					return 4
				4, 5:
					return 5
				_:
					return 1


## Parses a defense mode value (string or int) into `1..5`.
static func parse_defense_mode(raw: Variant) -> int:
	if raw is int or raw is float:
		return clampi(int(raw), 1, 5)
	match str(raw).strip_edges().to_lower():
		"1", "light", "lightarmor", "light_armor":
			return 1
		"2", "medium", "mediumarmor", "medium_armor":
			return 2
		"3", "heavy", "heavyarmor", "heavy_armor":
			return 3
		"4", "beast", "elephant":
			return 4
		"5", "fort", "building":
			return 5
		_:
			return 2


## Parses a terrain identifier (string or int) into `-1` (None) or `0..8`.
static func parse_terrain_id(raw: Variant) -> int:
	if raw is int or raw is float:
		return clampi(int(raw), -1, 8)
	match str(raw).strip_edges().to_lower():
		"0", "plains":
			return 0
		"1", "forest":
			return 1
		"2", "hills":
			return 2
		"3", "swamp":
			return 3
		"4", "shallowriver", "shallow_river":
			return 4
		"5", "deepwater", "deep_water":
			return 5
		"6", "fort":
			return 6
		"7", "roadport", "road_port":
			return 7
		"8", "stakedwater", "staked_water":
			return 8
		_:
			return -1


## Returns the canonical string key for `domain`.
static func domain_to_name(domain_id: int) -> String:
	return "Naval" if domain_id == 1 else "Land"


## Returns the canonical string key for `command_branch`.
static func branch_to_name(branch_id: int) -> String:
	const BRANCH_NAMES: Array[String] = [
		"Infantry",
		"Archer",
		"Cavalry",
		"Siege",
		"NavalLight",
		"NavalHeavy",
	]
	return BRANCH_NAMES[clampi(branch_id, 0, BRANCH_NAMES.size() - 1)]


## Returns the canonical string key for `fond_terrain`, or `""` when `-1`.
static func terrain_to_name(terrain_id: int) -> String:
	if terrain_id < 0:
		return ""
	const TERRAIN_NAMES: Array[String] = [
		"Plains",
		"Forest",
		"Hills",
		"Swamp",
		"ShallowRiver",
		"DeepWater",
		"Fort",
		"RoadPort",
		"StakedWater",
	]
	return TERRAIN_NAMES[clampi(terrain_id, 0, TERRAIN_NAMES.size() - 1)]


## Constructs a TroopDef from a JSON-parsed troop dictionary.
static func from_dict(d: Dictionary) -> TroopDef:
	var def := TroopDef.new()
	def.troop_id = int(d.get("troop_id", d.get("id", 0)))
	def.code = str(d.get("code", ""))
	def.display_name = str(d.get("display_name", d.get("name", def.code)))
	def.domain = parse_domain(d.get("domain", "Land"))
	def.command_branch = parse_command_branch(d.get("command_branch", "Infantry"))
	def.attack_mode = parse_attack_mode(d.get("attack_mode", ""), def.command_branch)
	def.defense_mode = parse_defense_mode(d.get("defense_mode", "MediumArmor"))
	def.base_hp = int(d.get("base_hp", d.get("strength", 160)))
	def.max_stack = clampi(int(d.get("max_stack", 3)), 1, 3)
	def.min_attack = int(d.get("min_attack", 30))
	def.base_atk = int(d.get("base_atk", d.get("max_attack", 40)))
	def.base_def = int(d.get("base_def", d.get("defence", 12)))
	def.damage_roll_min = int(d.get("damage_roll_min", 80))
	def.damage_roll_max = int(d.get("damage_roll_max", 100))
	def.critical_percent = int(d.get("critical_percent", d.get("base_crit", 5)))
	def.counter_percent = int(d.get("counter_percent", 100))
	def.min_range = int(d.get("min_range", 1))
	def.max_range = int(d.get("max_range", 1))
	def.mobility = int(d.get("mobility", 6))
	def.vision_range = int(d.get("vision_range", 3))
	def.fond_terrain = parse_terrain_id(d.get("fond_terrain", -1))
	def.ignore_zoc = bool(d.get("ignore_zoc", false))
	def.ignore_coc = bool(d.get("ignore_coc", false))
	def.devoid_zoc = bool(d.get("devoid_zoc", false))
	def.cost_coin = int(d.get("cost_coin", 40))
	def.cost_food = int(d.get("cost_food", 50))
	def.meal_food = int(d.get("meal_food", 10))

	var feat_out: Array[StringName] = []
	var raw_features: Variant = d.get("features", [])
	if raw_features is Array:
		for feat: Variant in raw_features:
			feat_out.append(StringName(str(feat)))
	def.features = feat_out
	return def


## Converts this TroopDef into a dictionary compatible with BattleUnit.from_troop_dict() and BattleEconomy.
func to_troop_dict() -> Dictionary:
	var feat_list: Array[String] = []
	for feat: StringName in features:
		feat_list.append(str(feat))
	return {
		"id": troop_id,
		"code": code,
		"name": display_name,
		"domain": domain_to_name(domain),
		"command_branch": branch_to_name(command_branch),
		"attack_mode": attack_mode,
		"defense_mode": defense_mode,
		"min_attack": min_attack,
		"max_attack": base_atk,
		"base_atk": base_atk,
		"defence": base_def,
		"base_def": base_def,
		"damage_roll_min": damage_roll_min,
		"damage_roll_max": damage_roll_max,
		"strength": base_hp,
		"max_stack": max_stack,
		"mobility": mobility,
		"vision_range": vision_range,
		"min_range": min_range,
		"max_range": max_range,
		"critical_percent": critical_percent,
		"counter_percent": counter_percent,
		"fond_terrain": terrain_to_name(fond_terrain),
		"ignore_zoc": ignore_zoc,
		"ignore_coc": ignore_coc,
		"devoid_zoc": devoid_zoc,
		"features": feat_list,
		"cost_coin": cost_coin,
		"cost_food": cost_food,
		"meal_food": meal_food,
	}
