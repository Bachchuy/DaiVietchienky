class_name BattleFxBridge
extends RefCounted
## Bridges sim commands, scenario events, VFX/SFX feedback, stress fixtures, and live replay checks (`res://game/battle/`).

const DEFAULT_BATTLE_SEED: int = 12880409


static func handle_command_executed(
	command_type: String,
	faction_id: int,
	ctrl: BattleGameController,
	battle_map: BattleMap,
	hud: BattleHud,
	juice: CombatJuiceHelper,
	audio: BattleAudioManager,
	camera: BattleCameraController,
	save_mgr: BattleSaveManager,
	is_stress_mode: bool
) -> String:
	if ctrl == null or ctrl.context == null:
		return ""
	var banner: String = ""
	if command_type == "March":
		var p: Dictionary = ctrl.context.last_command_payload
		var to_ax: Vector2i = p.get("to_hex", Vector2i.ZERO)
		if hud != null:
			var to_off: Vector2i = HexMath.axial_to_odd_r(to_ax)
			hud.append_combat_log("Đơn vị #%d hành quân tới (%d,%d)" % [int(p.get("unit_id", 0)), to_off.x, to_off.y])
		if juice != null and battle_map != null:
			juice.spawn_particle_preset("DustTrailCPU2D", battle_map.axial_to_world(to_ax), "Tran_Nguyen")
	elif command_type == "Attack":
		var rep: Dictionary = ctrl.context.get_last_combat_report()
		var p_atk: Dictionary = ctrl.context.last_command_payload
		var atk_id: int = int(p_atk.get("attacker_id", rep.get("attacker_id", 0)))
		var def_id: int = int(p_atk.get("defender_id", rep.get("defender_id", 0)))
		var dmg_val: int = int(rep.get("damage", 0))
		var counter_val: int = int(rep.get("counter_damage", 0))
		var is_cr: bool = bool(rep.get("is_crit", false))
		var crit_tag: String = " [BẠO KÍCH!]" if is_cr else ""
		var flank_tag: String = " [BỌC SƯỜN]" if bool(rep.get("is_flanked", false)) else ""
		if hud != null:
			hud.append_combat_log("Giao chiến: #%d đánh #%d gây %d ST%s%s | Phản kích: %d ST" % [
				atk_id, def_id, dmg_val, crit_tag, flank_tag, counter_val
			])
		var def_u: BattleUnit = ctrl.context.get_unit(def_id)
		var def_world: Vector2 = battle_map.axial_to_world(def_u.hex_position) if def_u != null and battle_map != null else Vector2(200.0, 200.0)
		if juice != null and battle_map != null:
			juice.spawn_particle_preset("MetalSparksCPU2D", def_world, "Tran_Nguyen")
			juice.spawn_floating_text(
				battle_map.get_layer_node("WorldSpaceUnitHudAndTextLayer"),
				def_world,
				dmg_val,
				&"crit" if is_cr else (&"blocked" if dmg_val <= 0 else &"normal")
			)
		if audio != null:
			audio.play_sfx("sword_hit", def_world, "Tran_Nguyen")
		if faction_id == ctrl.player_faction_id:
			if camera != null:
				camera.add_trauma(0.45 if is_cr else 0.22)
			if ctrl.outcome == BattleGameController.BattleOutcome.ONGOING:
				banner = "Giao chiến: Gây %d ST%s%s | Phản kích: %d ST" % [dmg_val, crit_tag, flank_tag, counter_val]
	elif command_type == "CastSkill":
		if hud != null:
			hud.append_combat_log("Thi triển Mưu Lược #10001 Hịch Tướng Sĩ (+Sĩ khí, giải Hỗn Loạn)")
		var p_sk: Dictionary = ctrl.context.last_command_payload
		var sk_pos: Vector2 = battle_map.axial_to_world(p_sk.get("target_hex", Vector2i.ZERO)) if battle_map != null else Vector2.ZERO
		if juice != null:
			juice.spawn_particle_preset("MoraleAuraCPU2D", sk_pos, "Tran_Nguyen")
		if audio != null:
			audio.play_sfx("horn_charge", sk_pos, "Tran_Nguyen")
		if faction_id == ctrl.player_faction_id:
			banner = "Đã thi triển Mưu Lược Hịch Tướng Sĩ (CD: 3 lượt)!"
	elif command_type == "EndTurn":
		if not is_stress_mode and save_mgr != null:
			save_mgr.save_battle_session(ctrl)
	if hud != null:
		hud.update_dock_buttons()
	return banner


static func format_scenario_event_banner(event_id: String, event_name: String, dialogues: Dictionary) -> String:
	if event_id == "evt_10101_tide_fall":
		var dlg: Dictionary = dialogues.get("talk_trieu_rut", {})
		return "[SỰ KIỆN VÒNG 4 — NƯỚC RÚT LỘ BÃI CỌC] %s: \"%s\"" % [
			str(dlg.get("speaker", "Trần Quốc Tuấn")),
			str(dlg.get("line", event_name)),
		]
	if event_id == "evt_10101_omnhi_wounded":
		var dlg_w: Dictionary = dialogues.get("talk_omnhi_hoang_loan", {})
		return "[SỰ KIỆN] %s: \"%s\"" % [
			str(dlg_w.get("speaker", "Ô Mã Nhi")),
			str(dlg_w.get("line", event_name)),
		]
	return "[SỰ KIỆN] %s" % event_name


static func build_stress_30x30_map(unit_count: int, troop_defs: Dictionary) -> BattleMapState:
	var target_map := BattleMapState.new(30, 30, BattleMapState.TerrainType.PLAINS)
	for row: int in range(30):
		for col: int in range(30):
			var ax: Vector2i = HexMath.odd_r_to_axial(Vector2i(col, row))
			if col >= 13 and col <= 15:
				target_map.set_terrain(ax, BattleMapState.TerrainType.DEEP_WATER)
			elif col == 12 or col == 16:
				target_map.set_terrain(ax, BattleMapState.TerrainType.SHALLOW_RIVER)
			elif (col + row) % 7 == 0:
				target_map.set_terrain(ax, BattleMapState.TerrainType.FOREST)
			elif (col * 3 + row) % 11 == 0:
				target_map.set_terrain(ax, BattleMapState.TerrainType.HILLS)
			elif row == 14:
				target_map.set_terrain(ax, BattleMapState.TerrainType.ROAD_PORT)

	var land_ids: Array[int] = [40101, 40102, 40103, 40104]
	var spawned: int = 0
	var uid: int = 1
	for row: int in range(2, 28, 2):
		for col: int in [4, 8, 20, 24]:
			if spawned >= unit_count:
				break
			_spawn_unit_into(target_map, troop_defs, uid, 1 if col < 12 else 3, land_ids[spawned % land_ids.size()], Vector2i(col, row), 3)
			uid += 1
			spawned += 1
		if spawned < unit_count and row % 4 == 0:
			_spawn_unit_into(target_map, troop_defs, uid, 1, 40201, Vector2i(13, row), 3)
			uid += 1
			spawned += 1
		if spawned < unit_count and row % 4 == 2:
			_spawn_unit_into(target_map, troop_defs, uid, 3, 40901, Vector2i(15, row), 3)
			uid += 1
			spawned += 1
	return target_map


static func _spawn_unit_into(
	target_map: BattleMapState,
	troop_defs: Dictionary,
	uid: int,
	faction: int,
	troop_id: int,
	offset_cell: Vector2i,
	stack_count: int
) -> void:
	var axial: Vector2i = HexMath.odd_r_to_axial(offset_cell)
	var u: BattleUnit = BattleUnit.from_troop_dict(uid, faction, axial, troop_defs.get(troop_id, {}))
	u.max_stack = stack_count
	u.troop_stack = stack_count
	u.state.max_hp = u.base_hp * stack_count
	u.state.current_hp = u.state.max_hp
	target_map.place_unit(u)


static func verify_deterministic_replay(
	ctrl: BattleGameController,
	stage_id: int,
	is_stress_mode: bool,
	stress_unit_count: int,
	troop_defs: Dictionary
) -> Dictionary:
	if ctrl == null or ctrl.context == null:
		return {"ok": false, "banner": "[REPLAY ERROR] Không có trận đấu đang chạy!"}
	var map_state: BattleMapState = ctrl.context.map_state
	var replay_payload: Dictionary = ctrl.export_replay()
	var verify_ctrl: BattleGameController = null
	if is_stress_mode:
		var verify_map: BattleMapState = build_stress_30x30_map(stress_unit_count, troop_defs)
		verify_ctrl = BattleGameController.new(verify_map, DEFAULT_BATTLE_SEED, [1, 3], ctrl.max_rounds)
	else:
		verify_ctrl = ScenarioLoader.load_stage(stage_id, DEFAULT_BATTLE_SEED)
	if verify_ctrl == null or not verify_ctrl.replay_from_dict(replay_payload):
		return {"ok": false, "banner": "[REPLAY ERROR] Không thể phát lại chuỗi lệnh!"}

	var live_units: Array[BattleUnit] = map_state.get_all_units()
	var rep_units: Array[BattleUnit] = verify_ctrl.context.map_state.get_all_units()
	if live_units.size() != rep_units.size():
		return {"ok": false, "banner": "[REPLAY DESYNC] Sai lệch quân số!"}
	for u_live: BattleUnit in live_units:
		var u_rep: BattleUnit = verify_ctrl.context.get_unit(u_live.unit_id)
		if u_rep == null or u_rep.state.current_hp != u_live.state.current_hp or u_rep.hex_position != u_live.hex_position:
			return {"ok": false, "banner": "[REPLAY DESYNC] Lệch HP/tọa độ tại đơn vị %d!" % u_live.unit_id}

	var all_ok: bool = (
		verify_ctrl.outcome == ctrl.outcome
		and verify_ctrl.current_round == ctrl.current_round
		and verify_ctrl.context.rng.get_state() == ctrl.context.rng.get_state()
	)
	return {
		"ok": all_ok,
		"banner": "[REPLAY VERIFIED 100%%] Phát lại %d lệnh từ Seed %d khớp tuyệt đối HP, Tọa độ, Vòng %d & RNG (%s)!" % [
			ctrl.command_history.get_replay_stream_size(),
			DEFAULT_BATTLE_SEED,
			ctrl.current_round,
			"OK" if all_ok else "DIFF",
		],
	}
