class_name AIDecisionMatrix
extends RefCounted

const SKILL_RALLY_ID: int = 10001

var profile: AIDifficultyProfile = null
var navigator: HexGridNavigator = HexGridNavigator.new()
var combat_resolver: CombatResolver = CombatResolver.new()
var morale_engine: MoraleEngine = MoraleEngine.new()
var _evaluators: AIEvaluators = null


func _init(difficulty_profile: AIDifficultyProfile = null) -> void:
	profile = (
		difficulty_profile
		if difficulty_profile != null
		else AIDifficultyProfile.create_preset(&"normal")
	)
	_evaluators = AIEvaluators.new(navigator, combat_resolver)


## Stage 1: Generate valid action candidates strictly from AIVisibleMapView (Zero Map-Hack).
func generate_candidates(
	unit: BattleUnit,
	visible_view: AIVisibleMapView
) -> Array[AIActionCandidate]:
	var candidates: Array[AIActionCandidate] = []
	if unit == null or visible_view == null or visible_view.filtered_map == null:
		return candidates
	if not unit.state.is_alive() or unit.state.morale == UnitCombatState.MoraleLevel.CHAOS or unit.state.has_acted:
		return candidates

	var f_map: BattleMapState = visible_view.filtered_map
	var sim_unit: BattleUnit = visible_view.get_unit_by_id(unit.unit_id)
	if sim_unit == null:
		sim_unit = unit

	var reachable: Dictionary[Vector2i, int] = navigator.get_reachable_hexes(f_map, sim_unit)
	var dest_list: Array[Vector2i] = []
	for h: Vector2i in reachable.keys():
		dest_list.append(h)
	dest_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	var can_atk: bool = sim_unit.state.can_attack()
	var can_skill: bool = (sim_unit.general_id > 0 and sim_unit.state.can_use_skill())
	var enemies: Array[BattleUnit] = visible_view.get_visible_enemies()
	var allies: Array[BattleUnit] = visible_view.get_allied_units()
	var min_r: int = maxi(1, sim_unit.min_range)
	var max_r: int = maxi(min_r, sim_unit.max_range)

	for dest: Vector2i in dest_list:
		var wait_cand := AIActionCandidate.new()
		wait_cand.action_kind = AIActionCandidate.ActionKind.WAIT
		wait_cand.dest_hex = dest
		candidates.append(wait_cand)

		if can_atk:
			for enemy: BattleUnit in enemies:
				if not enemy.state.is_alive():
					continue
				var dist: int = HexMath.hex_distance(dest, enemy.hex_position)
				if dist < min_r or dist > max_r:
					continue
				if navigator.has_line_of_sight(f_map, dest, enemy.hex_position):
					var atk_cand := AIActionCandidate.new()
					atk_cand.action_kind = AIActionCandidate.ActionKind.ATTACK
					atk_cand.dest_hex = dest
					atk_cand.target_unit_id = enemy.unit_id
					atk_cand.target_hex = enemy.hex_position
					candidates.append(atk_cand)

		if can_skill:
			var needs_rally: bool = false
			for ally: BattleUnit in allies:
				if not ally.state.is_alive():
					continue
				if HexMath.hex_distance(dest, ally.hex_position) <= 1:
					if (
						ally.state.morale == UnitCombatState.MoraleLevel.CHAOS
						or ally.state.morale == UnitCombatState.MoraleLevel.LOW
					):
						needs_rally = true
						break
			if needs_rally:
				var skill_cand := AIActionCandidate.new()
				skill_cand.action_kind = AIActionCandidate.ActionKind.CAST_SKILL
				skill_cand.dest_hex = dest
				skill_cand.skill_id = SKILL_RALLY_ID
				skill_cand.target_hex = dest
				skill_cand.mana_cost = 0
				candidates.append(skill_cand)

	return candidates


func _get_evaluators() -> AIEvaluators:
	if _evaluators == null:
		_evaluators = AIEvaluators.new(navigator, combat_resolver)
	else:
		_evaluators.navigator = navigator
		_evaluators.combat_resolver = combat_resolver
	return _evaluators


func evaluate_position(
	dest_hex: Vector2i,
	unit: BattleUnit,
	visible_view: AIVisibleMapView,
	director: ScenarioDirector = null
) -> float:
	return _get_evaluators().evaluate_position(dest_hex, unit, visible_view, director)


func evaluate_attack(
	candidate: AIActionCandidate,
	unit: BattleUnit,
	visible_view: AIVisibleMapView
) -> float:
	return _get_evaluators().evaluate_attack(candidate, unit, visible_view)


func evaluate_objective(
	candidate: AIActionCandidate,
	unit: BattleUnit,
	visible_view: AIVisibleMapView,
	director: ScenarioDirector
) -> float:
	return _get_evaluators().evaluate_objective(candidate, unit, visible_view, director)


func evaluate_status(
	candidate: AIActionCandidate,
	unit: BattleUnit,
	visible_view: AIVisibleMapView
) -> float:
	return _get_evaluators().evaluate_status(candidate, unit, visible_view)


func evaluate_mana(candidate: AIActionCandidate, tactical_gain: float) -> float:
	return _get_evaluators().evaluate_mana(candidate, tactical_gain)


## Stage 3: Weighted Utility Sum + Deterministic Additive RNG Noise.
func plan_unit_turn(
	unit: BattleUnit,
	visible_view: AIVisibleMapView,
	director: ScenarioDirector,
	rng: SeededRng
) -> Array[BattleCommands.BaseCommand]:
	if unit == null or not unit.state.is_alive() or unit.state.has_acted:
		return []
	if unit.state.morale == UnitCombatState.MoraleLevel.CHAOS or unit.state.chaos_turns > 0:
		return [BattleCommands.WaitCommand.new(unit.faction_id, unit.unit_id)]

	var candidates: Array[AIActionCandidate] = generate_candidates(unit, visible_view)
	if candidates.is_empty():
		return [BattleCommands.WaitCommand.new(unit.faction_id, unit.unit_id)]

	var best_cand: AIActionCandidate = null
	var best_score: float = -INF

	for cand: AIActionCandidate in candidates:
		var s_atk: float = evaluate_attack(cand, unit, visible_view)
		var s_pos: float = evaluate_position(cand.dest_hex, unit, visible_view, director)
		var s_obj: float = evaluate_objective(cand, unit, visible_view, director)
		var s_status: float = evaluate_status(cand, unit, visible_view)
		var s_mana: float = evaluate_mana(cand, s_status)
		var s_skill: float = s_status + s_mana

		var base_score: float = (
			profile.w_atk * s_atk
			+ profile.w_pos * s_pos
			+ profile.w_obj * s_obj
			+ profile.w_skill * s_skill
		)
		var noise: float = rng.roll_float_range(-profile.noise_amp, profile.noise_amp) if rng != null else 0.0
		var total_score: float = base_score + noise

		if total_score > best_score:
			best_score = total_score
			best_cand = cand

	if best_cand == null:
		return [BattleCommands.WaitCommand.new(unit.faction_id, unit.unit_id)]
	return best_cand.to_commands(unit)


## Executes a complete AI turn for `faction_id` through BattleGameController and ends with EndTurnCommand.
func execute_faction_turn(
	controller: BattleGameController,
	faction_id: int,
	director: ScenarioDirector = null
) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var acted_units: int = 0
	var executed_cmds: int = 0

	if controller == null or controller.outcome != BattleGameController.BattleOutcome.ONGOING:
		return {"acted_units": 0, "executed_commands": 0, "elapsed_ms": 0.0}
	if controller.current_faction_id != faction_id:
		return {"acted_units": 0, "executed_commands": 0, "elapsed_ms": 0.0}

	var unit_ids: Array[int] = []
	for u: BattleUnit in controller.context.map_state.get_all_units():
		if u.faction_id == faction_id and u.state.is_alive() and not u.state.has_acted:
			unit_ids.append(u.unit_id)
	unit_ids.sort()

	for uid: int in unit_ids:
		if controller.outcome != BattleGameController.BattleOutcome.ONGOING:
			break
		if controller.current_faction_id != faction_id:
			break
		var unit: BattleUnit = controller.context.get_unit(uid)
		if unit == null or not unit.state.is_alive() or unit.state.has_acted:
			continue
		if unit.state.morale == UnitCombatState.MoraleLevel.CHAOS or unit.state.chaos_turns > 0:
			continue

		var vis_view: AIVisibleMapView = AIVisibleMapView.from_context(controller.context, faction_id)
		var turn_seed: int = (
			controller.command_history.initial_seed
			^ (controller.current_round * 100003)
			^ (faction_id * 1009)
			^ (uid * 97)
		)
		var decision_rng := SeededRng.new(turn_seed)
		var cmds: Array[BattleCommands.BaseCommand] = plan_unit_turn(
			unit,
			vis_view,
			director,
			decision_rng
		)
		for cmd: BattleCommands.BaseCommand in cmds:
			if controller.outcome != BattleGameController.BattleOutcome.ONGOING:
				break
			if controller.submit_command(cmd):
				executed_cmds += 1
		acted_units += 1

	if (
		controller.outcome == BattleGameController.BattleOutcome.ONGOING
		and controller.current_faction_id == faction_id
	):
		if controller.submit_command(BattleCommands.EndTurnCommand.new(faction_id)):
			executed_cmds += 1

	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	return {
		"acted_units": acted_units,
		"executed_commands": executed_cmds,
		"elapsed_ms": elapsed_ms,
	}
