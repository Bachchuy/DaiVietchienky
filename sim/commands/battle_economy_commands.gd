class_name BattleEconomyCommands
extends RefCounted


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
		var eco: Object = ctx.economy
		var gained: int = int(eco.call("rob_facility", faction_id, facility_id, efficiency))
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
		var eco: Object = ctx.economy
		if not bool(eco.call("has_facility_of_type", faction_id, "Market")):
			return false

		if trade_mode == "coin_to_food":
			var cur_coin: int = int(eco.call("get_resource", faction_id, "coin"))
			if cur_coin < amount:
				return false
			var starving: bool = bool(eco.call("is_starving", faction_id))
			var rate: float = 0.375 if starving else 0.75
			var gained_food: int = CombatResolver.round_half_up(float(amount) * rate)
			eco.call("add_resource", faction_id, "coin", -amount)
			eco.call("add_resource", faction_id, "food", gained_food)
			return true
		elif trade_mode == "food_to_coin":
			if bool(eco.call("is_starving", faction_id)):
				return false
			var cur_food: int = int(eco.call("get_resource", faction_id, "food"))
			if cur_food < amount:
				return false
			var gained_coin: int = CombatResolver.round_half_up(float(amount) * 0.60)
			eco.call("add_resource", faction_id, "food", -amount)
			eco.call("add_resource", faction_id, "coin", gained_coin)
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
		var eco: Object = ctx.economy
		return bool(eco.call("try_upgrade_facility", faction_id, facility_id))

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
		var eco: Object = ctx.economy
		var coin_cost: int = 100
		var tech_cost: int = 40
		if int(eco.call("get_resource", faction_id, "coin")) < coin_cost or int(eco.call("get_resource", faction_id, "tech")) < tech_cost:
			return false
		eco.call("add_resource", faction_id, "coin", -coin_cost)
		eco.call("add_resource", faction_id, "tech", -tech_cost)
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
		var eco: Object = ctx.economy
		var cur_tier: int = int(eco.call("get_unlocked_tech_tier", faction_id, branch))
		if cur_tier != tier - 1:
			return false
		var coin_cost: int = 80 * tier
		var tech_cost: int = 50 * tier
		if int(eco.call("get_resource", faction_id, "coin")) < coin_cost or int(eco.call("get_resource", faction_id, "tech")) < tech_cost:
			return false
		eco.call("add_resource", faction_id, "coin", -coin_cost)
		eco.call("add_resource", faction_id, "tech", -tech_cost)
		eco.call("set_unlocked_tech_tier", faction_id, branch, tier)
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

		var eco: Object = ctx.economy
		var coin_cost: int = 80 * stack
		var food_cost: int = 60 * stack
		if int(eco.call("get_resource", faction_id, "coin")) < coin_cost or int(eco.call("get_resource", faction_id, "food")) < food_cost:
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
		var new_uid: int = int(eco.call("allocate_recruit_unit_id", ms))
		var new_unit: BattleUnit = BattleUnit.from_troop_dict(new_uid, faction_id, spawn_hex, t_dict)
		new_unit.max_stack = stack
		new_unit.troop_stack = stack
		new_unit.state.max_hp = new_unit.base_hp * stack
		new_unit.state.current_hp = new_unit.state.max_hp
		new_unit.state.has_acted = true
		if not ms.place_unit(new_unit):
			return false

		eco.call("add_resource", faction_id, "coin", -coin_cost)
		eco.call("add_resource", faction_id, "food", -food_cost)
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
		var eco: Object = ctx.economy
		var mana_cost: int = 40
		if int(eco.call("get_resource", faction_id, "mana")) < mana_cost:
			return false
		eco.call("add_resource", faction_id, "mana", -mana_cost)

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
