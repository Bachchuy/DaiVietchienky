class_name AIEvaluators
extends RefCounted

var navigator: HexGridNavigator = null
var combat_resolver: CombatResolver = null


func _init(p_navigator: HexGridNavigator = null, p_combat_resolver: CombatResolver = null) -> void:
	navigator = p_navigator if p_navigator != null else HexGridNavigator.new()
	combat_resolver = p_combat_resolver if p_combat_resolver != null else CombatResolver.new()


## Evaluator 1: Tactical Positioning (FondTerrain, Elevation/Cover, Pincer, Stakes, ZoC risk).
func evaluate_position(
	dest_hex: Vector2i,
	unit: BattleUnit,
	visible_view: AIVisibleMapView,
	_director: ScenarioDirector = null
) -> float:
	if unit == null or visible_view == null or visible_view.filtered_map == null:
		return 0.0

	var f_map: BattleMapState = visible_view.filtered_map
	var terrain: BattleMapState.TerrainType = f_map.get_terrain(dest_hex)
	var score: float = 0.0

	if unit.fond_terrain == int(terrain):
		score += 25.0

	if (
		terrain == BattleMapState.TerrainType.HILLS
		or terrain == BattleMapState.TerrainType.FOREST
		or terrain == BattleMapState.TerrainType.FORT
	):
		score += 20.0

	# Hazards on publicly visible map (NEVER reads hidden pre-Round-4 traps!)
	if terrain == BattleMapState.TerrainType.SWAMP and unit.fond_terrain != int(BattleMapState.TerrainType.SWAMP):
		score -= 50.0
	elif (
		terrain == BattleMapState.TerrainType.STAKED_WATER
		and unit.domain == BattleUnit.Domain.NAVAL
		and f_map.is_hostile(unit.faction_id, f_map.staked_water_owner_faction)
	):
		score -= 50.0

	var adj_zoc_enemies: int = 0
	var adj_enemies: int = 0
	var forms_pincer: bool = false
	for dir_idx: int in range(6):
		var nb: Vector2i = dest_hex + HexMath.AXIAL_DIRECTIONS[dir_idx]
		if not f_map.is_valid_hex(nb):
			continue
		var occ: BattleUnit = f_map.get_unit_at(nb)
		if occ == null or occ.unit_id == unit.unit_id:
			continue
		if f_map.is_hostile(unit.faction_id, occ.faction_id):
			adj_enemies += 1
			if occ.state.emits_zoc():
				adj_zoc_enemies += 1
			# Check 180-degree opposite side of this enemy for an active ally -> Pincer!
			var opp_hex: Vector2i = occ.hex_position + (occ.hex_position - dest_hex)
			if f_map.is_valid_hex(opp_hex):
				var opp_unit: BattleUnit = f_map.get_unit_at(opp_hex)
				if (
					opp_unit != null
					and opp_unit.unit_id != unit.unit_id
					and f_map.is_allied(unit.faction_id, opp_unit.faction_id)
					and opp_unit.state.emits_zoc()
				):
					forms_pincer = true

	if forms_pincer:
		score += 45.0
	if adj_zoc_enemies >= 2:
		score -= 30.0

	var adj_allies: int = 0
	var guards_commander: bool = false
	for ally: BattleUnit in visible_view.get_allied_units():
		if ally.unit_id == unit.unit_id or not ally.state.is_alive():
			continue
		var d: int = HexMath.hex_distance(dest_hex, ally.hex_position)
		if d <= 1:
			adj_allies += 1
			if ally.is_commander_in_chief and unit.state.emits_zoc():
				guards_commander = true

	if guards_commander:
		score += 35.0
	if adj_enemies >= 1 and adj_allies == 0:
		score -= 25.0

	return score


## Evaluator 2: Combat Expected Damage, KillSecuring, Morale Break, Stack Priority & Retaliation Risk.
func evaluate_attack(
	candidate: AIActionCandidate,
	unit: BattleUnit,
	visible_view: AIVisibleMapView
) -> float:
	if candidate == null or candidate.action_kind != AIActionCandidate.ActionKind.ATTACK:
		return 0.0
	if visible_view == null or visible_view.filtered_map == null:
		return 0.0

	var f_map: BattleMapState = visible_view.filtered_map
	var sim_attacker: BattleUnit = visible_view.get_unit_by_id(unit.unit_id)
	if sim_attacker == null:
		sim_attacker = unit
	var target: BattleUnit = visible_view.get_unit_by_id(candidate.target_unit_id)
	if target == null or not target.state.is_alive():
		return 0.0

	var orig_hex: Vector2i = sim_attacker.hex_position
	var moved_temp: bool = false
	if candidate.dest_hex != orig_hex and f_map.get_unit_at(candidate.dest_hex) == null:
		moved_temp = f_map.move_unit(sim_attacker, candidate.dest_hex)

	var preview: Dictionary = combat_resolver.preview_combat(f_map, navigator, sim_attacker, target)

	if moved_temp:
		f_map.move_unit(sim_attacker, orig_hex)

	var min_dmg: int = int(preview.get("min_damage", 0))
	var max_dmg: int = int(preview.get("max_damage", 0))
	var avg_dmg: float = 0.5 * float(min_dmg + max_dmg)
	var dmg_pct: float = (avg_dmg / maxf(1.0, float(target.state.max_hp))) * 100.0

	var score: float = 0.6 * dmg_pct

	# KillSecuring (+80.0 scored ONLY here)
	if target.state.current_hp <= min_dmg:
		score += 80.0

	# Push LOW morale enemy down to CHAOS via Flank or high crit chance
	if target.state.morale == UnitCombatState.MoraleLevel.LOW and (
		bool(preview.get("is_flanked", false)) or int(preview.get("crit_rate", 0)) >= 50
	):
		score += 40.0

	if target.get_effective_stack() == 3:
		score += 25.0

	if target.state.is_taunting:
		score += 60.0

	if bool(preview.get("will_retaliate", false)):
		var c_min: int = int(preview.get("counter_min_damage", 0))
		var c_max: int = int(preview.get("counter_max_damage", 0))
		var avg_counter: float = 0.5 * float(c_min + c_max)
		var self_loss_pct: float = (avg_counter / maxf(1.0, float(sim_attacker.state.max_hp))) * 100.0
		score -= 0.4 * self_loss_pct

	return score


## Evaluator 3: ScenarioDirector Objectives (SignalDock capture/defense & General hunt/escort).
func evaluate_objective(
	candidate: AIActionCandidate,
	unit: BattleUnit,
	visible_view: AIVisibleMapView,
	director: ScenarioDirector
) -> float:
	if candidate == null or unit == null or visible_view == null or visible_view.filtered_map == null:
		return 0.0

	var f_map: BattleMapState = visible_view.filtered_map
	var score: float = 0.0
	var dest: Vector2i = candidate.dest_hex

	if director != null:
		for area_id: String in director.primary_objective_area_ids:
			var area_hexes: Array[Vector2i] = director.get_area_hexes(area_id)
			if area_hexes.is_empty():
				continue
			var owner_id: int = director.get_area_owner(area_id)
			var is_enemy_or_neutral: bool = (owner_id == 0 or f_map.is_hostile(unit.faction_id, owner_id))

			var cur_best_d: int = 999999
			var new_best_d: int = 999999
			for ah: Vector2i in area_hexes:
				cur_best_d = mini(cur_best_d, HexMath.hex_distance(unit.hex_position, ah))
				new_best_d = mini(new_best_d, HexMath.hex_distance(dest, ah))

			if is_enemy_or_neutral:
				if area_hexes.has(dest):
					score += 90.0
				elif new_best_d < cur_best_d:
					score += 8.0 * float(cur_best_d - new_best_d)
			else:
				var threatened: bool = false
				for enemy: BattleUnit in visible_view.get_visible_enemies():
					for ah: Vector2i in area_hexes:
						if HexMath.hex_distance(enemy.hex_position, ah) <= 3:
							threatened = true
							break
					if threatened:
						break
				if threatened and new_best_d <= 1:
					score += 65.0

		if candidate.action_kind == AIActionCandidate.ActionKind.ATTACK:
			var target: BattleUnit = visible_view.get_unit_by_id(candidate.target_unit_id)
			if target != null and director.is_target_general_for(unit.faction_id, target.general_id):
				score += 50.0

		for ally: BattleUnit in visible_view.get_allied_units():
			if ally.unit_id == unit.unit_id or not ally.state.is_alive():
				continue
			var is_key_vip: bool = (
				ally.is_commander_in_chief
				or director.is_protected_general_for(unit.faction_id, ally.general_id)
			)
			if not is_key_vip:
				continue
			var hp_ratio: float = float(ally.state.current_hp) / maxf(1.0, float(ally.state.max_hp))
			var adj_threats: int = 0
			for enemy: BattleUnit in visible_view.get_visible_enemies():
				if HexMath.hex_distance(enemy.hex_position, ally.hex_position) <= 2:
					adj_threats += 1
			if (hp_ratio < 0.50 or adj_threats >= 2) and HexMath.hex_distance(dest, ally.hex_position) == 1:
				score += 55.0

	if candidate.action_kind == AIActionCandidate.ActionKind.WAIT:
		var enemies: Array[BattleUnit] = visible_view.get_visible_enemies()
		if not enemies.is_empty():
			var cur_enemy_d: int = 999999
			var new_enemy_d: int = 999999
			for enemy: BattleUnit in enemies:
				cur_enemy_d = mini(cur_enemy_d, HexMath.hex_distance(unit.hex_position, enemy.hex_position))
				new_enemy_d = mini(new_enemy_d, HexMath.hex_distance(dest, enemy.hex_position))
			if new_enemy_d < cur_enemy_d:
				score += 6.0 * float(cur_enemy_d - new_enemy_d)

	return score


## Evaluator 4: Status & Crowd-Control Value.
func evaluate_status(
	candidate: AIActionCandidate,
	_unit: BattleUnit,
	visible_view: AIVisibleMapView
) -> float:
	if candidate == null or visible_view == null:
		return 0.0
	if candidate.action_kind == AIActionCandidate.ActionKind.CAST_SKILL:
		var score: float = 0.0
		for ally: BattleUnit in visible_view.get_allied_units():
			if HexMath.hex_distance(candidate.target_hex, ally.hex_position) <= 1:
				if ally.state.morale == UnitCombatState.MoraleLevel.CHAOS:
					score += 60.0
				elif ally.state.morale == UnitCombatState.MoraleLevel.LOW:
					score += 25.0
				elif ally.state.morale == UnitCombatState.MoraleLevel.NORMAL:
					score += 15.0
		return score
	return 0.0


## Evaluator 5: Mana Efficiency for Skills / Tactics.
func evaluate_mana(candidate: AIActionCandidate, tactical_gain: float) -> float:
	if candidate == null or candidate.action_kind != AIActionCandidate.ActionKind.CAST_SKILL:
		return 0.0
	if candidate.mana_cost <= 0:
		return 0.0
	return (tactical_gain / float(maxi(candidate.mana_cost, 1))) * 20.0
