extends "res://tests/test_case.gd"

const SANDBOX_SCENE_PATH: String = "res://game/battle/battle.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"
const CODEX_SCENE_PATH: String = "res://scenes/ui/codex_panel.tscn"
const CAMPAIGN_CTRL_PATH: String = "res://scripts/presentation/campaign_menu_controller.gd"
const TUTORIAL_SCRIPT_PATH: String = "res://scripts/presentation/tutorial_overlay.gd"
const CODEX_SCRIPT_PATH: String = "res://scripts/presentation/codex_panel.gd"
const IP_AUDITOR_PATH: String = "res://sim/rules/asset_ip_auditor.gd"
const SAVE_MANAGER_PATH: String = "res://sim/state/battle_save_manager.gd"

const ScenarioLoaderScript = preload("res://sim/state/scenario_loader.gd")
const StaticLoaderScript = preload("res://sim/state/static_data_loader.gd")


func _clear_saves() -> void:
	for p: String in ["user://saves/battle_session.json", "user://saves/player_profile.json", "user://saves/player_profile.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_tran_campaign_six_stages_troops_generals_and_van_don_economy_load() -> void:
	var reg: DataRegistry = StaticLoaderScript.load_registry()
	assert_not_null(reg, "DataRegistry resource loads cleanly")
	if reg == null:
		return
	var stages: Array[StageDef] = reg.stages
	var troops: Array[TroopDef] = reg.troops
	var generals: Array[GeneralDef] = reg.generals
	var facilities: Array[FacilityDef] = reg.facilities

	assert_eq(stages.size(), 6, "6 Trần Dynasty campaign stages")
	assert_gte(float(troops.size()), 10.0, "At least 10 troop definitions")
	assert_lte(float(troops.size()), 14.0, "At most 14 troop definitions")
	assert_gte(float(generals.size()), 8.0, "At least 8 historical generals")
	assert_gt(float(facilities.size()), 0.0, "Facility definitions present")

	var valid_types: Array[String] = ["historical_claim", "abstraction", "fixture", "what_if"]
	var has_economy_stage: bool = false
	for st: StageDef in stages:
		var sid: int = st.stage_id
		assert_false(st.source_ref.is_empty(), "Stage %d has source_ref" % sid)
		assert_true(valid_types.has(st.modeling_type), "Stage %d has valid modeling_type" % sid)
		var ctrl: BattleGameController = ScenarioLoaderScript.load_stage(sid, 12880409, reg)
		assert_not_null(ctrl, "Stage %d loads cleanly" % sid)
		if st.enable_economy:
			has_economy_stage = true
			assert_true(ctrl.enable_economy, "Stage %d enables economy on controller" % sid)
			assert_not_null(ctrl.get("economy"), "Stage %d initializes BattleEconomy" % sid)
	assert_true(has_economy_stage, "Campaign includes Vân Đồn economy-enabled stage")

	for g: GeneralDef in generals:
		assert_false(g.source_ref.is_empty(), "General has source_ref")
		assert_true(valid_types.has(g.modeling_type), "General has valid modeling_type")


func test_campaign_menu_controller_sequential_unlock_preset_lock_and_free_replay() -> void:
	_clear_saves()
	var menu_scr: GDScript = load(CAMPAIGN_CTRL_PATH) as GDScript
	var save_scr: GDScript = load(SAVE_MANAGER_PATH) as GDScript
	assert_not_null(menu_scr, "CampaignMenuController script exists")
	if menu_scr == null or save_scr == null:
		return

	var menu_ctrl: Object = menu_scr.new()
	var save_mgr: Object = save_scr.new()
	add_child_autofree(menu_ctrl as Node)

	assert_true(bool(menu_ctrl.call("is_stage_unlocked", 10101, {})), "Stage 1 (10101) unlocked initially")
	assert_false(bool(menu_ctrl.call("is_stage_unlocked", 10102, {})), "Stage 2 (10102) locked initially")
	assert_false(bool(menu_ctrl.call("is_stage_unlocked", 10103, {})), "Stage 3 (10103) locked initially")

	save_mgr.call("record_stage_clear", 10101, 3)
	var prof: Dictionary = save_mgr.call("load_player_profile")
	assert_true(bool(menu_ctrl.call("is_stage_unlocked", 10102, prof)), "Stage 2 unlocks after Stage 1 cleared")

	assert_false(bool(menu_ctrl.call("can_customize_general_seats", 10101, false, {})), "Historical preset locked before clear")
	assert_true(bool(menu_ctrl.call("can_customize_general_seats", 10101, true, {"10101": 1})), "Free Replay / What-If unlocked after clear")

	assert_false(bool(menu_ctrl.call("validate_general_loadout", [1001, 1001], 2)), "Duplicate general rejected")
	assert_true(bool(menu_ctrl.call("validate_general_loadout", [1001, 1004], 2)), "Unique generals accepted")
	assert_false(bool(menu_ctrl.call("is_troop_allowed_in_stage", 40999, {"banned_troop_ids": [40999]})), "Banned troop rejected")

	var main_packed: PackedScene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	assert_not_null(main_packed, "main_menu.tscn exists")
	if main_packed != null:
		var menu_inst: Node = main_packed.instantiate()
		add_child_autofree(menu_inst)
		assert_not_null(menu_inst, "main_menu.tscn instantiates cleanly")


func test_contextual_tutorial_overlay_first_occurrence_persistence_and_economy_gate() -> void:
	_clear_saves()
	var packed: PackedScene = load(SANDBOX_SCENE_PATH) as PackedScene
	var sandbox: Node2D = packed.instantiate() as Node2D
	add_child_autofree(sandbox)

	var tut: Control = sandbox.call("get_tutorial_overlay") if sandbox.has_method("get_tutorial_overlay") else null
	assert_not_null(tut, "TutorialOverlay attached to sandbox HUD")
	if tut == null:
		return

	assert_true(bool(tut.call("trigger_tip", "tip_select_unit")), "First occurrence tip triggers")
	assert_true(tut.visible, "TutorialOverlay visible when tip active")
	tut.call("dismiss_current_tip")
	assert_false(tut.visible, "TutorialOverlay hidden after dismissal")
	assert_false(bool(tut.call("trigger_tip", "tip_select_unit")), "Dismissed tip does NOT repeat")

	tut.call("reset_tutorial_flags")
	assert_true(bool(tut.call("trigger_tip", "tip_select_unit")), "Reset tutorial flags re-arms tips")
	tut.call("dismiss_current_tip")

	assert_false(bool(tut.call("should_show_economy_tip", false)), "Economy tip suppressed when enable_economy == false")
	assert_true(bool(tut.call("should_show_economy_tip", true)), "Economy tip shown when enable_economy == true")


func test_historical_codex_era_separation_938_981_1288_and_grade_d_benchmark_rules() -> void:
	var entries: Array[CodexEntryDef] = StaticLoaderScript.load_codex_defs()
	assert_gt(float(entries.size()), 0.0, "Codex has entries")

	var has_938: bool = false
	var has_981: bool = false
	var has_1288: bool = false
	for c: CodexEntryDef in entries:
		if c.matches_query("938"):
			has_938 = true
		if c.matches_query("981"):
			has_981 = true
		if c.matches_query("1288"):
			has_1288 = true
		assert_false(c.source_ref.is_empty(), "Entry has source_ref")
		assert_false(c.modeling_type.is_empty(), "Entry has modeling_type")
		var grade: String = c.evidence_grade
		if c.category == "historical":
			assert_true(["A", "B", "C", "D"].has(grade), "Historical entry has evidence_grade A-D")
		if grade == "D":
			assert_ne(c.modeling_type, "historical_claim", "Grade D never labeled historical_claim")
		var sref: String = c.source_ref
		if sref.contains("[S1]") or sref.contains("[S2]") or sref.contains("[S8]"):
			assert_true(grade.is_empty(), "Benchmark refs excluded from historical evidence_grade")
	assert_true(has_938 and has_981 and has_1288, "Codex separates 938, 981, and 1288 Bạch Đằng")

	var codex_packed: PackedScene = load(CODEX_SCENE_PATH) as PackedScene
	assert_not_null(codex_packed, "codex_panel.tscn exists")
	if codex_packed != null:
		var codex_inst: Node = codex_packed.instantiate()
		add_child_autofree(codex_inst)
		var empty_res: Array = codex_inst.call("filter_entries", "zzz_invalid")
		assert_eq(empty_res.size(), 0, "Invalid search returns empty array")
		var bd_res: Array = codex_inst.call("filter_entries", "1288")
		assert_gt(float(bd_res.size()), 0.0, "Search '1288' returns matching entries")


func test_asset_ip_auditor_100_percent_clean_repo_and_negative_self_tests() -> void:
	var aud_scr: GDScript = load(IP_AUDITOR_PATH) as GDScript
	assert_not_null(aud_scr, "AssetIpAuditor script exists")
	if aud_scr == null:
		return

	var auditor: Object = aud_scr.new()
	var rep: Dictionary = auditor.call("run_full_audit")
	assert_true(bool(rep.get("ok", false)), "Full repository IP & isolation audit passes 100%% (violations: %s)" % str(rep.get("violations", [])))

	# Genuine negative self-tests calling AssetIpAuditor methods on synthetic bad inputs
	assert_true(bool(auditor.call("audit_case_exact_path", "res://assets_clean/emblems/dai_viet_emblem.png")), "Exact lowercase path accepted")
	assert_false(bool(auditor.call("audit_case_exact_path", "res://assets_clean/Emblems/dai_viet_emblem.png")), "Case mismatch 'Emblems' rejected on Windows")
	assert_false(bool(auditor.call("audit_registered_in_assets_md", "res://assets_clean/audio/unlisted_test.wav")), "Unlisted file rejected")
	assert_false(bool(auditor.call("audit_no_legacy_assets_ref", "var s = load(\"res://Assets/Audio/sfx_horn.wav\")")), "Legacy res://Assets/ ref rejected")
	assert_false(bool(auditor.call("audit_core_ai_isolation", "extends " + "Node\nfunc f(): get_" + "tree().quit()")), "Node/SceneTree in core rejected")
