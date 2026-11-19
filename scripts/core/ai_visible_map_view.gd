class_name AIVisibleMapView
extends RefCounted

var viewer_faction_id: int = 1
var fog_enabled: bool = false
var filtered_map: BattleMapState = null
var visible_hexes: Dictionary[Vector2i, bool] = {}

var _visible_enemies: Array[BattleUnit] = []
var _allied_units: Array[BattleUnit] = []
var _units_by_id: Dictionary[int, BattleUnit] = {}


static func _clone_unit_snapshot(src: BattleUnit) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = src.unit_id
	u.troop_id = src.troop_id
	u.general_id = src.general_id
	u.code = src.code
	u.display_name = src.display_name
	u.general_name = src.general_name
	u.faction_id = src.faction_id
	u.hex_position = src.hex_position
	u.facing = src.facing
	u.domain = src.domain
	u.command_branch = src.command_branch
	u.base_hp = src.base_hp
	u.max_stack = src.max_stack
	u.troop_stack = src.troop_stack
	u.base_atk = src.base_atk
	u.damage_roll_min = src.damage_roll_min
	u.damage_roll_max = src.damage_roll_max
	u.attack_mode = src.attack_mode
	u.base_def = src.base_def
	u.defense_mode = src.defense_mode
	u.max_mp = src.max_mp
	u.vision_range = src.vision_range
	u.min_range = src.min_range
	u.max_range = src.max_range
	u.base_crit = src.base_crit
	u.crit_rate_bonus = src.crit_rate_bonus
	u.crit_damage_bonus = src.crit_damage_bonus
	u.counter_percent = src.counter_percent
	u.damage_deepen = src.damage_deepen
	u.damage_resist = src.damage_resist
	u.is_commander_in_chief = src.is_commander_in_chief
	u.general_command_stat = src.general_command_stat
	u.general_luck = src.general_luck
	u.m_command = src.m_command
	u.aura_radius_hex = src.aura_radius_hex
	u.aura_damage_deepen = src.aura_damage_deepen
	u.aura_damage_resist = src.aura_damage_resist
	u.grants_dead_mate_immunity = src.grants_dead_mate_immunity
	u.fond_terrain = src.fond_terrain
	u.ignore_zoc = src.ignore_zoc
	u.ignore_coc = src.ignore_coc
	u.devoid_zoc = src.devoid_zoc
	u.ambush_forest = src.ambush_forest
	u.no_retaliation = src.no_retaliation

	u.state.current_hp = src.state.current_hp
	u.state.max_hp = src.state.max_hp
	u.state.current_mp = src.state.current_mp
	u.state.morale = src.state.morale
	u.state.is_morale_locked = src.state.is_morale_locked
	u.state.chaos_turns = src.state.chaos_turns
	u.state.march_disabled_turns = src.state.march_disabled_turns
	u.state.attack_disabled_turns = src.state.attack_disabled_turns
	u.state.skill_disabled_turns = src.state.skill_disabled_turns
	u.state.is_transported = src.state.is_transported
	u.state.is_invisible = src.state.is_invisible
	u.state.is_taunting = src.state.is_taunting
	u.state.has_retaliated_this_round = src.state.has_retaliated_this_round
	u.state.has_acted = src.state.has_acted
	u.state.has_used_undo_this_turn = src.state.has_used_undo_this_turn
	u.state.skill_cooldown = src.state.skill_cooldown
	return u


## Builds an information-restricted view for AI planning (Zero Map-Hack).
## Hidden traps and unrevealed Fog-of-War / stealth enemies are strictly excluded.
static func from_context(ctx: BattleContext, faction_id: int) -> AIVisibleMapView:
	var view := AIVisibleMapView.new()
	view.viewer_faction_id = faction_id
	if ctx == null or ctx.map_state == null:
		return view

	var src_map: BattleMapState = ctx.map_state
	view.fog_enabled = ctx.enable_fog_of_war
	var f_map := BattleMapState.new(src_map.width, src_map.height)
	f_map.staked_water_owner_faction = src_map.staked_water_owner_faction

	var teams: Dictionary[int, int] = src_map.get_faction_teams()
	for f_id: int in teams.keys():
		f_map.set_faction_team(f_id, teams[f_id])

	for row: int in range(src_map.height):
		for col: int in range(src_map.width):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			var t: BattleMapState.TerrainType = src_map.get_terrain(ax)
			f_map.set_terrain(ax, t)
			if t == BattleMapState.TerrainType.FORT:
				var f_owner: int = src_map.get_fort_owner(ax)
				if f_owner != 0:
					f_map.set_fort_owner(ax, f_owner)

	var all_units: Array[BattleUnit] = src_map.get_all_units()
	all_units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.unit_id < b.unit_id)

	var allied_positions: Array[Vector2i] = []
	for u: BattleUnit in all_units:
		if src_map.is_allied(faction_id, u.faction_id):
			allied_positions.append(u.hex_position)
			if view.fog_enabled:
				var vr: int = maxi(1, u.vision_range)
				for dq: int in range(-vr, vr + 1):
					var r_min: int = maxi(-vr, -dq - vr)
					var r_max: int = mini(vr, -dq + vr)
					for dr: int in range(r_min, r_max + 1):
						var cand: Vector2i = u.hex_position + Vector2i(dq, dr)
						if not src_map.is_valid_hex(cand):
							continue
						if cand == u.hex_position or ctx.navigator.has_line_of_sight(src_map, u.hex_position, cand):
							view.visible_hexes[cand] = true

	for u: BattleUnit in all_units:
		var is_ally: bool = src_map.is_allied(faction_id, u.faction_id)
		if is_ally:
			var clone_ally: BattleUnit = _clone_unit_snapshot(u)
			f_map.place_unit(clone_ally)
			view._allied_units.append(clone_ally)
			view._units_by_id[clone_ally.unit_id] = clone_ally
			continue

		if src_map.is_hostile(faction_id, u.faction_id):
			if view.fog_enabled:
				if not view.visible_hexes.has(u.hex_position):
					continue
				var terrain: BattleMapState.TerrainType = src_map.get_terrain(u.hex_position)
				if u.state.is_invisible and (
					terrain == BattleMapState.TerrainType.FOREST
					or terrain == BattleMapState.TerrainType.SWAMP
				):
					var revealed_by_adj: bool = false
					for ally_pos: Vector2i in allied_positions:
						if HexMath.hex_distance(ally_pos, u.hex_position) <= 1:
							revealed_by_adj = true
							break
					if not revealed_by_adj:
						continue
			var clone_enemy: BattleUnit = _clone_unit_snapshot(u)
			f_map.place_unit(clone_enemy)
			view._visible_enemies.append(clone_enemy)
			view._units_by_id[clone_enemy.unit_id] = clone_enemy

	view.filtered_map = f_map
	return view


func is_hex_visible(axial: Vector2i) -> bool:
	if filtered_map == null or not filtered_map.is_valid_hex(axial):
		return false
	if not fog_enabled:
		return true
	return visible_hexes.has(axial)


func get_terrain(axial: Vector2i) -> BattleMapState.TerrainType:
	if filtered_map == null:
		return BattleMapState.TerrainType.PLAINS
	return filtered_map.get_terrain(axial)


func get_visible_enemies() -> Array[BattleUnit]:
	return _visible_enemies


func get_allied_units() -> Array[BattleUnit]:
	return _allied_units


func get_unit_by_id(unit_id: int) -> BattleUnit:
	return _units_by_id.get(unit_id, null)


func get_visible_unit_at(axial: Vector2i) -> BattleUnit:
	if filtered_map == null:
		return null
	return filtered_map.get_unit_at(axial)
