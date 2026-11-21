class_name ScenarioDirector
extends RefCounted

## Public tactical objectives & named map areas shared with AI ObjectiveEvaluator and ScenarioEventManager.
## Hidden traps/stakes MUST NOT be exposed here before they are revealed on BattleMapState.
var _named_areas: Dictionary[String, Array] = {}
var area_owners: Dictionary[String, int] = {}
var primary_objective_area_ids: Array[String] = []
var target_general_ids: Dictionary[int, Array] = {}
var protect_general_ids: Dictionary[int, Array] = {}


func register_area(
	area_id: String,
	hexes: Array,
	initial_owner: int = 0,
	is_objective: bool = false
) -> void:
	var copy: Array[Vector2i] = []
	for h: Variant in hexes:
		if h is Vector2i:
			copy.append(h as Vector2i)
	_named_areas[area_id] = copy
	area_owners[area_id] = initial_owner
	if is_objective and not primary_objective_area_ids.has(area_id):
		primary_objective_area_ids.append(area_id)


func get_area_hexes(area_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _named_areas.has(area_id):
		return out
	var raw: Array = _named_areas[area_id]
	for item: Variant in raw:
		if item is Vector2i:
			out.append(item)
	return out


func set_area_owner(area_id: String, faction_id: int) -> void:
	if _named_areas.has(area_id):
		area_owners[area_id] = faction_id


func get_area_owner(area_id: String) -> int:
	return int(area_owners.get(area_id, 0))


func find_areas_containing_hex(axial: Vector2i) -> Array[String]:
	var matched: Array[String] = []
	for area_id: String in _named_areas.keys():
		var list: Array = _named_areas[area_id]
		if list.has(axial):
			matched.append(area_id)
	return matched


func get_objective_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for area_id: String in primary_objective_area_ids:
		for h: Vector2i in get_area_hexes(area_id):
			if not out.has(h):
				out.append(h)
	return out


func set_target_generals(faction_id: int, general_ids: Array) -> void:
	var copy: Array[int] = []
	for gid: Variant in general_ids:
		copy.append(int(gid))
	target_general_ids[faction_id] = copy


func set_protected_generals(faction_id: int, general_ids: Array) -> void:
	var copy: Array[int] = []
	for gid: Variant in general_ids:
		copy.append(int(gid))
	protect_general_ids[faction_id] = copy


func is_target_general_for(faction_id: int, general_id: int) -> bool:
	if general_id <= 0 or not target_general_ids.has(faction_id):
		return false
	return (target_general_ids[faction_id] as Array).has(general_id)


func is_protected_general_for(faction_id: int, general_id: int) -> bool:
	if general_id <= 0 or not protect_general_ids.has(faction_id):
		return false
	return (protect_general_ids[faction_id] as Array).has(general_id)
