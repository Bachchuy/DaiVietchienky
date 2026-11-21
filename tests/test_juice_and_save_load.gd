extends "res://tests/test_case.gd"

const SANDBOX_SCENE_PATH: String = "res://game/battle/battle.tscn"
const HIT_FLASH_SHADER_PATH: String = "res://assets_clean/shaders/hit_flash.gdshader"
const WATER_FLOW_SHADER_PATH: String = "res://assets_clean/shaders/water_flow.gdshader"
const JUICE_SCRIPT_PATH: String = "res://scripts/presentation/combat_juice_helper.gd"
const AUDIO_SCRIPT_PATH: String = "res://scripts/presentation/battle_audio_manager.gd"
const SAVE_SCRIPT_PATH: String = "res://sim/state/battle_save_manager.gd"

const ScenarioLoaderScript = preload("res://sim/state/scenario_loader.gd")
const CmdsScript = preload("res://sim/commands/battle_commands.gd")
const HexMathScript = preload("res://sim/rules/hex_math.gd")


func _spawn_sandbox() -> Node2D:
	var packed: PackedScene = load(SANDBOX_SCENE_PATH) as PackedScene
	assert_not_null(packed, "Sandbox scene exists")
	if packed == null:
		return null
	var inst: Node2D = packed.instantiate() as Node2D
	add_child_autofree(inst)
	return inst


func _clear_saves() -> void:
	for p: String in ["user://saves/battle_session.json", "user://saves/player_profile.json", "user://saves/player_profile.bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_hit_flash_shader_shared_material_and_reduce_flashing_wcag_cap() -> void:
	var hit_sh: Shader = load(HIT_FLASH_SHADER_PATH) as Shader
	var water_sh: Shader = load(WATER_FLOW_SHADER_PATH) as Shader
	assert_not_null(hit_sh, "hit_flash.gdshader loads cleanly")
	assert_not_null(water_sh, "water_flow.gdshader loads cleanly")
	if hit_sh == null or water_sh == null:
		return

	assert_true(hit_sh.code.contains("shader_type canvas_item"), "hit_flash is canvas_item shader")
	assert_true(hit_sh.code.contains("flash_modifier") and hit_sh.code.contains("hint_range(0.0, 1.0)"), "hit_flash exposes flash_modifier with hint_range(0.0, 1.0)")
	assert_true(water_sh.code.contains("shader_type canvas_item"), "water_flow is canvas_item shader")

	var sandbox: Node2D = _spawn_sandbox()
	var map_view: BattleMap = sandbox.call("get_map_view")
	var ground_layer: CanvasItem = map_view.get_layer_node("GroundLayer")
	assert_not_null(ground_layer, "GroundLayer exists")
	var water_mat := ShaderMaterial.new()
	water_mat.shader = water_sh
	assert_eq(water_mat.shader, water_sh, "water_flow.gdshader binds cleanly to ShaderMaterial")

	var juice: Object = sandbox.call("get_juice_helper") if sandbox.has_method("get_juice_helper") else null
	assert_not_null(juice, "BattleScene exposes get_juice_helper()")
	if juice == null:
		return

	var s1 := Sprite2D.new()
	var s2 := Sprite2D.new()
	add_child_autofree(s1)
	add_child_autofree(s2)

	juice.call("trigger_hit_flash", s1, false)
	var m1: Material = s1.material
	juice.call("trigger_hit_flash", s2, false)
	var m2: Material = s2.material
	assert_not_null(m1, "Hit flash attaches ShaderMaterial")
	assert_eq(m1, m2, "Sequential hits reuse shared ShaderMaterial")

	# Reduce Flashing soft tint + WCAG < 3 flashes/sec rate cap
	juice.set("reduce_flashing", true)
	var s3 := Sprite2D.new()
	add_child_autofree(s3)
	var accepted_flashes: int = 0
	for _i: int in range(4):
		if bool(juice.call("trigger_hit_flash", s3, true)):
			accepted_flashes += 1
		assert_null(s3.material, "Reduce Flashing skips ShaderMaterial swap")
	assert_gt(s3.self_modulate.r, s3.self_modulate.g, "Reduce Flashing applies soft red self_modulate tint")
	assert_true(accepted_flashes < 3, "Reduce Flashing caps flash frequency < 3/sec (got %d)" % accepted_flashes)


func test_local_hit_stop_squash_stretch_and_floating_text_without_global_time_scale() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var juice: Object = sandbox.call("get_juice_helper") if sandbox.has_method("get_juice_helper") else null
	assert_not_null(juice, "get_juice_helper() required")
	if juice == null:
		return

	var ctrl: BattleGameController = sandbox.call("get_controller")
	var rng_before: int = ctrl.context.rng.get_state()

	var anim_a := AnimatedSprite2D.new()
	var anim_b := AnimatedSprite2D.new()
	add_child_autofree(anim_a)
	add_child_autofree(anim_b)

	juice.call("play_local_hit_stop", [anim_a, anim_b], 0.08)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "Engine.time_scale remains 1.0 during local hit-stop")
	assert_almost_eq(anim_a.speed_scale, 0.0, 0.001, "Engaged visual A speed_scale paused to 0.0")
	assert_almost_eq(anim_b.speed_scale, 0.0, 0.001, "Engaged visual B speed_scale paused to 0.0")

	var heavy: Dictionary = juice.call("classify_impact_tier", true, true, 180)
	assert_gte(float(heavy.get("hit_stop_sec", 0.0)), 0.10, "Heavy hit-stop >= 100ms")
	assert_lte(float(heavy.get("hit_stop_sec", 1.0)), 0.15, "Heavy hit-stop <= 150ms")
	assert_gte(float(heavy.get("trauma", 0.0)), 0.70, "Heavy trauma >= 0.70")

	var small: Dictionary = juice.call("classify_impact_tier", false, false, 10)
	assert_almost_eq(float(small.get("hit_stop_sec", -1.0)), 0.0, 0.001, "Small tier has 0ms hit-stop")

	var target := Node2D.new()
	add_child_autofree(target)
	juice.call("play_squash_stretch", target)
	assert_gt(target.scale.x, 1.05, "Squash widens scale.x")
	assert_lt(target.scale.y, 0.95, "Squash compresses scale.y")

	var map_view: BattleMap = sandbox.call("get_map_view")
	var hud_layer: Node2D = map_view.get_layer_node("WorldSpaceUnitHudAndTextLayer")
	var before_children: int = hud_layer.get_child_count()
	var lbl_crit: Label = juice.call("spawn_floating_text", hud_layer, Vector2(100, 100), 96, &"crit")
	var lbl_blk: Label = juice.call("spawn_floating_text", hud_layer, Vector2(120, 100), 0, &"blocked")
	assert_eq(hud_layer.get_child_count(), before_children + 2, "Floating text spawned on WorldSpaceUnitHudAndTextLayer")
	assert_true(lbl_crit.text.contains("96") and lbl_crit.text.contains("💥"), "Crit floating text has symbol + value")
	assert_true(lbl_blk.text.contains("🛡️"), "Blocked floating text has shield symbol")
	assert_eq(ctrl.context.rng.get_state(), rng_before, "Combat juice never mutates BattleContext.rng")


func test_cpu_particles_pool_on_map_effect_layer_era_gating_and_quality_ratio() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var juice: Object = sandbox.call("get_juice_helper") if sandbox.has_method("get_juice_helper") else null
	assert_not_null(juice, "get_juice_helper() required")
	if juice == null:
		return

	var map_view: BattleMap = sandbox.call("get_map_view")
	var effect_layer: Node2D = map_view.get_layer_node("MapEffectLayer")
	assert_not_null(effect_layer, "MapEffectLayer exists")
	assert_eq(effect_layer.z_index, 44, "EffectsLayer z_index == 44")

	var initial_pool_count: int = effect_layer.get_child_count()
	assert_gt(float(initial_pool_count), 0.0, "Pre-warmed CPUParticles2D pool exists on MapEffectLayer")

	for preset: String in ["DustTrailCPU2D", "MetalSparksCPU2D", "WaterSplashCPU2D", "FireEmbersCPU2D", "MoraleAuraCPU2D"]:
		assert_true(bool(juice.call("spawn_particle_preset", preset, Vector2(120, 120), "Tran_Nguyen")), "Preset %s valid in 1288" % preset)

	assert_false(bool(juice.call("spawn_particle_preset", "GunpowderSmokeCPU2D", Vector2(100, 100), "Tran_Nguyen")), "GunpowderSmokeCPU2D blocked in 1288 Tran_Nguyen")
	assert_true(bool(juice.call("spawn_particle_preset", "GunpowderSmokeCPU2D", Vector2(100, 100), "Tay_Son")), "GunpowderSmokeCPU2D permitted in XV+ Tay_Son")
	assert_false(bool(juice.call("spawn_particle_preset", "unknown_preset_999", Vector2.ZERO, "Tran_Nguyen")), "Unknown preset rejected safely")

	juice.call("set_vfx_quality", "Low")
	juice.call("spawn_particle_preset", "FireEmbersCPU2D", Vector2(100, 100), "Tran_Nguyen")
	var first_cpu: CPUParticles2D = effect_layer.get_child(0) as CPUParticles2D
	assert_almost_eq(first_cpu.amount_ratio, 0.4, 0.01, "Low VFX quality sets amount_ratio = 0.4")

	for i: int in range(30):
		juice.call("spawn_particle_preset", "MetalSparksCPU2D", Vector2(40 + i, 50), "Tran_Nguyen")
	assert_eq(effect_layer.get_child_count(), initial_pool_count, "Pool node count constant across 30 consecutive bursts")


func test_four_bus_audio_pool_era_gating_and_clean_synthesized_wavs() -> void:
	var sandbox: Node2D = _spawn_sandbox()
	var audio_mgr: Object = sandbox.call("get_audio_manager") if sandbox.has_method("get_audio_manager") else null
	assert_not_null(audio_mgr, "BattleSandboxCP1 exposes get_audio_manager()")
	if audio_mgr == null:
		return

	for bus_name: String in ["Master", "BGM", "SFX", "Voice/Horn", "UI"]:
		assert_ne(AudioServer.get_bus_index(bus_name), -1, "AudioServer bus %s exists" % bus_name)

	var has_limiter: bool = false
	for i: int in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			has_limiter = true
	assert_true(has_limiter, "Master bus has AudioEffectHardLimiter")

	var p2d_cnt: int = 0
	var pui_cnt: int = 0
	for child: Node in (audio_mgr as Node).get_children():
		if child is AudioStreamPlayer2D:
			p2d_cnt += 1
		elif child is AudioStreamPlayer:
			pui_cnt += 1
	assert_eq(p2d_cnt, 24, "24 AudioStreamPlayer2D pre-allocated")
	assert_gte(float(pui_cnt), 6.0, "At least 6 UI AudioStreamPlayer pre-allocated")

	audio_mgr.call("set_bus_linear_volume", "SFX", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.5), 0.1, "SFX dB matches linear_to_db(0.5)")
	audio_mgr.call("set_bus_linear_volume", "SFX", 0.0)
	assert_false(is_nan(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), "0.0 volume produces valid non-NaN dB")

	assert_true(bool(audio_mgr.call("play_sfx", "sword_hit", Vector2(100, 100), "Tran_Nguyen")), "sword_hit plays in 1288")
	assert_false(bool(audio_mgr.call("play_sfx", "gunfire", Vector2.ZERO, "Tran_Nguyen")), "gunfire blocked in 1288")
	assert_false(bool(audio_mgr.call("play_sfx", "missing_key_xyz", Vector2.ZERO, "Tran_Nguyen")), "Unknown key returns false")

	audio_mgr.call("set_bgm_state", &"player_turn")
	assert_eq(str(audio_mgr.call("get_bgm_state")), "player_turn", "BGM state transitions to player_turn")
	audio_mgr.call("set_bgm_state", &"climax_tide_fall")
	assert_eq(str(audio_mgr.call("get_bgm_state")), "climax_tide_fall", "BGM state transitions to climax_tide_fall")


func test_tier2_session_save_load_rng_precision_and_triggered_event_ids() -> void:
	_clear_saves()
	var save_scr: GDScript = load(SAVE_SCRIPT_PATH) as GDScript
	assert_not_null(save_scr, "BattleSaveManager script exists")
	if save_scr == null:
		return

	var save_mgr: Object = save_scr.new()
	var big_seed: int = 9223372036854775783
	var ctrl1: BattleGameController = ScenarioLoaderScript.load_stage(10101, big_seed)
	while ctrl1.current_round < 4:
		ctrl1.submit_command(CmdsScript.EndTurnCommand.new(ctrl1.current_faction_id))

	assert_true(ctrl1.event_manager.triggered_event_ids.has("evt_10101_tide_fall"), "Round 4 TideFall triggered")
	assert_true(bool(save_mgr.call("save_battle_session", ctrl1)), "save_battle_session succeeds")

	var fa: FileAccess = FileAccess.open("user://saves/battle_session.json", FileAccess.READ)
	var raw_dict: Dictionary = JSON.parse_string(fa.get_as_text()) as Dictionary
	fa.close()
	assert_eq(int(raw_dict.get("version", 0)), 1, "version == 1")
	assert_eq(str(raw_dict.get("rng_seed", "")), str(big_seed), "64-bit rng_seed preserved as exact String")
	assert_true(raw_dict.get("rng_state") is String, "rng_state stored as String")

	var ctrl2: BattleGameController = ScenarioLoaderScript.load_stage(10101, 1288)
	assert_true(bool(save_mgr.call("load_battle_session", ctrl2)), "load_battle_session succeeds")
	assert_eq(ctrl2.current_round, 4, "Round 4 restored")
	assert_eq(ctrl2.context.rng.get_state(), ctrl1.context.rng.get_state(), "RNG state restored bit-identically")
	assert_true(ctrl2.event_manager.triggered_event_ids.has("evt_10101_tide_fall"), "triggered_event_ids restored")
	assert_eq(int(ctrl2.context.map_state.get_terrain(HexMathScript.odd_r_to_axial(Vector2i(6, 4)))), int(BattleMapState.TerrainType.STAKED_WATER), "StakedWater terrain restored")


func test_tier3_player_profile_bak_recovery_and_best_star_non_regression() -> void:
	_clear_saves()
	var save_scr: GDScript = load(SAVE_SCRIPT_PATH) as GDScript
	assert_not_null(save_scr, "BattleSaveManager script exists")
	if save_scr == null:
		return
	var save_mgr: Object = save_scr.new()

	save_mgr.call("save_player_profile", {"stage_stars": {"10101": 2}, "reduce_flashing": true})
	save_mgr.call("save_player_profile", {"stage_stars": {"10101": 3}, "reduce_flashing": true})
	assert_true(FileAccess.file_exists("user://saves/player_profile.json"), "Primary profile created")
	assert_true(FileAccess.file_exists("user://saves/player_profile.bak"), "Backup .bak profile created on overwrite")

	# Corrupt primary -> automatic .bak recovery
	var fa: FileAccess = FileAccess.open("user://saves/player_profile.json", FileAccess.WRITE)
	fa.store_string("{CORRUPTED_JSON")
	fa.close()
	var recovered: Dictionary = save_mgr.call("load_player_profile")
	assert_eq(int(recovered.get("stage_stars", {}).get("10101", 0)), 2, "Recovered 2 stars from .bak")
	assert_true(bool(recovered.get("reduce_flashing", false)), "Recovered reduce_flashing from .bak")

	# Best star non-regression
	save_mgr.call("record_stage_clear", 10101, 3)
	save_mgr.call("record_stage_clear", 10101, 1)
	var prof_after: Dictionary = save_mgr.call("load_player_profile")
	assert_eq(int(prof_after.get("stage_stars", {}).get("10101", 0)), 3, "Best star count never downgrades from 3 to 1")
