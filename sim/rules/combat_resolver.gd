class_name CombatResolver
extends RefCounted

const STACK_MULTIPLIERS: Dictionary[int, float] = {
	1: 1.00,
	2: 1.65,
	3: 2.20,
}

## 6 AttackMode (1..6) x 5 DefenseMode (1..5) matchup percentages (GDD combat_formulas.md Section 4).
const MATCHUP_MATRIX: Dictionary[int, Array] = {
	1: [105, 120, 100, 80, 45],   # Melee
	2: [135, 110, 100, 90, 85],   # Cavalry / Elephant Charge
	3: [125, 100, 75, 85, 35],    # Archery / Crossbow
	4: [80, 85, 120, 110, 150],   # Siege / Cannon
	5: [110, 100, 90, 120, 130],  # Naval Warfare
	6: [125, 115, 105, 100, 125], # Fire Weapons / Fire Ships
}


static func round_half_up(value: float) -> int:
	return int(floor(value + 0.5))


static func get_matchup_percent(attack_mode: int, defense_mode: int) -> int:
	var row: Array = MATCHUP_MATRIX.get(clampi(attack_mode, 1, 6), [100, 100, 100, 100, 100])
	var col_idx: int = clampi(defense_mode, 1, 5) - 1
	return int(row[col_idx])


static func compute_effective_def(
	base_def: int,
	terrain_def_mult: float,
	target_morale: UnitCombatState.MoraleLevel
) -> float:
	var morale_def_mult: float = 0.80 if target_morale == UnitCombatState.MoraleLevel.LOW else 1.00
	return float(base_def) * terrain_def_mult * morale_def_mult


static func compute_def_reduction(effective_def: float) -> float:
	return 100.0 / (100.0 + maxf(0.0, effective_def))


func is_flank_attack(
	map_state: BattleMapState,
	attacker: BattleUnit,
	target: BattleUnit
) -> bool:
	if map_state == null or attacker == null or target == null:
		return false
	for dir: Vector2i in HexMath.AXIAL_DIRECTIONS:
		var adj: Vector2i = target.hex_position + dir
		if not map_state.is_valid_hex(adj):
			continue
		var occ: BattleUnit = map_state.get_unit_at(adj)
		if occ == null or occ == attacker:
			continue
		if not map_state.is_allied(attacker.faction_id, occ.faction_id):
			continue
		if not occ.state.emits_zoc():
			continue
		if HexMath.hex_distance(occ.hex_position, attacker.hex_position) > 1:
			return true
	return false


func compute_attacker_terrain_mult(map_state: BattleMapState, attacker: BattleUnit) -> float:
	var terrain: BattleMapState.TerrainType = map_state.get_terrain(attacker.hex_position)
	var m_terrain: float = 1.00

	if terrain == BattleMapState.TerrainType.HILLS and attacker.max_range > 1:
		m_terrain += 0.10
	elif terrain == BattleMapState.TerrainType.SWAMP and attacker.is_cavalry_or_siege():
		m_terrain -= 0.15
	elif (
		terrain == BattleMapState.TerrainType.DEEP_WATER
		and attacker.domain == BattleUnit.Domain.LAND
		and attacker.state.is_transported
	):
		m_terrain -= 0.20

	if attacker.fond_terrain == int(terrain):
		m_terrain += 0.15

	return m_terrain


func compute_defender_terrain_mult(map_state: BattleMapState, defender: BattleUnit) -> float:
	var terrain: BattleMapState.TerrainType = map_state.get_terrain(defender.hex_position)
	var mult: float = map_state.get_terrain_def_mult(terrain, defender)
	if defender.fond_terrain == int(terrain):
		mult += 0.15
	return mult


func get_aura_bonuses(map_state: BattleMapState, unit: BattleUnit) -> Vector2i:
	var best_deepen: int = 0
	var best_resist: int = 0
	for ally: BattleUnit in map_state.get_all_units():
		if not map_state.is_allied(unit.faction_id, ally.faction_id):
			continue
		if ally.aura_radius_hex <= 0 or not ally.state.emits_zoc():
			continue
		if HexMath.hex_distance(ally.hex_position, unit.hex_position) <= ally.aura_radius_hex:
			best_deepen = maxi(best_deepen, ally.aura_damage_deepen)
			best_resist = maxi(best_resist, ally.aura_damage_resist)
	return Vector2i(best_deepen, best_resist)


func compute_strike_raw_damage(
	map_state: BattleMapState,
	attacker: BattleUnit,
	defender: BattleUnit,
	roll_factor: float,
	flanked: bool,
	is_starving: bool = false
) -> float:
	if attacker.state.morale == UnitCombatState.MoraleLevel.CHAOS:
		return 0.0

	var max_hp: int = maxi(1, attacker.state.max_hp)
	var hp_ratio: float = clampf(float(attacker.state.current_hp) / float(max_hp), 0.0, 1.0)
	var m_hp: float = 0.50 + 0.50 * hp_ratio

	var gen_cmd: int = clampi(attacker.general_command_stat, 0, 30)
	var atk_rolled: float = (float(attacker.base_atk) * roll_factor + float(gen_cmd)) * m_hp

	var def_terrain_mult: float = compute_defender_terrain_mult(map_state, defender)
	var eff_def: float = compute_effective_def(defender.base_def, def_terrain_mult, defender.state.morale)
	var def_reduction: float = compute_def_reduction(eff_def)

	var dmg_pct: int = get_matchup_percent(attacker.attack_mode, defender.defense_mode)
	var m_matchup: float = float(dmg_pct) / 100.0

	var m_morale: float = 1.00
	match attacker.state.morale:
		UnitCombatState.MoraleLevel.HIGH:
			m_morale = 1.15
		UnitCombatState.MoraleLevel.NORMAL:
			m_morale = 1.00
		UnitCombatState.MoraleLevel.LOW:
			m_morale = 0.75
		_:
			m_morale = 0.00

	var m_target_chaos: float = (
		1.30 if defender.state.morale == UnitCombatState.MoraleLevel.CHAOS else 1.00
	)
	var m_flank: float = 1.15 if flanked else 1.00
	var m_terrain: float = compute_attacker_terrain_mult(map_state, attacker)
	var m_stack: float = STACK_MULTIPLIERS.get(attacker.get_effective_stack(), 1.00)
	var m_starvation: float = 0.75 if is_starving else 1.00

	var atk_aura: Vector2i = get_aura_bonuses(map_state, attacker)
	var def_aura: Vector2i = get_aura_bonuses(map_state, defender)
	var total_deepen: int = maxi(0, attacker.damage_deepen + atk_aura.x)
	var total_resist: int = clampi(defender.damage_resist + def_aura.y, -50, 75)
	var m_deepen: float = 1.0 + float(total_deepen) / 100.0
	var m_resist: float = 1.0 - float(total_resist) / 100.0

	return (
		atk_rolled
		* def_reduction
		* m_matchup
		* attacker.m_command
		* m_morale
		* m_target_chaos
		* m_flank
		* m_terrain
		* m_stack
		* m_starvation
		* m_deepen
		* m_resist
	)


func compute_crit_rate(attacker: BattleUnit) -> int:
	if attacker.state.morale == UnitCombatState.MoraleLevel.CHAOS:
		return 0
	var hp_ratio: float = clampf(
		float(attacker.state.current_hp) / maxf(1.0, float(attacker.state.max_hp)),
		0.0,
		1.0
	)
	var morale_mod: int = 0
	match attacker.state.morale:
		UnitCombatState.MoraleLevel.HIGH:
			morale_mod = 20
		UnitCombatState.MoraleLevel.LOW:
			morale_mod = -5
		_:
			morale_mod = 0
	var luck: int = clampi(attacker.general_luck, 0, 100)
	var raw_crit: int = (
		attacker.base_crit
		+ int(hp_ratio * 10.0)
		+ int(float(luck) * 0.15)
		+ morale_mod
		+ attacker.crit_rate_bonus
	)
	return clampi(raw_crit, 0, 100)


static func apply_crit_damage(final_damage: int, crit_damage_bonus: int = 0) -> int:
	var crit_mult: float = 1.50 + float(crit_damage_bonus) / 100.0
	return maxi(1, round_half_up(float(final_damage) * crit_mult))


func is_retaliation_suppressed_by_ambush(map_state: BattleMapState, attacker: BattleUnit) -> bool:
	if attacker.no_retaliation:
		return true
	if attacker.ambush_forest and map_state.get_terrain(attacker.hex_position) == BattleMapState.TerrainType.FOREST:
		return true
	return false


func can_defender_retaliate(
	map_state: BattleMapState,
	navigator: HexGridNavigator,
	attacker: BattleUnit,
	defender: BattleUnit
) -> bool:
	if defender == null or not defender.state.is_alive():
		return false
	if not defender.state.can_retaliate():
		return false
	if defender.counter_percent <= 0:
		return false
	if is_retaliation_suppressed_by_ambush(map_state, attacker):
		return false
	var dist: int = HexMath.hex_distance(defender.hex_position, attacker.hex_position)
	if dist < defender.min_range or dist > defender.max_range:
		return false
	return navigator.has_line_of_sight(map_state, defender.hex_position, attacker.hex_position)


func preview_combat(
	map_state: BattleMapState,
	navigator: HexGridNavigator,
	attacker: BattleUnit,
	defender: BattleUnit,
	attacker_starving: bool = false,
	defender_starving: bool = false
) -> Dictionary:
	var flanked: bool = is_flank_attack(map_state, attacker, defender)
	var min_roll: float = float(attacker.damage_roll_min) / 100.0
	var max_roll: float = float(attacker.damage_roll_max) / 100.0

	var min_dmg: int = 0
	var max_dmg: int = 0
	if attacker.state.morale != UnitCombatState.MoraleLevel.CHAOS:
		min_dmg = maxi(1, round_half_up(compute_strike_raw_damage(map_state, attacker, defender, min_roll, flanked, attacker_starving)))
		max_dmg = maxi(1, round_half_up(compute_strike_raw_damage(map_state, attacker, defender, max_roll, flanked, attacker_starving)))

	var crit_pct: int = compute_crit_rate(attacker)
	var crit_max: int = apply_crit_damage(max_dmg, attacker.crit_damage_bonus) if max_dmg > 0 else 0

	# Estimate retaliation assuming defender survives with post-min-damage HP
	var will_ret: bool = false
	var counter_min: int = 0
	var counter_max: int = 0
	if defender.state.current_hp > min_dmg and can_defender_retaliate(map_state, navigator, attacker, defender):
		will_ret = true
		var saved_hp: int = defender.state.current_hp
		defender.state.current_hp = maxi(1, saved_hp - max_dmg)
		var c_min_raw: float = compute_strike_raw_damage(
			map_state,
			defender,
			attacker,
			float(defender.damage_roll_min) / 100.0,
			false,
			defender_starving
		)
		defender.state.current_hp = maxi(1, saved_hp - min_dmg)
		var c_max_raw: float = compute_strike_raw_damage(
			map_state,
			defender,
			attacker,
			float(defender.damage_roll_max) / 100.0,
			false,
			defender_starving
		)
		defender.state.current_hp = saved_hp
		counter_min = maxi(1, round_half_up(c_min_raw * float(defender.counter_percent) / 100.0))
		counter_max = maxi(1, round_half_up(c_max_raw * float(defender.counter_percent) / 100.0))

	return {
		"min_damage": min_dmg,
		"max_damage": max_dmg,
		"crit_rate": crit_pct,
		"crit_max_damage": crit_max,
		"is_flanked": flanked,
		"damage_percent": get_matchup_percent(attacker.attack_mode, defender.defense_mode),
		"will_retaliate": will_ret,
		"counter_min_damage": counter_min,
		"counter_max_damage": counter_max,
	}


func resolve_attack(
	map_state: BattleMapState,
	navigator: HexGridNavigator,
	attacker: BattleUnit,
	defender: BattleUnit,
	rng: SeededRng,
	attacker_starving: bool = false,
	defender_starving: bool = false
) -> Dictionary:
	if attacker == null or defender == null or not attacker.state.can_attack():
		return {
			"ok": false,
			"damage": 0,
			"is_crit": false,
			"is_flanked": false,
			"retaliated": false,
			"counter_damage": 0,
			"defender_defeated": false,
			"attacker_defeated": false,
		}

	var flanked: bool = is_flank_attack(map_state, attacker, defender)
	var min_roll: float = float(attacker.damage_roll_min) / 100.0
	var max_roll: float = float(attacker.damage_roll_max) / 100.0
	var roll_factor: float = rng.roll_float_range(min_roll, max_roll)

	var raw_dmg: float = compute_strike_raw_damage(map_state, attacker, defender, roll_factor, flanked, attacker_starving)
	var dealt_damage: int = maxi(1, round_half_up(raw_dmg))

	var crit_pct: int = compute_crit_rate(attacker)
	var crit_roll: int = rng.roll_int_range(1, 100)
	var is_crit: bool = (crit_roll <= crit_pct)
	if is_crit:
		dealt_damage = apply_crit_damage(dealt_damage, attacker.crit_damage_bonus)

	defender.state.current_hp = maxi(0, defender.state.current_hp - dealt_damage)
	var defender_defeated: bool = not defender.state.is_alive()

	# Immediate combat morale shocks on living defender BEFORE checking retaliation (GDD Section 7.1)
	if not defender_defeated:
		if flanked:
			defender.state.shift_morale(-1)
		if is_crit:
			defender.state.shift_morale(-1)
	else:
		map_state.remove_unit(defender.unit_id)

	# Sequential retaliation check
	var retaliated: bool = false
	var counter_dmg: int = 0
	var attacker_defeated: bool = false
	if not defender_defeated and can_defender_retaliate(map_state, navigator, attacker, defender):
		retaliated = true
		defender.state.has_retaliated_this_round = true
		var c_min: float = float(defender.damage_roll_min) / 100.0
		var c_max: float = float(defender.damage_roll_max) / 100.0
		var c_roll: float = rng.roll_float_range(c_min, c_max)
		var c_raw: float = compute_strike_raw_damage(map_state, defender, attacker, c_roll, false, defender_starving)
		counter_dmg = maxi(1, round_half_up(c_raw * float(defender.counter_percent) / 100.0))
		attacker.state.current_hp = maxi(0, attacker.state.current_hp - counter_dmg)
		attacker_defeated = not attacker.state.is_alive()
		if attacker_defeated:
			map_state.remove_unit(attacker.unit_id)

	return {
		"ok": true,
		"damage": dealt_damage,
		"is_crit": is_crit,
		"is_flanked": flanked,
		"retaliated": retaliated,
		"counter_damage": counter_dmg,
		"defender_defeated": defender_defeated,
		"attacker_defeated": attacker_defeated,
	}
