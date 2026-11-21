class_name ScenarioLoader
extends RefCounted


## Loads a battle controller cleanly from DataRegistry (.tres) by stage ID.
static func load_stage(
	stage_id: int,
	battle_seed: int = 12880409,
	registry: DataRegistry = null
) -> BattleGameController:
	var active_reg: DataRegistry = registry if registry != null else StaticDataLoader.load_registry()
	if active_reg == null:
		return null
	var stage_def: StageDef = active_reg.get_stage(stage_id)
	return load_stage_def(stage_def, battle_seed, active_reg)


## Builds and initializes a deterministic BattleGameController directly from a StageDef Resource.
static func load_stage_def(
	stage_def: StageDef,
	battle_seed: int = 12880409,
	registry: DataRegistry = null
) -> BattleGameController:
	if stage_def == null:
		return null
	var troop_source: Variant = registry if registry != null else StaticDataLoader.DEFAULT_REGISTRY_PATH
	var troop_defs: Dictionary[int, Dictionary] = StaticDataLoader.load_troop_settings(troop_source)
	var ctrl: BattleGameController = _build_controller_from_dict(stage_def.to_battle_dict(), troop_defs, battle_seed)
	if ctrl != null and stage_def.enable_economy:
		ctrl.enable_economy = true
		if ctrl.economy == null:
			var eco := BattleEconomy.new()
			eco.init_faction(1, 300, 300, 150, 100)
			eco.init_faction(2, 300, 300, 150, 100)
			ctrl.economy = eco
	return ctrl


## Builds and initializes a complete deterministic BattleGameController from a battle JSON file.
static func load_battle_file(
	battle_path: String,
	battle_seed: int = 12880409,
	troop_source: Variant = StaticDataLoader.DEFAULT_REGISTRY_PATH
) -> BattleGameController:
	var data: Dictionary = StaticDataLoader.load_json_dict(battle_path)
	if data.is_empty():
		return null
	var troop_defs: Dictionary[int, Dictionary] = StaticDataLoader.load_troop_settings(troop_source)
	return _build_controller_from_dict(data, troop_defs, battle_seed)


static func _build_controller_from_dict(
	data: Dictionary,
	troop_defs: Dictionary[int, Dictionary],
	battle_seed: int
) -> BattleGameController:
	var width: int = maxi(1, int(data.get("map_width", 12)))
	var height: int = maxi(1, int(data.get("map_height", 10)))
	var default_terrain: BattleMapState.TerrainType = ScenarioEventManager.parse_terrain_enum(
		str(data.get("default_terrain", "Plains"))
	)
	var map_state := BattleMapState.new(width, height, default_terrain)
	map_state.staked_water_owner_faction = int(data.get("staked_water_owner_faction", 1))

	var director := ScenarioDirector.new()
	_configure_factions(data, map_state, director)

	var turn_order: Array[int] = _parse_turn_order(data)
	var max_rounds: int = maxi(1, int(data.get("max_rounds", 10)))
	var player_faction: int = int(data.get("player_faction_id", 1))

	var event_mgr := ScenarioEventManager.new()
	var raw_events: Variant = data.get("events", [])
	event_mgr.setup(raw_events if raw_events is Array else [], [])

	var victory_eval := ScenarioVictoryEvaluator.new(
		data.get("victory_conditions", []) if data.get("victory_conditions", []) is Array else [],
		data.get("defeat_conditions", []) if data.get("defeat_conditions", []) is Array else [],
		data.get("star_conditions", []) if data.get("star_conditions", []) is Array else [],
		player_faction,
		max_rounds
	)

	var ctrl := BattleGameController.new(map_state, battle_seed, turn_order, max_rounds)
	ctrl.player_faction_id = player_faction
	ctrl.enable_economy = bool(data.get("enable_economy", false))
	if ctrl.enable_economy:
		var eco := BattleEconomy.new()
		eco.init_faction(1, 300, 300, 150, 100)
		eco.init_faction(2, 300, 300, 150, 100)
		var raw_eco: Variant = data.get("economy", {})
		if raw_eco is Dictionary:
			var ed: Dictionary = raw_eco as Dictionary
			var facs_in: Variant = ed.get("factions", {})
			if facs_in is Dictionary:
				for fk: Variant in (facs_in as Dictionary).keys():
					var fd: Dictionary = (facs_in as Dictionary)[fk] as Dictionary
					eco.init_faction(
						int(str(fk)),
						int(fd.get("coin", 300)),
						int(fd.get("food", 300)),
						int(fd.get("tech", 150)),
						int(fd.get("mana", 100))
					)
			var fac_list: Variant = ed.get("facilities", [])
			if fac_list is Array:
				for f_item: Variant in fac_list as Array:
					if f_item is Dictionary:
						var f_d: Dictionary = f_item as Dictionary
						eco.register_facility(
							str(f_d.get("id", "fac")),
							int(f_d.get("owner", 1)),
							str(f_d.get("type", "Farm")),
							int(f_d.get("level", 1)),
							int(f_d.get("turns_unrobbed", 1)),
							bool(f_d.get("has_granary", false))
						)
		ctrl.economy = eco
	ctrl.director = director
	ctrl.event_manager = event_mgr
	ctrl.victory_evaluator = victory_eval
	ctrl.context.troop_defs = troop_defs
	ctrl.context.coordinate_space = str(data.get("coordinate_space", "odd_r"))
	ctrl.context.director = director
	ctrl.context.victory_evaluator = victory_eval

	_apply_terrain_overrides(data, ctrl.context, map_state)
	_register_areas(data, ctrl.context, director)
	_spawn_placements(data, ctrl.context)

	victory_eval.register_initial_units(map_state)
	ctrl.start_battle()
	return ctrl


## Loads dialogue lines for a stage ID from DataRegistry (.tres) for the HUD.
static func load_stage_dialogues(
	stage_id: int,
	registry: DataRegistry = null
) -> Dictionary:
	var active_reg: DataRegistry = registry if registry != null else StaticDataLoader.load_registry()
	if active_reg == null:
		return {}
	var stage_def: StageDef = active_reg.get_stage(stage_id)
	return stage_def.get_dialogues_dict() if stage_def != null else {}


static func _parse_turn_order(data: Dictionary) -> Array[int]:
	var order: Array[int] = []
	var raw_order: Variant = data.get("turn_order", [])
	if raw_order is Array:
		for item: Variant in raw_order:
			order.append(int(item))
	if order.is_empty():
		var raw_factions: Variant = data.get("factions", [])
		if raw_factions is Array:
			for f_var: Variant in raw_factions:
				if f_var is Dictionary:
					order.append(int((f_var as Dictionary).get("faction_id", 1)))
	if order.is_empty():
		order = [1, 2]
	return order


static func _configure_factions(
	data: Dictionary,
	map_state: BattleMapState,
	director: ScenarioDirector
) -> void:
	var raw_factions: Variant = data.get("factions", [])
	if not (raw_factions is Array):
		return
	for f_var: Variant in raw_factions:
		if not (f_var is Dictionary):
			continue
		var f_dict: Dictionary = f_var as Dictionary
		var fid: int = int(f_dict.get("faction_id", 1))
		var tid: int = int(f_dict.get("team_id", fid))
		map_state.set_faction_team(fid, tid)

		var t_gens: Variant = f_dict.get("target_generals", [])
		if t_gens is Array and not (t_gens as Array).is_empty():
			director.set_target_generals(fid, t_gens as Array)
		var p_gens: Variant = f_dict.get("protected_generals", [])
		if p_gens is Array and not (p_gens as Array).is_empty():
			director.set_protected_generals(fid, p_gens as Array)


static func _apply_terrain_overrides(
	data: Dictionary,
	ctx: BattleContext,
	map_state: BattleMapState
) -> void:
	var raw_overrides: Variant = data.get("terrain_overrides", [])
	if not (raw_overrides is Array):
		return
	for ov_var: Variant in raw_overrides:
		if not (ov_var is Dictionary):
			continue
		var ov: Dictionary = ov_var as Dictionary
		var axial: Vector2i = ctx.parse_hex_dict(ov)
		var t_enum: BattleMapState.TerrainType = ScenarioEventManager.parse_terrain_enum(
			str(ov.get("terrain", "Plains"))
		)
		map_state.set_terrain(axial, t_enum)
		if ov.has("fort_owner"):
			map_state.set_fort_owner(axial, int(ov.get("fort_owner", 0)))


static func _register_areas(
	data: Dictionary,
	ctx: BattleContext,
	director: ScenarioDirector
) -> void:
	var raw_areas: Variant = data.get("areas", [])
	if not (raw_areas is Array):
		return
	for area_var: Variant in raw_areas:
		if not (area_var is Dictionary):
			continue
		var area_dict: Dictionary = area_var as Dictionary
		var area_id: String = str(area_dict.get("area_id", ""))
		if area_id.is_empty():
			continue
		var hexes: Array[Vector2i] = []
		var raw_hexes: Variant = area_dict.get("hexes", [])
		if raw_hexes is Array:
			for h_var: Variant in raw_hexes:
				if h_var is Dictionary:
					hexes.append(ctx.parse_hex_dict(h_var as Dictionary))
		director.register_area(
			area_id,
			hexes,
			int(area_dict.get("initial_owner", 0)),
			bool(area_dict.get("is_objective", false))
		)


static func _spawn_placements(data: Dictionary, ctx: BattleContext) -> void:
	var raw_placements: Variant = data.get("placements", [])
	if not (raw_placements is Array):
		return
	for p_var: Variant in raw_placements:
		if p_var is Dictionary:
			ctx.spawn_unit_from_placement(p_var as Dictionary)
