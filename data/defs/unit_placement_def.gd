class_name UnitPlacementDef
extends Resource
## Initial or reinforcement unit placement on a battle stage (`res://data/defs/`).

@export_group("Unit")
@export var unit_id: int = 0
@export var faction_id: int = 1
@export var troop_id: int = 40101
@export_range(1, 3) var troop_stack: int = 1
@export var hex_pos: Vector2i = Vector2i.ZERO
@export var display_name_override: String = ""
@export_range(0, 5) var facing: int = 0
@export_enum("CHAOS", "LOW", "NORMAL", "HIGH") var initial_morale: String = "NORMAL"
@export var is_invisible: bool = false
@export var is_morale_locked: bool = false
@export_enum("None:-1", "Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var fond_terrain_override: int = -1
@export var max_hp_override: int = 0
@export var current_hp_override: int = 0

@export_group("Commander")
@export var general_id: int = 0
@export var general_name: String = ""
@export var is_commander_in_chief: bool = false
@export_range(0, 100) var general_command_stat: int = 0
@export_range(0, 100) var general_luck: int = 0
@export_range(0.5, 2.0, 0.01) var m_command: float = 1.0
@export_range(0, 6) var aura_radius_hex: int = 0
@export_range(0, 100) var aura_damage_deepen: int = 0
@export_range(0, 100) var aura_damage_resist: int = 0
@export var grants_dead_mate_immunity: bool = false

@export_group("Historical Metadata")
@export_enum("historical_claim", "fixture", "abstraction", "what_if") var modeling_type: String = "fixture"
@export_multiline var source_ref: String = ""


static func _parse_hex(raw: Variant) -> Vector2i:
	if raw is Vector2i:
		return raw as Vector2i
	if raw is Dictionary:
		var hd: Dictionary = raw as Dictionary
		return Vector2i(int(hd.get("q", hd.get("col", 0))), int(hd.get("r", hd.get("row", 0))))
	return Vector2i.ZERO


## Constructs a UnitPlacementDef from a JSON-parsed placement dictionary.
static func from_dict(d: Dictionary) -> UnitPlacementDef:
	var def := UnitPlacementDef.new()
	def.unit_id = int(d.get("unit_id", 0))
	def.faction_id = int(d.get("faction_id", 1))
	def.troop_id = int(d.get("troop_id", 40101))
	def.troop_stack = clampi(int(d.get("troop_stack", d.get("max_stack", 1))), 1, 3)
	def.hex_pos = _parse_hex(d.get("hex", d.get("hex_pos", Vector2i.ZERO)))
	def.display_name_override = str(d.get("name", ""))
	def.facing = clampi(int(d.get("facing", 0)), 0, 5)
	var morale_raw: String = str(d.get("initial_morale", "NORMAL")).strip_edges().to_upper()
	def.initial_morale = morale_raw if morale_raw in ["CHAOS", "LOW", "NORMAL", "HIGH"] else "NORMAL"
	def.is_invisible = bool(d.get("is_invisible", false))
	def.is_morale_locked = bool(d.get("is_morale_locked", false))
	def.fond_terrain_override = TroopDef.parse_terrain_id(d.get("fond_terrain", -1))
	def.max_hp_override = int(d.get("max_hp", 0))
	def.current_hp_override = int(d.get("current_hp", 0))

	def.general_id = int(d.get("general_id", 0))
	def.general_name = str(d.get("general_name", ""))
	def.is_commander_in_chief = bool(d.get("is_commander_in_chief", false))
	def.general_command_stat = int(d.get("general_command_stat", 0))
	def.general_luck = int(d.get("general_luck", 0))
	def.m_command = float(d.get("m_command", 1.0))
	def.aura_radius_hex = int(d.get("aura_radius_hex", 0))
	def.aura_damage_deepen = int(d.get("aura_damage_deepen", 0))
	def.aura_damage_resist = int(d.get("aura_damage_resist", 0))
	def.grants_dead_mate_immunity = bool(d.get("grants_dead_mate_immunity", false))

	var m_type: String = str(d.get("modeling_type", "fixture"))
	def.modeling_type = m_type if m_type in ["historical_claim", "fixture", "abstraction", "what_if"] else "fixture"
	def.source_ref = str(d.get("source_ref", ""))
	return def


## Serializes this UnitPlacementDef to a dictionary compatible with BattleContext.spawn_unit_from_placement().
func to_dict() -> Dictionary:
	var out: Dictionary = {
		"unit_id": unit_id,
		"faction_id": faction_id,
		"troop_id": troop_id,
		"troop_stack": troop_stack,
		"hex": {"q": hex_pos.x, "r": hex_pos.y},
		"facing": facing,
		"initial_morale": initial_morale,
		"is_invisible": is_invisible,
		"is_morale_locked": is_morale_locked,
		"modeling_type": modeling_type,
		"source_ref": source_ref,
	}
	if not display_name_override.is_empty():
		out["name"] = display_name_override
	if fond_terrain_override >= 0:
		out["fond_terrain"] = TroopDef.terrain_to_name(fond_terrain_override)
	if max_hp_override > 0:
		out["max_hp"] = max_hp_override
	if current_hp_override > 0:
		out["current_hp"] = current_hp_override
	if general_id > 0 or not general_name.is_empty() or is_commander_in_chief:
		out["general_id"] = general_id
		out["general_name"] = general_name
		out["is_commander_in_chief"] = is_commander_in_chief
		out["general_command_stat"] = general_command_stat
		out["general_luck"] = general_luck
		out["m_command"] = m_command
		out["aura_radius_hex"] = aura_radius_hex
		out["aura_damage_deepen"] = aura_damage_deepen
		out["aura_damage_resist"] = aura_damage_resist
		out["grants_dead_mate_immunity"] = grants_dead_mate_immunity
	return out
