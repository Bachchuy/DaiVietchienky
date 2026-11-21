extends GdTestCase

const UNIT_VIEW_SCENE_PATH: String = "res://game/battle/units/unit_view.tscn"
const UNIT_SCRIPTS: Array[String] = [
	"res://game/battle/units/unit_view.gd",
	"res://game/battle/units/unit_animator_component.gd",
	"res://game/battle/units/health_bar_component.gd",
	"res://game/battle/units/status_badge_component.gd",
]


func test_unit_view_scene_instantiates_components_and_isolates_shader_material() -> void:
	var packed: PackedScene = load(UNIT_VIEW_SCENE_PATH) as PackedScene
	assert_not_null(packed, "unit_view.tscn loads cleanly")
	if packed == null:
		return

	var view_a: UnitView = packed.instantiate() as UnitView
	var view_b: UnitView = packed.instantiate() as UnitView
	add_child_autofree(view_a)
	add_child_autofree(view_b)

	assert_not_null(view_a.sprite, "Sprite2D exported & wired")
	assert_not_null(view_a.strategic_token, "StrategicToken exported & wired")
	assert_not_null(view_a.anim_player, "AnimationPlayer exported & wired")
	assert_not_null(view_a.animator, "UnitAnimatorComponent exported & wired")
	assert_not_null(view_a.health_bar, "HealthBarComponent exported & wired")
	assert_not_null(view_a.status_badges, "StatusBadgeComponent exported & wired")

	var mat_a: ShaderMaterial = view_a.get_shader_material()
	var mat_b: ShaderMaterial = view_b.get_shader_material()
	assert_not_null(mat_a, "UnitView A has ShaderMaterial")
	assert_not_null(mat_b, "UnitView B has ShaderMaterial")
	assert_ne(mat_a, mat_b, "Each UnitView instance duplicates ShaderMaterial to avoid uniform leaks")

	view_a.set_selected(true)
	view_b.set_attack_target(true)
	assert_almost_eq(float(mat_a.get_shader_parameter("is_selected")), 1.0, 0.001, "View A selected == 1.0")
	assert_almost_eq(float(mat_b.get_shader_parameter("is_selected")), 0.0, 0.001, "View B unaffected by View A selection")
	assert_almost_eq(float(mat_b.get_shader_parameter("is_attack_target")), 1.0, 0.001, "View B attack_target == 1.0")
	assert_almost_eq(float(mat_a.get_shader_parameter("is_attack_target")), 0.0, 0.001, "View A unaffected by View B target")


func test_bind_all_twelve_troops_builds_animations_tint_and_strategic_lod() -> void:
	var packed: PackedScene = load(UNIT_VIEW_SCENE_PATH) as PackedScene
	var reg: DataRegistry = StaticDataLoader.load_registry()
	assert_not_null(packed, "unit_view.tscn exists")
	assert_not_null(reg, "DataRegistry loads")
	if packed == null or reg == null:
		return

	assert_eq(reg.troops.size(), 12, "Testing all 12 canonical troops")
	for i: int in range(reg.troops.size()):
		var t: TroopDef = reg.troops[i]
		var faction_id: int = 1 if i % 2 == 0 else 2
		var unit: BattleUnit = BattleUnit.from_troop_dict(100 + i, faction_id, Vector2i(i, 0), t.to_troop_dict())
		var view: UnitView = packed.instantiate() as UnitView
		add_child_autofree(view)
		view.bind_unit(unit, t)

		assert_eq(view.get_unit_id(), unit.unit_id, "Bound unit_id matches")
		assert_eq(view.get_faction_id(), faction_id, "Bound faction_id matches")
		assert_eq(view.get_troop_id(), t.troop_id, "Bound troop_id matches")
		assert_not_null(view.sprite.texture, "Sprite texture resolved for %d" % t.troop_id)
		assert_not_null(view.strategic_token.texture, "Strategic token resolved for %d" % t.troop_id)
		for clip: String in ["idle", "walk", "attack", "hurt", "death"]:
			assert_true(view.animator.has_anim(clip), "Clip '%s' built for troop %d" % [clip, t.troop_id])

		var expected_tint: Color = view.dai_viet_tint if faction_id == 1 else view.dai_nguyen_tint
		var mat: ShaderMaterial = view.get_shader_material()
		assert_eq(mat.get_shader_parameter("target_color"), expected_tint, "Shader tint matches faction")

		if t.troop_id == 40103 or t.troop_id == 40903:
			assert_almost_eq(view.sprite.scale.x, 1.2, 0.01, "Mounted troop uses 1.2x scale")
		else:
			assert_almost_eq(view.sprite.scale.x, 1.5, 0.01, "Foot/naval troop uses 1.5x scale")

		view.set_strategic_lod(true)
		assert_true(view.is_strategic_lod(), "Strategic LOD enabled")
		assert_false(view.sprite.visible, "Sprite hidden in strategic LOD")
		assert_true(view.strategic_token.visible, "Token visible in strategic LOD")
		view.set_strategic_lod(false)
		assert_true(view.sprite.visible, "Sprite restored when LOD disabled")
		assert_false(view.strategic_token.visible, "Token hidden when LOD disabled")


func test_health_bar_banners_status_badges_and_death_state_sync() -> void:
	var packed: PackedScene = load(UNIT_VIEW_SCENE_PATH) as PackedScene
	var reg: DataRegistry = StaticDataLoader.load_registry()
	if packed == null or reg == null:
		return

	var spear_def: TroopDef = reg.get_troop(40101)
	var unit: BattleUnit = BattleUnit.from_troop_dict(55, 1, Vector2i(2, 8), spear_def.to_troop_dict())
	unit.max_stack = 3
	unit.troop_stack = 3
	unit.state.max_hp = 480
	unit.state.current_hp = 480
	unit.is_commander_in_chief = true
	unit.state.morale = UnitCombatState.MoraleLevel.HIGH
	unit.facing = 3  # West -> flip_h true

	var view: UnitView = packed.instantiate() as UnitView
	add_child_autofree(view)
	view.bind_unit(unit, spear_def)

	assert_true(view.sprite.flip_h, "Facing West flips sprite left")
	assert_eq(view.health_bar.get_active_banners(), 3, "Full 480/480 HP -> 3 banners")
	assert_almost_eq(view.health_bar.get_hp_ratio(), 1.0, 0.001, "Full HP ratio 1.0")
	var badges: Array[String] = view.status_badges.get_active_badges()
	assert_true(badges.has("COMMANDER"), "Commander badge active")
	assert_true(badges.has("MORALE_HIGH"), "High morale badge active")

	# Damage down to 50% (240/480 -> 2 banners) + acted + march disabled + chaos
	unit.state.current_hp = 240
	unit.state.has_acted = true
	unit.state.march_disabled_turns = 2
	unit.state.apply_chaos(2)
	view.sync_from_unit(unit)

	assert_eq(view.health_bar.get_active_banners(), 2, "240/480 (50%) -> 2 banners")
	assert_almost_eq(view.sprite.modulate.r, 0.70, 0.01, "Acted unit slightly dimmed")
	var chaos_badges: Array[String] = view.status_badges.get_active_badges()
	assert_true(chaos_badges.has("MORALE_CHAOS"), "CHAOS badge shown")
	assert_true(chaos_badges.has("MARCH_LOCKED"), "MARCH_LOCKED badge shown")
	assert_true(chaos_badges.has("ACTED"), "ACTED badge shown")

	# Play attack and move
	view.play_attack(Vector2(100.0, 0.0))
	assert_eq(view.animator.get_current_anim(), "attack", "play_attack plays 'attack'")
	assert_false(view.sprite.flip_h, "Attacking East clears flip_h")

	# Defeat unit -> hides overlays & triggers death animation
	unit.state.current_hp = 0
	view.sync_from_unit(unit)
	assert_false(view.health_bar.visible, "Defeated unit hides health bar")
	assert_false(view.status_badges.visible, "Defeated unit hides status badges")
	assert_eq(view.animator.get_current_anim(), "death", "Defeated unit enters death anim")


func test_unit_view_scripts_under_400_lines_and_clean_architecture() -> void:
	for path: String in UNIT_SCRIPTS:
		assert_true(FileAccess.file_exists(path), "Script exists: %s" % path)
		var txt: String = FileAccess.get_file_as_string(path)
		var line_count: int = txt.split("\n").size()
		assert_lte(line_count, 400, "%s is %d lines (<= 400 limit)" % [path, line_count])
		assert_false(txt.contains("get_node(\"/root/"), "%s avoids get_node('/root/...')" % path)
		assert_false(txt.contains("CombatPreviewBox"), "%s avoids CombatPreviewBox (DEC-026)" % path)
