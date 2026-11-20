class_name BattleSaveManager
extends RefCounted

const SESSION_SAVE_PATH: String = "user://saves/battle_session.json"
const PROFILE_SAVE_PATH: String = "user://saves/player_profile.json"
const PROFILE_BAK_PATH: String = "user://saves/player_profile.bak"


func save_battle_session(
	controller: BattleGameController,
	save_path: String = SESSION_SAVE_PATH
) -> bool:
	if controller == null or controller.context == null or controller.context.map_state == null:
		return false
	DirAccess.make_dir_recursive_absolute("user://saves")

	var map_state: BattleMapState = controller.context.map_state
	var hex_cells: Array[Dictionary] = []
	for row: int in range(map_state.height):
		for col: int in range(map_state.width):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			hex_cells.append({
				"q": ax.x,
				"r": ax.y,
				"terrain": int(map_state.get_terrain(ax)),
				"fort_owner": map_state.get_fort_owner(ax),
			})

	var unit_states: Array[Dictionary] = []
	for u: BattleUnit in map_state.get_all_units():
		unit_states.append({
			"unit_id": u.unit_id,
			"faction_id": u.faction_id,
			"troop_id": u.troop_id,
			"general_id": u.general_id,
			"general_name": u.general_name,
			"display_name": u.display_name,
			"q": u.hex_position.x,
			"r": u.hex_position.y,
			"current_hp": u.state.current_hp,
			"max_hp": u.state.max_hp,
			"current_mp": u.state.current_mp,
			"max_mp": u.max_mp,
			"morale": int(u.state.morale),
			"is_morale_locked": u.state.is_morale_locked,
			"chaos_turns": u.state.chaos_turns,
			"march_disabled_turns": u.state.march_disabled_turns,
			"attack_disabled_turns": u.state.attack_disabled_turns,
			"skill_disabled_turns": u.state.skill_disabled_turns,
			"skill_cooldown": u.state.skill_cooldown,
			"has_acted": u.state.has_acted,
			"has_retaliated_this_round": u.state.has_retaliated_this_round,
			"max_stack": u.max_stack,
		})

	var area_owners: Dictionary = {}
	if controller.director != null:
		area_owners = controller.director.area_owners.duplicate()

	var triggered_ids: Array[String] = []
	if controller.event_manager != null:
		triggered_ids = controller.event_manager.triggered_event_ids.duplicate()

	var eco_dict: Dictionary = {}
	var eco_obj: Variant = controller.get("economy")
	if eco_obj is Object and (eco_obj as Object).has_method("to_dict"):
		eco_dict = (eco_obj as Object).call("to_dict")

	var payload: Dictionary = {
		"version": 1,
		"stage_id": 10101,
		"current_round": controller.current_round,
		"max_rounds": controller.max_rounds,
		"current_faction_id": controller.current_faction_id,
		"player_faction_id": controller.player_faction_id,
		"outcome": int(controller.outcome),
		"enable_economy": controller.enable_economy,
		"rng_seed": str(controller.context.rng.get_seed()),
		"rng_state": str(controller.context.rng.get_state()),
		"triggered_event_ids": triggered_ids,
		"area_owners": area_owners,
		"hex_cell_states": hex_cells,
		"unit_states": unit_states,
		"economy_state": eco_dict,
	}

	var fa: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(JSON.stringify(payload, "\t"))
	fa.close()
	return true


func load_battle_session(
	controller: BattleGameController,
	save_path: String = SESSION_SAVE_PATH
) -> bool:
	if controller == null or controller.context == null or controller.context.map_state == null:
		return false
	if not FileAccess.file_exists(save_path):
		return false

	var fa: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if fa == null:
		return false
	var raw_txt: String = fa.get_as_text()
	fa.close()

	var parser := JSON.new()
	if parser.parse(raw_txt) != OK:
		return false
	if not (parser.data is Dictionary):
		return false

	var d: Dictionary = parser.data as Dictionary
	if int(d.get("version", 0)) != 1:
		return false

	controller.current_round = int(d.get("current_round", controller.current_round))
	controller.max_rounds = int(d.get("max_rounds", controller.max_rounds))
	controller.current_faction_id = int(d.get("current_faction_id", controller.current_faction_id))
	controller.player_faction_id = int(d.get("player_faction_id", controller.player_faction_id))
	controller.enable_economy = bool(d.get("enable_economy", false))

	var seed_str: String = str(d.get("rng_seed", "1288"))
	var state_str: String = str(d.get("rng_state", seed_str))
	controller.context.rng.restore(int(seed_str), int(state_str))

	if controller.event_manager != null and d.has("triggered_event_ids") and d["triggered_event_ids"] is Array:
		controller.event_manager.triggered_event_ids.clear()
		for raw_id: Variant in d["triggered_event_ids"] as Array:
			controller.event_manager.triggered_event_ids.append(str(raw_id))

	var map_state: BattleMapState = controller.context.map_state
	var cells_raw: Variant = d.get("hex_cell_states", [])
	if cells_raw is Array:
		for c_var: Variant in cells_raw as Array:
			if c_var is Dictionary:
				var cd: Dictionary = c_var as Dictionary
				var ax := Vector2i(int(cd.get("q", 0)), int(cd.get("r", 0)))
				if map_state.is_valid_hex(ax):
					map_state.set_terrain(ax, int(cd.get("terrain", 0)) as BattleMapState.TerrainType)
					map_state.set_fort_owner(ax, int(cd.get("fort_owner", 0)))

	if controller.director != null and d.get("area_owners") is Dictionary:
		var ao: Dictionary = d["area_owners"] as Dictionary
		for area_id_v: Variant in ao.keys():
			var area_id_s: String = str(area_id_v)
			controller.director.set_area_owner(area_id_s, int(ao[area_id_v]))

	var units_raw: Variant = d.get("unit_states", [])
	if units_raw is Array:
		var saved_by_id: Dictionary = {}
		for u_var: Variant in units_raw as Array:
			if u_var is Dictionary:
				var ud: Dictionary = u_var as Dictionary
				saved_by_id[int(ud.get("unit_id", -1))] = ud

		for existing_u: BattleUnit in map_state.get_all_units():
			if not saved_by_id.has(existing_u.unit_id):
				map_state.remove_unit(existing_u.unit_id)

		for uid_key: Variant in saved_by_id.keys():
			var ud: Dictionary = saved_by_id[uid_key] as Dictionary
			var uid: int = int(uid_key)
			var u: BattleUnit = controller.context.get_unit(uid)
			var target_hex := Vector2i(int(ud.get("q", 0)), int(ud.get("r", 0)))
			if u != null:
				if u.hex_position != target_hex:
					map_state.move_unit(u, target_hex)
				u.state.current_hp = int(ud.get("current_hp", u.state.current_hp))
				u.state.max_hp = int(ud.get("max_hp", u.state.max_hp))
				u.state.current_mp = int(ud.get("current_mp", u.state.current_mp))
				u.state.morale = int(ud.get("morale", int(u.state.morale))) as UnitCombatState.MoraleLevel
				u.state.is_morale_locked = bool(ud.get("is_morale_locked", false))
				u.state.chaos_turns = int(ud.get("chaos_turns", 0))
				u.state.march_disabled_turns = int(ud.get("march_disabled_turns", 0))
				u.state.attack_disabled_turns = int(ud.get("attack_disabled_turns", 0))
				u.state.skill_disabled_turns = int(ud.get("skill_disabled_turns", 0))
				u.state.skill_cooldown = int(ud.get("skill_cooldown", 0))
				u.state.has_acted = bool(ud.get("has_acted", false))
				u.state.has_retaliated_this_round = bool(ud.get("has_retaliated_this_round", false))
				u.max_stack = int(ud.get("max_stack", u.max_stack))

	var eco_raw: Variant = d.get("economy_state", {})
	if eco_raw is Dictionary and not (eco_raw as Dictionary).is_empty():
		var eco_obj: Variant = controller.get("economy")
		if eco_obj == null and ResourceLoader.exists("res://scripts/core/battle_economy.gd"):
			var eco_scr: GDScript = load("res://scripts/core/battle_economy.gd") as GDScript
			if eco_scr != null:
				eco_obj = eco_scr.new()
				controller.set("economy", eco_obj)
		if eco_obj is Object and (eco_obj as Object).has_method("from_dict"):
			(eco_obj as Object).call("from_dict", eco_raw as Dictionary)

	return true


func save_player_profile(
	profile_data: Dictionary,
	save_path: String = PROFILE_SAVE_PATH
) -> bool:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var bak_path: String = _get_bak_path(save_path)

	# Copy existing valid primary profile to .bak before overwriting
	if FileAccess.file_exists(save_path):
		var prev_dict: Variant = _try_parse_dict_file(save_path)
		if prev_dict is Dictionary:
			var fa_bak: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
			if fa_bak != null:
				fa_bak.store_string(JSON.stringify(prev_dict, "\t"))
				fa_bak.close()

	var merged: Dictionary = _default_profile()
	var existing: Variant = _try_parse_dict_file(save_path)
	if existing is Dictionary:
		_merge_profile_dicts(merged, existing as Dictionary)
	_merge_profile_dicts(merged, profile_data)
	merged["version"] = 1

	var fa: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(JSON.stringify(merged, "\t"))
	fa.close()
	return true


func load_player_profile(save_path: String = PROFILE_SAVE_PATH) -> Dictionary:
	var primary: Variant = _try_parse_dict_file(save_path)
	if primary is Dictionary:
		return primary as Dictionary

	var bak_path: String = _get_bak_path(save_path)
	var backup: Variant = _try_parse_dict_file(bak_path)
	if backup is Dictionary:
		var fa_restore: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if fa_restore != null:
			fa_restore.store_string(JSON.stringify(backup, "\t"))
			fa_restore.close()
		return backup as Dictionary

	return _default_profile()


func record_stage_clear(
	stage_id: int,
	stars: int,
	save_path: String = PROFILE_SAVE_PATH
) -> bool:
	var prof: Dictionary = load_player_profile(save_path)
	var stage_stars: Dictionary = (
		(prof.get("stage_stars", {}) as Dictionary).duplicate(true)
		if prof.get("stage_stars") is Dictionary
		else {}
	)
	var key: String = str(stage_id)
	var prev_best: int = int(stage_stars.get(key, 0))
	stage_stars[key] = maxi(prev_best, clampi(stars, 1, 3))
	prof["stage_stars"] = stage_stars
	return save_player_profile(prof, save_path)


func _get_bak_path(save_path: String) -> String:
	if save_path == PROFILE_SAVE_PATH:
		return PROFILE_BAK_PATH
	return save_path.get_basename() + ".bak"


func _try_parse_dict_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return null
	var txt: String = fa.get_as_text()
	fa.close()
	if txt.is_empty():
		return null
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		return null
	if not (parser.data is Dictionary):
		return null
	return parser.data as Dictionary


func _default_profile() -> Dictionary:
	return {
		"version": 1,
		"stage_stars": {},
		"tutorial_flags": {},
		"codex_unlocked": ["bach_dang_1288"],
		"audio": {
			"Master": 0.85,
			"BGM": 0.80,
			"SFX": 0.85,
		},
		"reduce_flashing": false,
		"vfx_quality": 2,
		"shake_scale": 1.0,
	}


func _merge_profile_dicts(dst: Dictionary, src: Dictionary) -> void:
	for k: Variant in src.keys():
		if dst.has(k) and dst[k] is Dictionary and src[k] is Dictionary:
			var sub_dst: Dictionary = (dst[k] as Dictionary).duplicate(true)
			for sk: Variant in (src[k] as Dictionary).keys():
				sub_dst[sk] = (src[k] as Dictionary)[sk]
			dst[k] = sub_dst
		else:
			dst[k] = src[k]
