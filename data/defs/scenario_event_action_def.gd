class_name ScenarioEventActionDef
extends Resource
## Scripted action executed when a ScenarioEventDef triggers (`res://data/defs/`).

@export_enum("CameraFocus", "PlayDialogue", "AlterTerrain", "ApplyAreaEffect", "SpawnReinforcements", "ModifyMorale", "ResolveBattle") var action_type: String = "PlayDialogue"

@export_group("Camera & Dialogue")
@export var target_hex: Vector2i = Vector2i.ZERO
@export_range(0.0, 10.0, 0.1) var duration: float = 1.0
@export var dialogue_id: String = ""

@export_group("Terrain & Area Effect")
@export var area_id: String = ""
@export_enum("Plains:0", "Forest:1", "Hills:2", "Swamp:3", "ShallowRiver:4", "DeepWater:5", "Fort:6", "RoadPort:7", "StakedWater:8") var new_terrain: int = 8
@export var target_faction_id: int = -1
@export_range(0.0, 1.0, 0.05) var hp_loss_max_ratio: float = 0.35
@export_range(0, 10) var march_disabled_turns: int = 0
@export_range(0, 10) var chaos_turns: int = 0

@export_group("Reinforcements & Morale & Outcome")
@export var reinforcements: Array[UnitPlacementDef] = []
@export var faction_id: int = -1
@export_range(-3, 3) var morale_delta: int = 0
@export_enum("Ongoing:0", "Victory:1", "Defeat:2") var forced_outcome: int = 1


## Constructs a ScenarioEventActionDef from a JSON-parsed result dictionary.
static func from_dict(d: Dictionary) -> ScenarioEventActionDef:
	var def := ScenarioEventActionDef.new()
	def.action_type = str(d.get("action", "PlayDialogue"))
	var raw_hex: Variant = d.get("target_hex", {})
	if raw_hex is Dictionary:
		var hd: Dictionary = raw_hex as Dictionary
		def.target_hex = Vector2i(int(hd.get("q", hd.get("col", 0))), int(hd.get("r", hd.get("row", 0))))
	elif raw_hex is Vector2i:
		def.target_hex = raw_hex as Vector2i
	def.duration = float(d.get("duration", 1.0))
	def.dialogue_id = str(d.get("dialogue_id", ""))
	def.area_id = str(d.get("area_id", ""))
	var parsed_terrain: int = TroopDef.parse_terrain_id(d.get("new_terrain", "StakedWater"))
	def.new_terrain = maxi(0, parsed_terrain)
	def.target_faction_id = int(d.get("target_faction_id", -1))
	def.hp_loss_max_ratio = float(d.get("hp_loss_max_ratio", 0.35))
	def.march_disabled_turns = int(d.get("march_disabled_turns", 0))
	def.chaos_turns = int(d.get("chaos_turns", 0))
	def.faction_id = int(d.get("faction_id", -1))
	def.morale_delta = int(d.get("delta", 0))
	def.forced_outcome = clampi(int(d.get("outcome", 1)), 0, 2)

	var spawned: Array[UnitPlacementDef] = []
	var raw_placements: Variant = d.get("placements", [])
	if raw_placements is Array:
		for p_var: Variant in raw_placements:
			if p_var is Dictionary:
				spawned.append(UnitPlacementDef.from_dict(p_var as Dictionary))
	def.reinforcements = spawned
	return def


## Serializes this action to a dictionary compatible with ScenarioEventManager._execute_results().
func to_dict() -> Dictionary:
	var out: Dictionary = {"action": action_type}
	match action_type:
		"CameraFocus":
			out["target_hex"] = {"q": target_hex.x, "r": target_hex.y}
			out["duration"] = duration
		"PlayDialogue":
			out["dialogue_id"] = dialogue_id
		"AlterTerrain":
			out["area_id"] = area_id
			out["new_terrain"] = TroopDef.terrain_to_name(new_terrain)
		"ApplyAreaEffect":
			out["area_id"] = area_id
			out["target_faction_id"] = target_faction_id
			out["hp_loss_max_ratio"] = hp_loss_max_ratio
			out["march_disabled_turns"] = march_disabled_turns
			out["chaos_turns"] = chaos_turns
		"SpawnReinforcements":
			var p_dicts: Array[Dictionary] = []
			for p: UnitPlacementDef in reinforcements:
				if p != null:
					p_dicts.append(p.to_dict())
			out["placements"] = p_dicts
		"ModifyMorale":
			out["faction_id"] = faction_id
			out["delta"] = morale_delta
			if not area_id.is_empty():
				out["area_id"] = area_id
		"ResolveBattle":
			out["outcome"] = forced_outcome
		_:
			pass
	return out
