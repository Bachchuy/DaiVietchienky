class_name ScenarioVictoryEvaluator
extends RefCounted

const OUTCOME_ONGOING: int = 0
const OUTCOME_VICTORY: int = 1
const OUTCOME_DEFEAT: int = 2

var victory_conditions: Array[Dictionary] = []
var defeat_conditions: Array[Dictionary] = []
var star_conditions: Array[Dictionary] = []
var player_faction_id: int = 1
var max_rounds: int = 10

var registered_player_units: Dictionary[int, int] = {}
var registered_enemy_units: Dictionary[int, int] = {}


func _init(
	p_victory: Array = [],
	p_defeat: Array = [],
	p_stars: Array = [],
	p_player_faction: int = 1,
	p_max_rounds: int = 10
) -> void:
	for item: Variant in p_victory:
		if item is Dictionary:
			victory_conditions.append((item as Dictionary).duplicate(true))
	for item: Variant in p_defeat:
		if item is Dictionary:
			defeat_conditions.append((item as Dictionary).duplicate(true))
	for item: Variant in p_stars:
		if item is Dictionary:
			star_conditions.append((item as Dictionary).duplicate(true))
	player_faction_id = p_player_faction
	max_rounds = maxi(1, p_max_rounds)


func clear_registrations() -> void:
	registered_player_units.clear()
	registered_enemy_units.clear()


func register_initial_units(map_state: BattleMapState) -> void:
	clear_registrations()
	if map_state == null:
		return
	for u: BattleUnit in map_state.get_all_units():
		register_unit(u, map_state)


func register_unit(unit: BattleUnit, map_state: BattleMapState) -> void:
	if unit == null or map_state == null:
		return
	if map_state.is_allied(player_faction_id, unit.faction_id):
		registered_player_units[unit.unit_id] = unit.state.max_hp
	elif map_state.is_hostile(player_faction_id, unit.faction_id):
		registered_enemy_units[unit.unit_id] = unit.state.max_hp


func get_enemy_defeated_percent(map_state: BattleMapState) -> float:
	if registered_enemy_units.is_empty():
		return 100.0
	var living_ids: Dictionary[int, bool] = {}
	for u: BattleUnit in map_state.get_all_units():
		if u.state.is_alive():
			living_ids[u.unit_id] = true

	var defeated: int = 0
	for eid: int in registered_enemy_units.keys():
		if not living_ids.has(eid):
			defeated += 1
	return (float(defeated) / float(registered_enemy_units.size())) * 100.0


func get_player_hp_loss_percent(map_state: BattleMapState) -> float:
	if registered_player_units.is_empty():
		return 0.0
	var total_max: int = 0
	var total_cur: int = 0
	var cur_by_id: Dictionary[int, int] = {}
	for u: BattleUnit in map_state.get_all_units():
		if u.state.is_alive():
			cur_by_id[u.unit_id] = u.state.current_hp

	for uid: int in registered_player_units.keys():
		var m_hp: int = registered_player_units[uid]
		total_max += m_hp
		total_cur += mini(m_hp, int(cur_by_id.get(uid, 0)))

	if total_max <= 0:
		return 0.0
	return maxf(0.0, (float(total_max - total_cur) / float(total_max)) * 100.0)


func evaluate_outcome(
	map_state: BattleMapState,
	director: ScenarioDirector,
	current_round: int,
	forced_outcome: int,
	is_round_end: bool
) -> int:
	if forced_outcome != OUTCOME_ONGOING:
		return forced_outcome

	# 1. Check immediate defeat conditions (LoseKeyArea / GeneralDefeated / AllUnitsEliminated)
	for d_cond: Dictionary in defeat_conditions:
		var d_type: String = str(d_cond.get("type", ""))
		match d_type:
			"LoseKeyArea":
				if director != null:
					var area_id: String = str(d_cond.get("area_id", ""))
					var owner_id: int = director.get_area_owner(area_id)
					if owner_id == 0 or map_state.is_hostile(player_faction_id, owner_id):
						return OUTCOME_DEFEAT
			"GeneralDefeated":
				var target_gid: int = int(d_cond.get("target_general_id", 0))
				if not _is_general_alive(map_state, target_gid):
					return OUTCOME_DEFEAT
			"AllUnitsEliminated":
				var fac_id: int = int(d_cond.get("faction_id", player_faction_id))
				if not _has_any_unit_of_faction(map_state, fac_id):
					return OUTCOME_DEFEAT
			_:
				pass

	# 2. Check Victory conditions
	for v_cond: Dictionary in victory_conditions:
		var v_type: String = str(v_cond.get("type", ""))
		match v_type:
			"DefeatGeneralWhileHoldingArea":
				var instant: bool = bool(v_cond.get("instant", true))
				if instant or is_round_end:
					var enemy_gid: int = int(v_cond.get("target_general_id", 0))
					var req_area: String = str(v_cond.get("required_area_id", ""))
					var area_ok: bool = req_area.is_empty() or _is_area_held_by_player(map_state, director, req_area)
					if area_ok and not _is_general_alive(map_state, enemy_gid):
						return OUTCOME_VICTORY
			"HoldAreaAndEnemyCasualtyAtMaxRound":
				if is_round_end:
					var at_r: int = int(v_cond.get("at_round", max_rounds))
					if current_round >= at_r:
						var req_area: String = str(v_cond.get("required_area_id", ""))
						var min_pct: float = float(v_cond.get("min_enemy_defeated_percent", 75.0))
						var area_ok: bool = req_area.is_empty() or _is_area_held_by_player(map_state, director, req_area)
						if area_ok and get_enemy_defeated_percent(map_state) + 0.0001 >= min_pct:
							return OUTCOME_VICTORY
			_:
				pass

	# 3. Check round-limit defeat (only after checking round-end Hold & Casualty victory!)
	if is_round_end:
		for d_cond: Dictionary in defeat_conditions:
			if str(d_cond.get("type", "")) == "MaxRoundsUnfulfilled":
				var lim: int = int(d_cond.get("max_rounds", max_rounds))
				if current_round >= lim:
					return OUTCOME_DEFEAT
		if current_round >= max_rounds:
			return OUTCOME_DEFEAT

	return OUTCOME_ONGOING


func evaluate_stars(controller_ref: RefCounted) -> Dictionary:
	var rounds_used: int = 0
	var outcome_val: int = OUTCOME_ONGOING
	var map_state: BattleMapState = null
	if controller_ref != null:
		rounds_used = int(controller_ref.get("current_round"))
		outcome_val = int(controller_ref.get("outcome"))
		var ctx: BattleContext = controller_ref.get("context") as BattleContext
		if ctx != null:
			map_state = ctx.map_state

	var hp_loss_pct: float = get_player_hp_loss_percent(map_state) if map_state != null else 0.0
	var enemy_def_pct: float = get_enemy_defeated_percent(map_state) if map_state != null else 0.0
	var earned_list: Array[int] = []
	var details: Array[Dictionary] = []

	if outcome_val == OUTCOME_VICTORY:
		for s_cond: Dictionary in star_conditions:
			var star_num: int = int(s_cond.get("star", 1))
			var s_type: String = str(s_cond.get("type", "Victory"))
			var passed: bool = false
			match s_type:
				"Victory":
					passed = true
				"MaxRoundLimit":
					passed = rounds_used <= int(s_cond.get("max_rounds", max_rounds))
				"CasualtyHpPercentLimit":
					passed = hp_loss_pct <= float(s_cond.get("max_loss_percent", 20.0)) + 0.0001
				_:
					passed = false
			if passed:
				earned_list.append(star_num)
			details.append({
				"star": star_num,
				"passed": passed,
				"description": str(s_cond.get("description", "")),
			})

	return {
		"stars": earned_list.size(),
		"earned_list": earned_list,
		"rounds_used": rounds_used,
		"player_hp_loss_percent": hp_loss_pct,
		"enemy_defeated_percent": enemy_def_pct,
		"details": details,
	}


func _is_general_alive(map_state: BattleMapState, general_id: int) -> bool:
	if map_state == null or general_id <= 0:
		return false
	for u: BattleUnit in map_state.get_all_units():
		if u.general_id == general_id and u.state.is_alive():
			return true
	return false


func _has_any_unit_of_faction(map_state: BattleMapState, faction_id: int) -> bool:
	if map_state == null:
		return false
	for u: BattleUnit in map_state.get_all_units():
		if u.faction_id == faction_id and u.state.is_alive():
			return true
	return false


func _is_area_held_by_player(
	map_state: BattleMapState,
	director: ScenarioDirector,
	area_id: String
) -> bool:
	if director == null:
		return true
	var owner_id: int = director.get_area_owner(area_id)
	return owner_id != 0 and map_state.is_allied(player_faction_id, owner_id)
