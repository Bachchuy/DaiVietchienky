class_name BattleEconomy
extends RefCounted

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
	else:
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
	else:
		base_meal = 10
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


# ===========================================================================
# 7 Deterministic Economy Commands (non-undoable)
# ===========================================================================

class RobAreaIncomeCommand extends BattleCommands.BaseCommand:
	var facility_id: String = ""
	var efficiency: float = 0.80

	func _init(p_faction: int = 0, p_facility_id: String = "", p_efficiency: float = 0.80) -> void:
		faction_id = p_faction
		facility_id = p_facility_id
		efficiency = p_efficiency

	func get_command_type() -> String:
		return "RobAreaIncome"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null:
			return false
		var eco: BattleEconomy = ctx.economy as BattleEconomy
		var gained: int = eco.rob_facility(faction_id, facility_id, efficiency)
		return gained > 0

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["facility_id"] = facility_id
		d["efficiency"] = efficiency
		return d


class TradeCommand extends BattleCommands.BaseCommand:
	var trade_mode: String = "coin_to_food"
	var amount: int = 100

	func _init(p_faction: int = 0, p_mode: String = "coin_to_food", p_amount: int = 100) -> void:
		faction_id = p_faction
		trade_mode = p_mode
		amount = p_amount

	func get_command_type() -> String:
		return "Trade"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null or amount <= 0:
			return false
		var eco: BattleEconomy = ctx.economy as BattleEconomy
		if not eco.has_facility_of_type(faction_id, "Market"):
			return false

		if trade_mode == "coin_to_food":
			var cur_coin: int = eco.get_resource(faction_id, "coin")
			if cur_coin < amount:
				return false
			var starving: bool = eco.is_starving(faction_id)
			var rate: float = 0.375 if starving else 0.75
			var gained_food: int = CombatResolver.round_half_up(float(amount) * rate)
			eco.add_resource(faction_id, "coin", -amount)
			eco.add_resource(faction_id, "food", gained_food)
			return true
		elif trade_mode == "food_to_coin":
			if eco.is_starving(faction_id):
				return false
			var cur_food: int = eco.get_resource(faction_id, "food")
			if cur_food < amount:
				return false
			var gained_coin: int = CombatResolver.round_half_up(float(amount) * 0.60)
			eco.add_resource(faction_id, "food", -amount)
			eco.add_resource(faction_id, "coin", gained_coin)
			return true
		return false

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["trade_mode"] = trade_mode
		d["amount"] = amount
		return d


class UpgradeFacilityCommand extends BattleCommands.BaseCommand:
	var facility_id: String = ""

	func _init(p_faction: int = 0, p_facility_id: String = "") -> void:
		faction_id = p_faction
		facility_id = p_facility_id

	func get_command_type() -> String:
		return "UpgradeFacility"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null:
			return false
		var eco: BattleEconomy = ctx.economy as BattleEconomy
		if not eco._facilities.has(facility_id):
			return false
		var fac: Dictionary = eco._facilities[facility_id] as Dictionary
		if int(fac.get("owner", 0)) != faction_id:
			return false
		var cur_lvl: int = int(fac.get("level", 1))
		if cur_lvl >= 3:
			return false
		var coin_cost: int = 120 * cur_lvl
		var tech_cost: int = 30 * cur_lvl
		if eco.get_resource(faction_id, "coin") < coin_cost or eco.get_resource(faction_id, "tech") < tech_cost:
			return false
		eco.add_resource(faction_id, "coin", -coin_cost)
		eco.add_resource(faction_id, "tech", -tech_cost)
		fac["level"] = cur_lvl + 1
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["facility_id"] = facility_id
		return d


class FortifyHexCommand extends BattleCommands.BaseCommand:
	var target_hex: Vector2i = Vector2i.ZERO

	func _init(p_faction: int = 0, p_target_hex: Vector2i = Vector2i.ZERO) -> void:
		faction_id = p_faction
		target_hex = p_target_hex

	func get_command_type() -> String:
		return "FortifyHex"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null or ctx.map_state == null:
			return false
		if not ctx.map_state.is_valid_hex(target_hex):
			return false
		var t: BattleMapState.TerrainType = ctx.map_state.get_terrain(target_hex)
		if t == BattleMapState.TerrainType.DEEP_WATER or t == BattleMapState.TerrainType.STAKED_WATER:
			return false
		var eco: BattleEconomy = ctx.economy as BattleEconomy
		var coin_cost: int = 100
		var tech_cost: int = 40
		if eco.get_resource(faction_id, "coin") < coin_cost or eco.get_resource(faction_id, "tech") < tech_cost:
			return false
		eco.add_resource(faction_id, "coin", -coin_cost)
		eco.add_resource(faction_id, "tech", -tech_cost)
		ctx.map_state.set_terrain(target_hex, BattleMapState.TerrainType.FORT)
		ctx.map_state.set_fort_owner(target_hex, faction_id)
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["target_hex"] = {"q": target_hex.x, "r": target_hex.y}
		return d


class UnlockBattleTechCommand extends BattleCommands.BaseCommand:
	var tier: int = 1
	var branch: String = "INFANTRY"
	var era: String = "Tran_Nguyen"

	func _init(
		p_faction: int = 0,
		p_tier: int = 1,
		p_branch: String = "INFANTRY",
		p_era: String = "Tran_Nguyen"
	) -> void:
		faction_id = p_faction
		tier = p_tier
		branch = p_branch.to_upper()
		era = p_era

	func get_command_type() -> String:
		return "UnlockBattleTech"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null:
			return false
		if tier < 1 or tier > 3:
			return false
		if branch.contains("GUNPOWDER") and (era.to_lower().contains("tran") or era.contains("1288")):
			return false
		var eco: BattleEconomy = ctx.economy as BattleEconomy
		var cur_tier: int = eco.get_unlocked_tech_tier(faction_id, branch)
		if cur_tier != tier - 1:
			return false
		var coin_cost: int = 80 * tier
		var tech_cost: int = 50 * tier
		if eco.get_resource(faction_id, "coin") < coin_cost or eco.get_resource(faction_id, "tech") < tech_cost:
			return false
		eco.add_resource(faction_id, "coin", -coin_cost)
		eco.add_resource(faction_id, "tech", -tech_cost)
		var fd: Dictionary = eco._ensure_faction(faction_id)
		var techs: Dictionary = fd.get("unlocked_techs", {}) as Dictionary
		techs[branch] = tier
		fd["unlocked_techs"] = techs
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["tier"] = tier
		d["branch"] = branch
		d["era"] = era
		return d


class RecruitCommand extends BattleCommands.BaseCommand:
	var troop_id: int = 40101
	var stack: int = 1
	var spawn_hex: Vector2i = Vector2i.ZERO

	func _init(
		p_faction: int = 0,
		p_troop_id: int = 40101,
		p_stack: int = 1,
		p_spawn_hex: Vector2i = Vector2i.ZERO
	) -> void:
		faction_id = p_faction
		troop_id = p_troop_id
		stack = clampi(p_stack, 1, 3)
		spawn_hex = p_spawn_hex

	func get_command_type() -> String:
		return "Recruit"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null or ctx.map_state == null:
			return false
		var ms: BattleMapState = ctx.map_state
		if not ms.is_valid_hex(spawn_hex):
			return false
		if ms.get_terrain(spawn_hex) != BattleMapState.TerrainType.FORT:
			return false
		if ms.get_fort_owner(spawn_hex) != faction_id:
			return false
		if ms.get_unit_at(spawn_hex) != null:
			return false

		var eco: BattleEconomy = ctx.economy as BattleEconomy
		var coin_cost: int = 80 * stack
		var food_cost: int = 60 * stack
		if eco.get_resource(faction_id, "coin") < coin_cost or eco.get_resource(faction_id, "food") < food_cost:
			return false

		var t_defs: Dictionary[int, Dictionary] = StaticDataLoader.load_troop_settings()
		var t_dict: Dictionary = t_defs.get(troop_id, {
			"id": troop_id,
			"name": "Quân Chi Viện",
			"command_branch": "Infantry",
			"strength": 160,
			"base_atk": 28,
			"base_def": 20,
			"mobility": 6,
		})
		var new_uid: int = eco.allocate_recruit_unit_id(ms)
		var new_unit: BattleUnit = BattleUnit.from_troop_dict(new_uid, faction_id, spawn_hex, t_dict)
		new_unit.max_stack = stack
		new_unit.troop_stack = stack
		new_unit.state.max_hp = new_unit.base_hp * stack
		new_unit.state.current_hp = new_unit.state.max_hp
		new_unit.state.has_acted = true
		if not ms.place_unit(new_unit):
			return false

		eco.add_resource(faction_id, "coin", -coin_cost)
		eco.add_resource(faction_id, "food", -food_cost)
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["troop_id"] = troop_id
		d["stack"] = stack
		d["spawn_hex"] = {"q": spawn_hex.x, "r": spawn_hex.y}
		return d


class ApplyTacticCommand extends BattleCommands.BaseCommand:
	var tactic_id: String = "forced_march"
	var target_unit_id: int = 0

	func _init(p_faction: int = 0, p_tactic_id: String = "forced_march", p_target_unit_id: int = 0) -> void:
		faction_id = p_faction
		tactic_id = p_tactic_id
		target_unit_id = p_target_unit_id

	func get_command_type() -> String:
		return "ApplyTactic"

	func execute(ctx: BattleContext) -> bool:
		if ctx == null or ctx.economy == null:
			return false
		var unit: BattleUnit = ctx.get_unit(target_unit_id)
		if unit == null or unit.faction_id != faction_id or not unit.state.is_alive():
			return false
		var eco: BattleEconomy = ctx.economy as BattleEconomy
		var mana_cost: int = 40
		if eco.get_resource(faction_id, "mana") < mana_cost:
			return false
		eco.add_resource(faction_id, "mana", -mana_cost)

		match tactic_id:
			"forced_march":
				unit.state.current_mp += 2
			"inspire":
				unit.state.shift_morale(1)
			_:
				unit.state.current_mp += 1
		# ApplyTactic consumes faction mana and leaves unit available for action / CastSkill
		return true

	func to_dict() -> Dictionary:
		var d: Dictionary = super.to_dict()
		d["tactic_id"] = tactic_id
		d["target_unit_id"] = target_unit_id
		return d
