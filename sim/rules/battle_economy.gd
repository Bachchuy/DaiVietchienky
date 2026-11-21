class_name BattleEconomy
extends RefCounted

const RobAreaIncomeCommand = BattleEconomyCommands.RobAreaIncomeCommand
const TradeCommand = BattleEconomyCommands.TradeCommand
const UpgradeFacilityCommand = BattleEconomyCommands.UpgradeFacilityCommand
const FortifyHexCommand = BattleEconomyCommands.FortifyHexCommand
const UnlockBattleTechCommand = BattleEconomyCommands.UnlockBattleTechCommand
const RecruitCommand = BattleEconomyCommands.RecruitCommand
const ApplyTacticCommand = BattleEconomyCommands.ApplyTacticCommand

const BASE_FOOD_CAP: int = 1000
const GRANARY_CAP_PER_LEVEL: int = 500

var _factions: Dictionary = {}
var _facilities: Dictionary = {}
var _next_recruit_unit_id: int = 800


func init_faction(
	faction_id: int,
	coin: int = 200,
	food: int = 200,
	tech: int = 100,
	mana: int = 50
) -> void:
	_factions[faction_id] = {
		"coin": maxi(0, coin),
		"food": food,
		"tech": maxi(0, tech),
		"mana": maxi(0, mana),
		"unlocked_techs": {
			"INFANTRY": 0,
			"ARCHER": 0,
			"CAVALRY": 0,
			"NAVAL": 0,
			"SIEGE": 0,
		},
	}


func _ensure_faction(faction_id: int) -> Dictionary:
	if not _factions.has(faction_id):
		init_faction(faction_id, 0, 0, 0, 0)
	return _factions[faction_id] as Dictionary


func get_resource(faction_id: int, res_key: String) -> int:
	var fd: Dictionary = _ensure_faction(faction_id)
	return int(fd.get(res_key.to_lower(), 0))


func set_resource(faction_id: int, res_key: String, amount: int) -> void:
	var fd: Dictionary = _ensure_faction(faction_id)
	var k: String = res_key.to_lower()
	if k == "food":
		var cap: int = get_food_cap(faction_id)
		fd[k] = mini(amount, cap) if amount > 0 else amount
	else:
		fd[k] = maxi(0, amount)


func add_resource(faction_id: int, res_key: String, delta: int) -> int:
	var cur: int = get_resource(faction_id, res_key)
	var next_val: int = cur + delta
	var k: String = res_key.to_lower()
	if k == "food":
		if delta > 0:
			next_val = mini(next_val, get_food_cap(faction_id))
		var fd: Dictionary = _ensure_faction(faction_id)
		fd[k] = next_val
		return next_val
	set_resource(faction_id, k, next_val)
	return get_resource(faction_id, k)


func get_food_cap(faction_id: int) -> int:
	var cap: int = BASE_FOOD_CAP
	for fac_id_str: String in _facilities.keys():
		var fac: Dictionary = _facilities[fac_id_str] as Dictionary
		if int(fac.get("owner", 0)) == faction_id and str(fac.get("type", "")) == "Granary":
			var lvl: int = clampi(int(fac.get("level", 1)), 1, 3)
			cap += GRANARY_CAP_PER_LEVEL * lvl
	return cap


func register_facility(
	facility_id: String,
	owner_faction: int,
	facility_type: String,
	level: int = 1,
	turns_unrobbed: int = 1,
	has_granary_protection: bool = false,
	hex_pos: Vector2i = Vector2i(-1, -1)
) -> void:
	_facilities[facility_id] = {
		"id": facility_id,
		"owner": owner_faction,
		"type": facility_type,
		"level": clampi(level, 1, 3),
		"turns_unrobbed": clampi(turns_unrobbed, 0, 7),
		"has_granary": has_granary_protection,
		"q": hex_pos.x,
		"r": hex_pos.y,
	}


func get_facility(facility_id: String) -> Dictionary:
	return _facilities.get(facility_id, {}) as Dictionary


func has_facility_of_type(faction_id: int, facility_type: String) -> bool:
	var target_low: String = facility_type.to_lower()
	for fid: String in _facilities.keys():
		var fac: Dictionary = _facilities[fid] as Dictionary
		if int(fac.get("owner", 0)) == faction_id and str(fac.get("type", "")).to_lower() == target_low:
			return true
	return false


func try_upgrade_facility(faction_id: int, facility_id: String) -> bool:
	if not _facilities.has(facility_id):
		return false
	var fac: Dictionary = _facilities[facility_id] as Dictionary
	if int(fac.get("owner", 0)) != faction_id:
		return false
	var cur_lvl: int = int(fac.get("level", 1))
	if cur_lvl >= 3:
		return false
	var coin_cost: int = 120 * cur_lvl
	var tech_cost: int = 30 * cur_lvl
	if get_resource(faction_id, "coin") < coin_cost or get_resource(faction_id, "tech") < tech_cost:
		return false
	add_resource(faction_id, "coin", -coin_cost)
	add_resource(faction_id, "tech", -tech_cost)
	fac["level"] = cur_lvl + 1
	return true


func compute_unit_meal_food(unit: BattleUnit) -> int:
	if unit == null:
		return 0
	var stack: int = clampi(unit.max_stack, 1, 3)
	var base_meal: int = 10
	if unit.features.has("elephant") or unit.troop_id == 40104:
		base_meal = 30
	elif unit.command_branch == BattleUnit.CommandBranch.CAVALRY:
		base_meal = 20
	elif unit.command_branch == BattleUnit.CommandBranch.NAVAL_HEAVY or unit.command_branch == BattleUnit.CommandBranch.SIEGE:
		base_meal = 20
	elif unit.command_branch == BattleUnit.CommandBranch.NAVAL_LIGHT:
		base_meal = 15
	return base_meal * stack


func compute_faction_total_meal_food(faction_id: int, map_state: BattleMapState) -> int:
	if map_state == null:
		return 0
	var total: int = 0
	for u: BattleUnit in map_state.get_all_units():
		if u.faction_id == faction_id and u.state.is_alive():
			total += compute_unit_meal_food(u)
	return total


func process_begin_round(faction_id: int, map_state: BattleMapState) -> Dictionary:
	_ensure_faction(faction_id)
	var food_gain: int = 0
	var coin_gain: int = 0
	var tech_gain: int = 0
	var mana_gain: int = 0

	for fid: String in _facilities.keys():
		var fac: Dictionary = _facilities[fid] as Dictionary
		if int(fac.get("owner", 0)) != faction_id:
			continue
		var lvl: int = clampi(int(fac.get("level", 1)), 1, 3)
		var f_type: String = str(fac.get("type", ""))
		match f_type:
			"Farm":
				food_gain += 40 + 40 * lvl
			"Market":
				coin_gain += 30 + 30 * lvl
			"Mine":
				coin_gain += 15 + 15 * lvl
				tech_gain += 10 + 15 * lvl
			"Temple":
				mana_gain += 10 + 15 * lvl
			"Academy":
				tech_gain += 5 + 15 * lvl
		fac["turns_unrobbed"] = mini(3, int(fac.get("turns_unrobbed", 0)) + 1)

	if coin_gain > 0:
		add_resource(faction_id, "coin", coin_gain)
	if tech_gain > 0:
		add_resource(faction_id, "tech", tech_gain)
	if mana_gain > 0:
		add_resource(faction_id, "mana", mana_gain)
	if food_gain > 0:
		add_resource(faction_id, "food", food_gain)

	var total_meal: int = compute_faction_total_meal_food(faction_id, map_state)
	add_resource(faction_id, "food", -total_meal)

	if is_starving(faction_id):
		apply_starvation_effects(faction_id, map_state)

	return {
		"coin_gain": coin_gain,
		"food_gain": food_gain,
		"tech_gain": tech_gain,
		"mana_gain": mana_gain,
		"meal_consumed": total_meal,
		"is_starving": is_starving(faction_id),
	}


func is_starving(faction_id: int) -> bool:
	return get_resource(faction_id, "food") < 0


func get_combat_damage_multiplier(faction_id: int) -> float:
	return 0.75 if is_starving(faction_id) else 1.0


func can_heal_unit(faction_id: int) -> bool:
	return not is_starving(faction_id)


func apply_starvation_effects(faction_id: int, map_state: BattleMapState) -> void:
	if not is_starving(faction_id) or map_state == null:
		return
	for u: BattleUnit in map_state.get_all_units():
		if u.faction_id != faction_id or not u.state.is_alive():
			continue
		if u.state.morale == UnitCombatState.MoraleLevel.HIGH:
			u.state.morale = UnitCombatState.MoraleLevel.NORMAL
		elif u.state.morale == UnitCombatState.MoraleLevel.NORMAL:
			u.state.morale = UnitCombatState.MoraleLevel.LOW
		# LOW floors at LOW — Starvation NEVER drops morale to CHAOS


func rob_facility(
	raider_faction: int,
	facility_id: String,
	rob_efficiency: float = 0.80
) -> int:
	if not _facilities.has(facility_id):
		return 0
	var fac: Dictionary = _facilities[facility_id] as Dictionary
	var owner_id: int = int(fac.get("owner", 0))
	if owner_id == raider_faction:
		return 0
	var turns_acc: int = clampi(int(fac.get("turns_unrobbed", 0)), 0, 3)
	if turns_acc <= 0:
		return 0

	var lvl: int = clampi(int(fac.get("level", 1)), 1, 3)
	var f_type: String = str(fac.get("type", "Farm"))
	var base_per_turn: int = 80
	var res_key: String = "food"
	match f_type:
		"Farm":
			base_per_turn = 40 + 40 * lvl
			res_key = "food"
		"Market":
			base_per_turn = 30 + 30 * lvl
			res_key = "coin"
		"Mine":
			base_per_turn = 15 + 15 * lvl
			res_key = "coin"
		"Temple":
			base_per_turn = 10 + 15 * lvl
			res_key = "mana"
		_:
			base_per_turn = 40 + 40 * lvl
			res_key = "food"

	var has_granary: bool = bool(fac.get("has_granary", false)) or has_facility_of_type(owner_id, "Granary")
	var granary_mult: float = 0.50 if has_granary else 1.00
	var gained: int = CombatResolver.round_half_up(float(base_per_turn * turns_acc) * rob_efficiency * granary_mult)
	fac["turns_unrobbed"] = 0
	if gained > 0:
		add_resource(raider_faction, res_key, gained)
	return gained


func get_unlocked_tech_tier(faction_id: int, branch: String) -> int:
	var fd: Dictionary = _ensure_faction(faction_id)
	var techs: Dictionary = fd.get("unlocked_techs", {}) as Dictionary
	return int(techs.get(branch.to_upper(), 0))


func set_unlocked_tech_tier(faction_id: int, branch: String, tier: int) -> void:
	var fd: Dictionary = _ensure_faction(faction_id)
	var techs: Dictionary = fd.get("unlocked_techs", {}) as Dictionary
	techs[branch.to_upper()] = tier
	fd["unlocked_techs"] = techs


func allocate_recruit_unit_id(map_state: BattleMapState) -> int:
	if map_state != null:
		for u: BattleUnit in map_state.get_all_units():
			if u.unit_id >= _next_recruit_unit_id:
				_next_recruit_unit_id = u.unit_id + 1
	var assigned: int = _next_recruit_unit_id
	_next_recruit_unit_id += 1
	return assigned


func to_dict() -> Dictionary:
	var fac_out: Dictionary = {}
	for k: Variant in _factions.keys():
		fac_out[str(k)] = (_factions[k] as Dictionary).duplicate(true)
	return {
		"factions": fac_out,
		"facilities": _facilities.duplicate(true),
		"next_recruit_unit_id": _next_recruit_unit_id,
	}


func from_dict(data: Dictionary) -> void:
	_factions.clear()
	var fac_in: Variant = data.get("factions", {})
	if fac_in is Dictionary:
		for k_str: Variant in (fac_in as Dictionary).keys():
			var fid: int = int(str(k_str))
			var sub: Variant = (fac_in as Dictionary)[k_str]
			if sub is Dictionary:
				_factions[fid] = (sub as Dictionary).duplicate(true)
	var fac_map: Variant = data.get("facilities", {})
	if fac_map is Dictionary:
		_facilities = (fac_map as Dictionary).duplicate(true)
	_next_recruit_unit_id = int(data.get("next_recruit_unit_id", 800))
