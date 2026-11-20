class_name BattleHudController
extends Node

signal briefing_dismissed()
signal dialogue_finished()
signal retry_requested()
signal replay_requested()
signal next_stage_requested()
signal save_and_exit_requested()
signal accessibility_changed(reduce_flashing: bool, vfx_quality: int, shake_scale: float)

const TOP_BAR_HEIGHT: float = 40.0
const BOTTOM_DOCK_HEIGHT: float = 56.0
const PREVIEW_BOX_SIZE: Vector2 = Vector2(396.0, 152.0)

const TERRAIN_NAMES: Dictionary[int, String] = {
	0: "Đồng bằng (2 MP)",
	1: "Rừng tre (+20% Thủ)",
	2: "Đồi cao (+15% Thủ, Cao điểm)",
	3: "Đầm lầy (-10% Thủ)",
	4: "Sông cạn / Bờ bãi",
	5: "Sông sâu Bạch Đằng",
	6: "Thành lũy (+30% Thủ, CoC x2)",
	7: "Đường cái / Bến thuyền (1 MP)",
	8: "Bãi cọc ngầm lộ diện",
}

const MORALE_NAMES: Dictionary[int, String] = {
	0: "HỖN LOẠN (CHAOS)",
	1: "Dao Động (LOW)",
	2: "Ổn Định (NORMAL)",
	3: "Hưng Phấn (HIGH)",
}

var reduce_flashing: bool = false
var vfx_quality_index: int = 2

var _sandbox: Node2D = null
var _hud_layer: CanvasLayer = null
var _controller: BattleGameController = null
var _map_view: BattleMapView = null
var _camera: BattleCameraController = null
var _input_fsm: BattleInputFSM = null

var _top_bar: Panel = null
var _top_bar_hbox: HBoxContainer = null
var _pause_btn: Button = null
var _mode_round_label: Label = null
var _mana_label: Label = null
var _economy_container: HBoxContainer = null
var _coin_label: Label = null
var _food_label: Label = null
var _tech_label: Label = null
var _objective_label: Label = null
var _perf_label: Label = null

var _bottom_dock: Panel = null
var _bottom_dock_hbox: HBoxContainer = null
var _unit_card_label: Label = null
var _banner_label: Label = null
var _move_btn: Button = null
var _attack_btn: Button = null
var _skill_btn: Button = null
var _undo_btn: Button = null
var _wait_btn: Button = null
var _end_turn_btn: Button = null

var _preview_box: Panel = null
var _preview_vbox: VBoxContainer = null
var _preview_title_label: Label = null
var _preview_hp_label: Label = null
var _preview_stats_label: Label = null
var _preview_mods_label: Label = null
var _preview_target_unit: BattleUnit = null
var _preview_blink_time: float = 0.0

var _briefing_modal: Panel = null
var _briefing_title_label: Label = null
var _briefing_meta_label: Label = null
var _briefing_body_label: Label = null
var _briefing_start_btn: Button = null

var _dialogue_modal: Panel = null
var _dialogue_speaker_label: Label = null
var _dialogue_line_label: Label = null
var _dialogue_continue_btn: Button = null

var _summary_modal: Panel = null
var _summary_title_label: Label = null
var _summary_stars_label: Label = null
var _combat_log_panel: PanelContainer = null
var _combat_log_label: Label = null
var _retry_btn: Button = null
var _replay_btn: Button = null
var _next_stage_btn: Button = null

var _pause_modal: Panel = null
var _shake_slider: HSlider = null
var _reduce_flashing_check: CheckBox = null
var _vfx_quality_option: OptionButton = null
var _master_vol_slider: HSlider = null
var _bgm_vol_slider: HSlider = null
var _sfx_vol_slider: HSlider = null
var _resume_btn: Button = null
var _restart_btn: Button = null
var _save_exit_btn: Button = null
var _tutorial_overlay: TutorialOverlay = null
var _codex_panel: CodexPanel = null

var _stage_dialogues: Dictionary = {}
var _dialogue_queue: Array[Dictionary] = []
var _combat_log_entries: Array[String] = []
var _objective_text: String = "Mục tiêu: Giữ Bến Tín Hiệu (2,8) & Hạ Ô Mã Nhi"
var _mode_title: String = "ĐẠI VIỆT CHIẾN KỲ [CP4] — Bạch Đằng 12×10"
var _last_viewport_size: Vector2 = Vector2(1280.0, 720.0)
var _last_synced_shake_val: float = -1.0
var _last_synced_flash_val: bool = false
var _last_synced_vfx_idx: int = -1
var _summary_shown_for_outcome: int = 0


func setup(
	sandbox: Node2D,
	hud_layer: CanvasLayer,
	map_view: BattleMapView,
	camera: BattleCameraController,
	input_fsm: BattleInputFSM
) -> void:
	_sandbox = sandbox
	_hud_layer = hud_layer
	_map_view = map_view
	_camera = camera
	_input_fsm = input_fsm

	_build_top_status_bar()
	_build_bottom_command_dock()
	_build_combat_preview_box()
	_build_briefing_modal()
	_build_dialogue_modal()
	_build_result_summary_modal()
	_build_pause_settings_modal()

	_tutorial_overlay = TutorialOverlay.new()
	_tutorial_overlay.visible = false
	_hud_layer.add_child(_tutorial_overlay)

	_codex_panel = CodexPanel.new()
	_codex_panel.visible = false
	_hud_layer.add_child(_codex_panel)

	apply_viewport_layout(_get_current_viewport_size())


func bind_battle(
	controller: BattleGameController,
	stage_meta: Dictionary,
	dialogues: Dictionary,
	show_briefing: bool = true
) -> void:
	_controller = controller
	_stage_dialogues = dialogues.duplicate(true)
	_dialogue_queue.clear()
	_combat_log_entries.clear()
	_summary_shown_for_outcome = 0

	if _summary_modal != null:
		_summary_modal.visible = false
	if _pause_modal != null:
		_pause_modal.visible = false
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = false
	if _codex_panel != null:
		_codex_panel.visible = false
	hide_combat_preview()

	if _controller != null:
		if _controller.event_manager != null:
			if not _controller.event_manager.dialogue_requested.is_connected(_on_event_dialogue_requested):
				_controller.event_manager.dialogue_requested.connect(_on_event_dialogue_requested)
			if not _controller.event_manager.camera_focus_requested.is_connected(_on_event_camera_focus_requested):
				_controller.event_manager.camera_focus_requested.connect(_on_event_camera_focus_requested)
			for queued_dlg_id: String in _controller.event_manager.dialogue_queue:
				_enqueue_dialogue_by_id(queued_dlg_id, false)
		if not _controller.round_started.is_connected(_on_controller_round_started):
			_controller.round_started.connect(_on_controller_round_started)
		if not _controller.faction_turn_started.is_connected(_on_controller_faction_turn_started):
			_controller.faction_turn_started.connect(_on_controller_faction_turn_started)

	_populate_briefing(stage_meta)
	append_combat_log("Khai chiến: %s (Vòng 1/%d)" % [
		str(stage_meta.get("name", "Đại Chiến Bạch Đằng 1288")),
		_controller.max_rounds if _controller != null else 10,
	])

	if show_briefing and _briefing_modal != null:
		_briefing_modal.visible = true
		if _dialogue_modal != null:
			_dialogue_modal.visible = false
	else:
		if _briefing_modal != null:
			_briefing_modal.visible = false
		_present_next_dialogue_if_any()

	sync_with_controller(_controller)
	update_dock_buttons()
	apply_viewport_layout(_get_current_viewport_size())


func _process(delta: float) -> void:
	var vp: Vector2 = _get_current_viewport_size()
	if vp != _last_viewport_size:
		apply_viewport_layout(vp)

	_sync_accessibility_widgets()

	if _preview_box != null and _preview_box.visible:
		_preview_blink_time += delta * 5.0
		var alpha: float = 0.72 + 0.28 * sin(_preview_blink_time)
		if _preview_hp_label != null:
			_preview_hp_label.modulate = Color(1.0, 0.92, 0.75, alpha)

	if _controller != null:
		sync_with_controller(_controller)
		update_dock_buttons()
		if _controller.outcome != BattleGameController.BattleOutcome.ONGOING and _summary_shown_for_outcome != int(_controller.outcome):
			show_result_summary(int(_controller.outcome))


func _get_current_viewport_size() -> Vector2:
	if get_tree() != null and get_tree().root != null:
		var sz: Vector2 = Vector2(get_tree().root.size)
		if sz.x >= 320.0 and sz.y >= 240.0:
			return sz
	return Vector2(1280.0, 720.0)


func apply_viewport_layout(vp_size: Vector2) -> void:
	var vp: Vector2 = Vector2(maxf(640.0, vp_size.x), maxf(360.0, vp_size.y))
	_last_viewport_size = vp

	if _top_bar != null:
		_top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_top_bar.custom_minimum_size = Vector2(0.0, TOP_BAR_HEIGHT)
		_top_bar.position = Vector2.ZERO
		_top_bar.size = Vector2(vp.x, TOP_BAR_HEIGHT)
		if _top_bar_hbox != null:
			_top_bar_hbox.position = Vector2(10.0, 4.0)
			_top_bar_hbox.size = Vector2(maxf(100.0, vp.x - 20.0), TOP_BAR_HEIGHT - 8.0)

	if _bottom_dock != null:
		_bottom_dock.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_bottom_dock.custom_minimum_size = Vector2(0.0, BOTTOM_DOCK_HEIGHT)
		_bottom_dock.position = Vector2(0.0, vp.y - BOTTOM_DOCK_HEIGHT)
		_bottom_dock.size = Vector2(vp.x, BOTTOM_DOCK_HEIGHT)
		if _bottom_dock_hbox != null:
			_bottom_dock_hbox.position = Vector2(10.0, 4.0)
			_bottom_dock_hbox.size = Vector2(maxf(100.0, vp.x - 20.0), BOTTOM_DOCK_HEIGHT - 8.0)

	_center_modal(_briefing_modal, Vector2(minf(580.0, vp.x - 40.0), minf(270.0, vp.y - 120.0)), vp)
	_center_modal(_summary_modal, Vector2(minf(640.0, vp.x - 40.0), minf(360.0, vp.y - 120.0)), vp)
	_center_modal(_pause_modal, Vector2(minf(540.0, vp.x - 40.0), minf(350.0, vp.y - 120.0)), vp)

	if _dialogue_modal != null:
		var dw: float = minf(720.0, vp.x - 48.0)
		var dh: float = 132.0
		_dialogue_modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_dialogue_modal.custom_minimum_size = Vector2(dw, dh)
		_dialogue_modal.size = Vector2(dw, dh)
		_dialogue_modal.position = Vector2((vp.x - dw) * 0.5, maxf(TOP_BAR_HEIGHT + 8.0, vp.y - BOTTOM_DOCK_HEIGHT - dh - 12.0))
		if _dialogue_modal.get_child_count() > 0 and _dialogue_modal.get_child(0) is Control:
			var dv: Control = _dialogue_modal.get_child(0) as Control
			dv.position = Vector2(14.0, 10.0)
			dv.size = Vector2(maxf(80.0, dw - 28.0), maxf(40.0, dh - 20.0))

	if _preview_box != null and _preview_box.visible:
		_clamp_preview_box_to_viewport(vp)


func _input(event: InputEvent) -> void:
	if _hud_layer == null:
		return
	var click_pos := Vector2(-9999.0, -9999.0)
	var is_release: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			click_pos = mb.position
			is_release = true
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if not st.pressed:
			click_pos = st.position
			is_release = true
	if not is_release:
		return

	var scopes: Array[Control] = []
	if _briefing_modal != null and _briefing_modal.visible:
		scopes.append(_briefing_modal)
	elif _dialogue_modal != null and _dialogue_modal.visible:
		scopes.append(_dialogue_modal)
	elif _summary_modal != null and _summary_modal.visible:
		scopes.append(_summary_modal)
	elif _pause_modal != null and _pause_modal.visible:
		scopes.append(_pause_modal)
	else:
		if _top_bar != null and _top_bar.visible:
			scopes.append(_top_bar)
		if _bottom_dock != null and _bottom_dock.visible:
			scopes.append(_bottom_dock)
		for child: Node in _hud_layer.get_children():
			if child is Control and (child as Control).visible and not scopes.has(child as Control):
				scopes.append(child as Control)

	for scope: Control in scopes:
		var btn: BaseButton = _find_hit_button(scope, click_pos)
		if btn != null and not btn.disabled:
			if btn is CheckBox:
				btn.button_pressed = not btn.button_pressed
			btn.pressed.emit()
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			return


func _find_hit_button(root_node: Node, screen_pos: Vector2) -> BaseButton:
	if root_node == null:
		return null
	if root_node is Control and not (root_node as Control).visible:
		return null
	if root_node is BaseButton:
		var b: BaseButton = root_node as BaseButton
		if b.get_global_rect().has_point(screen_pos):
			return b
	for child: Node in root_node.get_children():
		var hit: BaseButton = _find_hit_button(child, screen_pos)
		if hit != null:
			return hit
	return null


func _center_modal(modal: Control, target_size: Vector2, vp: Vector2) -> void:
	if modal == null:
		return
	modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	modal.custom_minimum_size = target_size
	modal.size = target_size
	modal.position = (vp - target_size) * 0.5
	if modal.get_child_count() > 0 and modal.get_child(0) is Control:
		var inner: Control = modal.get_child(0) as Control
		inner.position = Vector2(14.0, 12.0)
		inner.size = Vector2(maxf(80.0, target_size.x - 28.0), maxf(40.0, target_size.y - 24.0))


func set_mode_title(title: String) -> void:
	_mode_title = title
	if _controller != null:
		sync_with_controller(_controller)


func set_objective_text(text: String) -> void:
	_objective_text = text
	if _objective_label != null:
		_objective_label.text = text
	apply_viewport_layout(_get_current_viewport_size())


func set_bottom_banner(msg: String) -> void:
	if _banner_label != null:
		_banner_label.text = msg


func get_bottom_banner() -> String:
	return _banner_label.text if _banner_label != null else ""


func get_top_bar() -> Panel:
	return _top_bar


func get_bottom_dock() -> Panel:
	return _bottom_dock


func get_selection_label() -> Label:
	return _banner_label


func get_mode_label() -> Label:
	return _mode_round_label


func get_perf_label() -> Label:
	return _perf_label


func get_tutorial_overlay() -> TutorialOverlay:
	return _tutorial_overlay


func get_codex_panel() -> CodexPanel:
	return _codex_panel


func is_any_modal_open() -> bool:
	if _briefing_modal != null and _briefing_modal.visible:
		return true
	if _dialogue_modal != null and _dialogue_modal.visible:
		return true
	if _summary_modal != null and _summary_modal.visible:
		return true
	if _pause_modal != null and _pause_modal.visible:
		return true
	return false


func dismiss_briefing() -> void:
	if _briefing_modal != null and _briefing_modal.visible:
		_briefing_modal.visible = false
		briefing_dismissed.emit()
	_present_next_dialogue_if_any()


func dismiss_all_modals() -> void:
	if _briefing_modal != null:
		_briefing_modal.visible = false
	_dialogue_queue.clear()
	if _dialogue_modal != null:
		_dialogue_modal.visible = false
	if _summary_modal != null:
		_summary_modal.visible = false
	if _pause_modal != null:
		_pause_modal.visible = false
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = false
	if _codex_panel != null:
		_codex_panel.visible = false
	if _camera != null:
		_camera.camera_locked = false
	if _input_fsm != null:
		_input_fsm.set_input_locked(false)


func sync_with_controller(ctrl: BattleGameController = null) -> void:
	if ctrl != null:
		_controller = ctrl
	if _controller == null:
		return

	var fac_text: String = "ĐẠI VIỆT" if _controller.current_faction_id == 1 else "ĐẠI NGUYÊN"
	var status_text: String = "LƯỢT: %s" % fac_text
	if _controller.outcome == BattleGameController.BattleOutcome.VICTORY:
		var stars_n: int = 1
		if _controller.victory_evaluator != null:
			stars_n = int(_controller.victory_evaluator.evaluate_stars(_controller).get("stars", 1))
		status_text = "CHIẾN THẮNG (%d/3 SAO)" % stars_n
	elif _controller.outcome == BattleGameController.BattleOutcome.DEFEAT:
		status_text = "THẤT BẠI"

	if _mode_round_label != null:
		_mode_round_label.text = "%s | VÒNG %02d/%02d | %s" % [
			_mode_title,
			_controller.current_round,
			_controller.max_rounds,
			status_text,
		]

	var mana_val: int = 0
	var coin_val: int = 0
	var food_val: int = 0
	var tech_val: int = 0
	var eco_obj: Variant = _controller.get("economy")
	if eco_obj is Object and (eco_obj as Object).has_method("get_resource"):
		var eo: Object = eco_obj as Object
		var p_fac: int = _controller.player_faction_id
		mana_val = maxi(0, int(eo.call("get_resource", p_fac, "mana")))
		coin_val = int(eo.call("get_resource", p_fac, "coin"))
		food_val = int(eo.call("get_resource", p_fac, "food"))
		tech_val = maxi(0, int(eo.call("get_resource", p_fac, "tech")))

	if _mana_label != null:
		_mana_label.text = "🔮 Mana: %d" % maxi(0, mana_val)

	var show_eco: bool = _controller.enable_economy
	if _economy_container != null:
		_economy_container.visible = show_eco
	if _coin_label != null:
		_coin_label.visible = show_eco
		_coin_label.text = "🪙 Tiền: %d" % coin_val
	if _food_label != null:
		_food_label.visible = show_eco
		_food_label.text = "🌾 Lương: %d" % food_val
	if _tech_label != null:
		_tech_label.visible = show_eco
		_tech_label.text = "⚙️ Kỹ nghệ: %d" % tech_val

	if _perf_label != null and _camera != null and _map_view != null and _controller.context != null and _controller.context.map_state != null:
		var fps: int = Engine.get_frames_per_second()
		var lod_text: String = "TOKEN" if _map_view.is_strategic_lod() else "MODEL"
		_perf_label.text = "FPS: %d | %.2fx [%s] | Quân: %d" % [
			fps if fps > 0 else 60,
			_camera.zoom.x,
			lod_text,
			_controller.context.map_state.get_all_units().size(),
		]


func update_unit_card(axial: Vector2i, unit: BattleUnit) -> void:
	if _unit_card_label == null or _controller == null or _controller.context == null:
		return
	var map_state: BattleMapState = _controller.context.map_state
	if map_state == null:
		return

	if unit == null:
		if _map_view != null and _map_view.has_selected_hex() and map_state.is_valid_hex(axial):
			var off: Vector2i = HexMath.axial_to_odd_r(axial)
			var t_name: String = TERRAIN_NAMES.get(int(map_state.get_terrain(axial)), "Địa hình")
			_unit_card_label.text = "Ô (%d,%d) — %s (Trống)" % [off.x, off.y, t_name]
		else:
			_unit_card_label.text = "Chưa chọn đạo quân"
		update_dock_buttons()
		return

	var off_u: Vector2i = HexMath.axial_to_odd_r(unit.hex_position)
	var t_str: String = TERRAIN_NAMES.get(int(map_state.get_terrain(unit.hex_position)), "Địa hình")
	var fac_str: String = "Đại Việt" if unit.faction_id == 1 else "Đại Nguyên"
	var gen_prefix: String = ("%s — " % unit.general_name) if not unit.general_name.is_empty() else ""
	var morale_str: String = MORALE_NAMES.get(int(unit.state.morale), "Ổn Định")
	_unit_card_label.text = "[%s] %s%s | HP: %d/%d (%d cờ) | Sĩ khí: %s | MP: %d/%d | (%d,%d) %s" % [
		fac_str,
		gen_prefix,
		unit.display_name,
		unit.state.current_hp,
		unit.state.max_hp,
		unit.get_active_banners(),
		morale_str,
		unit.state.current_mp,
		unit.max_mp,
		off_u.x,
		off_u.y,
		t_str,
	]
	update_dock_buttons()


func update_dock_buttons() -> void:
	if _controller == null or _input_fsm == null:
		return
	var is_player_turn: bool = (
		_controller.outcome == BattleGameController.BattleOutcome.ONGOING
		and _controller.current_faction_id == _controller.player_faction_id
	)
	var st: BattleInputFSM.State = _input_fsm.get_state()
	var active_u: BattleUnit = _input_fsm.get_active_unit()
	var can_act: bool = (
		is_player_turn
		and active_u != null
		and active_u.faction_id == _controller.player_faction_id
		and not active_u.state.has_acted
	)

	var has_target_in_range: bool = false
	if can_act and _controller.context != null and _controller.context.map_state != null:
		var ms: BattleMapState = _controller.context.map_state
		var nav: HexGridNavigator = _controller.context.navigator
		for ah: Vector2i in nav.get_attackable_hexes(ms, active_u, active_u.hex_position):
			var occ: BattleUnit = ms.get_unit_at(ah)
			if occ != null and ms.is_hostile(active_u.faction_id, occ.faction_id):
				has_target_in_range = true
				break

	if _move_btn != null:
		_move_btn.disabled = not (can_act and st == BattleInputFSM.State.UNIT_SELECTED and active_u.state.can_move())
	if _attack_btn != null:
		_attack_btn.disabled = not (
			can_act
			and (st == BattleInputFSM.State.AIMING_TARGET or ((st == BattleInputFSM.State.UNIT_SELECTED or st == BattleInputFSM.State.POST_MOVE_ACTION) and has_target_in_range))
		)
	if _skill_btn != null:
		_skill_btn.disabled = not (
			can_act
			and _input_fsm.can_active_unit_use_skill()
			and (st == BattleInputFSM.State.UNIT_SELECTED or st == BattleInputFSM.State.POST_MOVE_ACTION or st == BattleInputFSM.State.SKILL_TARGETING)
		)
	if _undo_btn != null:
		_undo_btn.disabled = not (is_player_turn and _input_fsm.can_undo_post_move())
	if _wait_btn != null:
		_wait_btn.disabled = not (
			can_act
			and (st == BattleInputFSM.State.UNIT_SELECTED or st == BattleInputFSM.State.POST_MOVE_ACTION)
		)
	if _end_turn_btn != null:
		_end_turn_btn.disabled = not is_player_turn


func show_combat_preview(attacker: BattleUnit, defender: BattleUnit, prev: Dictionary) -> void:
	if _preview_box == null or attacker == null or defender == null:
		return
	_preview_target_unit = defender
	_preview_blink_time = 0.0

	var min_dmg: int = int(prev.get("min_damage", 0))
	var max_dmg: int = int(prev.get("max_damage", 0))
	var crit_rate: int = int(prev.get("crit_rate", 0))
	var crit_max: int = int(prev.get("crit_max_damage", 0))
	var will_retaliate: bool = bool(prev.get("will_retaliate", false))
	var c_min: int = int(prev.get("counter_min_damage", 0))
	var c_max: int = int(prev.get("counter_max_damage", 0))
	var matchup_pct: int = int(prev.get("damage_percent", 100))
	var def_terrain_mult: float = float(prev.get("defender_terrain_def_mult", 1.0))
	var is_flanked: bool = bool(prev.get("is_flanked", false))

	var hp_after_max: int = maxi(0, defender.state.current_hp - min_dmg)
	var hp_after_min: int = maxi(0, defender.state.current_hp - max_dmg)

	var atk_title: String = attacker.general_name if not attacker.general_name.is_empty() else attacker.display_name
	var def_title: String = defender.general_name if not defender.general_name.is_empty() else defender.display_name
	_preview_title_label.text = "DỰ BÁO GIAO CHIẾN: %s ⚔ %s" % [atk_title, def_title]
	_preview_hp_label.text = "HP Mục tiêu: %d/%d -> Dự kiến còn %d~%d HP (-%d~%d)" % [
		defender.state.current_hp,
		defender.state.max_hp,
		hp_after_min,
		hp_after_max,
		min_dmg,
		max_dmg,
	]

	var counter_str: String = (
		"Phản kích: %d ~ %d ST" % [c_min, c_max]
		if will_retaliate and c_max > 0
		else "Phản kích: 0 (Không phản kích)"
	)
	_preview_stats_label.text = "ST dự kiến: %d ~ %d | Bạo kích (Crit): %d%% (~%d ST) | %s" % [
		min_dmg,
		max_dmg,
		crit_rate,
		crit_max,
		counter_str,
	]

	var flank_str: String = " | Bọc sườn (Flank +15%)" if is_flanked else ""
	var starv_str: String = ""
	if bool(prev.get("is_starving", false)):
		starv_str = " | Đói lương (Starvation -25% / x0.75)"
	elif _controller != null and _controller.enable_economy:
		var eco_v: Variant = _controller.get("economy")
		if eco_v is Object and (eco_v as Object).has_method("is_starving"):
			if bool((eco_v as Object).call("is_starving", attacker.faction_id)):
				starv_str = " | Đói lương (Starvation -25% / x0.75)"
	_preview_mods_label.text = "Khắc chế: %d%% | Thủ địa hình: x%.2f | Cờ: %dx%s%s" % [
		matchup_pct,
		def_terrain_mult,
		attacker.get_active_banners(),
		flank_str,
		starv_str,
	]

	if _map_view != null and _map_view.has_method("set_projected_target_damage"):
		_map_view.call("set_projected_target_damage", defender.hex_position, max_dmg)

	_preview_box.visible = true
	_preview_box.size = PREVIEW_BOX_SIZE
	if _preview_vbox != null:
		_preview_vbox.position = Vector2(10.0, 6.0)
		_preview_vbox.size = PREVIEW_BOX_SIZE - Vector2(20.0, 12.0)
	_clamp_preview_box_to_viewport(_last_viewport_size)


func _clamp_preview_box_to_viewport(vp: Vector2) -> void:
	if _preview_box == null:
		return
	var desired := Vector2((vp.x - PREVIEW_BOX_SIZE.x) * 0.5, TOP_BAR_HEIGHT + 12.0)
	if _preview_target_unit != null and _sandbox != null and _map_view != null:
		var world_pos: Vector2 = HexMath.axial_to_world(_preview_target_unit.hex_position, _map_view.hex_size)
		var screen_pos: Vector2 = _sandbox.get_canvas_transform() * world_pos
		desired = screen_pos + Vector2(36.0, -PREVIEW_BOX_SIZE.y * 0.5)
		if desired.x + PREVIEW_BOX_SIZE.x > vp.x - 10.0:
			desired.x = screen_pos.x - PREVIEW_BOX_SIZE.x - 36.0

	var min_x: float = 8.0
	var max_x: float = maxf(min_x, vp.x - PREVIEW_BOX_SIZE.x - 8.0)
	var min_y: float = TOP_BAR_HEIGHT + 6.0
	var max_y: float = maxf(min_y, vp.y - BOTTOM_DOCK_HEIGHT - PREVIEW_BOX_SIZE.y - 6.0)
	_preview_box.position = Vector2(
		clampf(desired.x, min_x, max_x),
		clampf(desired.y, min_y, max_y)
	)
	_preview_box.size = PREVIEW_BOX_SIZE
	if _preview_vbox != null:
		_preview_vbox.position = Vector2(10.0, 6.0)
		_preview_vbox.size = PREVIEW_BOX_SIZE - Vector2(20.0, 12.0)


func hide_combat_preview() -> void:
	_preview_target_unit = null
	if _preview_box != null:
		_preview_box.visible = false
	if _map_view != null and _map_view.has_method("clear_projected_target_damage"):
		_map_view.call("clear_projected_target_damage")


func queue_dialogue_id(dialogue_id: String) -> void:
	_enqueue_dialogue_by_id(dialogue_id, true)


func _enqueue_dialogue_by_id(dialogue_id: String, present_now: bool) -> void:
	if dialogue_id.is_empty():
		return
	if not _stage_dialogues.has(dialogue_id):
		push_warning("BattleHudController: Unknown dialogue_id '%s' ignored safely." % dialogue_id)
		return
	var entry: Variant = _stage_dialogues[dialogue_id]
	if entry is Dictionary:
		var d: Dictionary = entry as Dictionary
		_dialogue_queue.append({
			"id": dialogue_id,
			"speaker": str(d.get("speaker", "Tướng lĩnh")),
			"line": str(d.get("line", "")),
		})
	elif entry is Array:
		for item: Variant in entry as Array:
			if item is Dictionary:
				var di: Dictionary = item as Dictionary
				_dialogue_queue.append({
					"id": dialogue_id,
					"speaker": str(di.get("speaker", "Tướng lĩnh")),
					"line": str(di.get("line", "")),
				})
	if present_now:
		_present_next_dialogue_if_any()


func show_dialogue_entries(entries: Array) -> void:
	for item: Variant in entries:
		if item is Dictionary:
			var d: Dictionary = item as Dictionary
			_dialogue_queue.append({
				"speaker": str(d.get("speaker", "Tướng lĩnh")),
				"line": str(d.get("line", "")),
			})
	_present_next_dialogue_if_any()


func _present_next_dialogue_if_any() -> void:
	if _briefing_modal != null and _briefing_modal.visible:
		return
	if _dialogue_queue.is_empty():
		if _dialogue_modal != null:
			_dialogue_modal.visible = false
		if _camera != null:
			_camera.camera_locked = false
		if _input_fsm != null:
			_input_fsm.set_input_locked(false)
		dialogue_finished.emit()
		return

	var current: Dictionary = _dialogue_queue[0]
	if _dialogue_speaker_label != null:
		_dialogue_speaker_label.text = "🗣 %s" % str(current.get("speaker", "Tướng lĩnh"))
	if _dialogue_line_label != null:
		_dialogue_line_label.text = "\"%s\"" % str(current.get("line", ""))
	if _dialogue_modal != null:
		_dialogue_modal.visible = true
	apply_viewport_layout(_last_viewport_size)
	if _camera != null:
		_camera.camera_locked = true
	if _input_fsm != null:
		_input_fsm.set_input_locked(true)


func advance_dialogue() -> void:
	if not _dialogue_queue.is_empty():
		_dialogue_queue.pop_front()
	_present_next_dialogue_if_any()


func append_combat_log(entry: String) -> void:
	if entry.is_empty():
		return
	_combat_log_entries.append(entry)
	if _combat_log_label != null:
		_combat_log_label.text = "\n".join(_combat_log_entries)


func show_result_summary(outcome_code: int) -> void:
	if _summary_modal == null or _controller == null:
		return
	_summary_shown_for_outcome = outcome_code
	hide_combat_preview()
	if _dialogue_modal != null:
		_dialogue_modal.visible = false
	if _camera != null:
		_camera.camera_locked = false

	if outcome_code == int(BattleGameController.BattleOutcome.VICTORY):
		var star_res: Dictionary = (
			_controller.victory_evaluator.evaluate_stars(_controller)
			if _controller.victory_evaluator != null
			else {"stars": 1, "rounds_used": _controller.current_round, "player_hp_loss_percent": 0.0, "enemy_defeated_percent": 100.0, "details": []}
		)
		var stars: int = int(star_res.get("stars", 1))
		_summary_title_label.text = "CHIẾN THẮNG ĐẠI VIỆT — %d/3 SAO (%d ★)" % [stars, stars]
		var detail_lines: PackedStringArray = PackedStringArray()
		detail_lines.append("Hoàn tất tại Vòng %d/%d | Tổn thất HP: %.1f%% | Địch bị loại: %.1f%%" % [
			_controller.current_round,
			_controller.max_rounds,
			float(star_res.get("player_hp_loss_percent", 0.0)),
			float(star_res.get("enemy_defeated_percent", 0.0)),
		])
		var raw_details: Variant = star_res.get("details", [])
		if raw_details is Array:
			for d_var: Variant in raw_details as Array:
				if d_var is Dictionary:
					var dd: Dictionary = d_var as Dictionary
					var mark: String = "[★ ĐẠT]" if bool(dd.get("passed", false)) else "[☆ CHƯA ĐẠT]"
					detail_lines.append("%s Sao %d: %s" % [mark, int(dd.get("star", 1)), str(dd.get("description", ""))])
		_summary_stars_label.text = "\n".join(detail_lines)
	else:
		var reason_str: String = _diagnose_defeat_cause()
		_summary_title_label.text = "THẤT BẠI — %s" % reason_str
		_summary_stars_label.text = "Kết thúc tại Vòng %d/%d | Địch bị loại: %.1f%%" % [
			_controller.current_round,
			_controller.max_rounds,
			_controller.victory_evaluator.get_enemy_defeated_percent(_controller.context.map_state) if _controller.victory_evaluator != null else 0.0,
		]

	if _combat_log_label != null:
		_combat_log_label.text = "\n".join(_combat_log_entries)
	_summary_modal.visible = true
	apply_viewport_layout(_get_current_viewport_size())


func _diagnose_defeat_cause() -> String:
	if _controller == null or _controller.context == null or _controller.context.map_state == null:
		return "Thất bại chiến thuật"
	var ms: BattleMapState = _controller.context.map_state
	var ve: ScenarioVictoryEvaluator = _controller.victory_evaluator
	if ve != null:
		for d_cond: Dictionary in ve.defeat_conditions:
			var d_type: String = str(d_cond.get("type", ""))
			match d_type:
				"LoseKeyArea":
					if _controller.director != null:
						var area_id: String = str(d_cond.get("area_id", "signal_dock"))
						var owner_id: int = _controller.director.get_area_owner(area_id)
						if owner_id == 0 or ms.is_hostile(_controller.player_faction_id, owner_id):
							return "LoseKeyArea — Mất khu vực trọng yếu Bến Tín Hiệu (%s)" % area_id
				"GeneralDefeated":
					var gid: int = int(d_cond.get("target_general_id", 1001))
					var alive: bool = false
					for u: BattleUnit in ms.get_all_units():
						if u.general_id == gid and u.state.is_alive():
							alive = true
							break
					if not alive:
						return "GeneralDefeated — Chủ tướng Trần Quốc Tuấn (%d) bại trận" % gid
				"AllUnitsEliminated":
					var fac_id: int = int(d_cond.get("faction_id", _controller.player_faction_id))
					var has_any: bool = false
					for u: BattleUnit in ms.get_all_units():
						if u.faction_id == fac_id and u.state.is_alive():
							has_any = true
							break
					if not has_any:
						return "AllUnitsEliminated — Toàn quân Đại Việt đã bị tiêu diệt"
				"MaxRoundsUnfulfilled":
					var lim: int = int(d_cond.get("max_rounds", _controller.max_rounds))
					if _controller.current_round >= lim:
						return "MaxRoundsUnfulfilled — Hết giới hạn %d vòng chưa hoàn thành mục tiêu" % lim
	if _controller.current_round >= _controller.max_rounds:
		return "MaxRoundsUnfulfilled — Hết giới hạn %d vòng" % _controller.max_rounds
	return "AllUnitsEliminated — Toàn quân bại trận"


func open_pause_modal() -> void:
	if _pause_modal == null:
		return
	if (_briefing_modal != null and _briefing_modal.visible) or (_dialogue_modal != null and _dialogue_modal.visible) or (_summary_modal != null and _summary_modal.visible):
		return
	_pause_modal.visible = true
	apply_viewport_layout(_get_current_viewport_size())


func close_pause_modal() -> void:
	if _pause_modal != null:
		_pause_modal.visible = false
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = false
	if _codex_panel != null:
		_codex_panel.visible = false


func toggle_pause_modal() -> void:
	if _pause_modal == null:
		return
	if _pause_modal.visible:
		close_pause_modal()
	else:
		open_pause_modal()


func _sync_accessibility_widgets() -> void:
	if _shake_slider != null and _camera != null:
		var raw_v: float = _shake_slider.value
		if not is_equal_approx(raw_v, _last_synced_shake_val):
			_last_synced_shake_val = raw_v
			var norm_shake: float = clampf(raw_v / 100.0 if _shake_slider.max_value > 2.0 else raw_v, 0.0, 1.0)
			_camera.shake_user_scale = norm_shake
			_propagate_accessibility()

	if _reduce_flashing_check != null:
		var rf: bool = _reduce_flashing_check.button_pressed
		if rf != _last_synced_flash_val:
			_last_synced_flash_val = rf
			reduce_flashing = rf
			_propagate_accessibility()

	if _vfx_quality_option != null:
		var q_idx: int = _vfx_quality_option.selected
		if q_idx >= 0 and q_idx != _last_synced_vfx_idx:
			_last_synced_vfx_idx = q_idx
			vfx_quality_index = q_idx
			_propagate_accessibility()


func _propagate_accessibility() -> void:
	var shake_sc: float = _camera.shake_user_scale if _camera != null else 1.0
	if _sandbox != null and _sandbox.has_method("get_juice_helper"):
		var jh: Variant = _sandbox.call("get_juice_helper")
		if jh is Object:
			var jo: Object = jh as Object
			jo.set("reduce_flashing", reduce_flashing)
			if jo.has_method("set_vfx_quality"):
				jo.call("set_vfx_quality", vfx_quality_index)
	accessibility_changed.emit(reduce_flashing, vfx_quality_index, shake_sc)


func _on_event_dialogue_requested(dialogue_id: String) -> void:
	_enqueue_dialogue_by_id(dialogue_id, true)


func _on_event_camera_focus_requested(target_hex: Vector2i, _duration: float) -> void:
	if _camera != null and _map_view != null:
		var was_locked: bool = _camera.camera_locked
		_camera.camera_locked = false
		_camera.pan_to_world_pos(HexMath.axial_to_world(target_hex, _map_view.hex_size), true)
		_camera.camera_locked = was_locked


func _on_controller_round_started(round_num: int) -> void:
	append_combat_log("--- Bắt đầu Vòng %02d ---" % round_num)
	sync_with_controller(_controller)


func _on_controller_faction_turn_started(fac_id: int, round_num: int) -> void:
	var fac_str: String = "Đại Việt" if fac_id == 1 else "Đại Nguyên"
	append_combat_log("Vòng %02d: Lượt của phe %s" % [round_num, fac_str])
	sync_with_controller(_controller)
	update_dock_buttons()


func _populate_briefing(stage_meta: Dictionary) -> void:
	if _briefing_title_label == null:
		return
	var st_id: int = int(stage_meta.get("id", stage_meta.get("stage_id", 10101)))
	var st_name: String = str(stage_meta.get("name", "Đại Chiến Bạch Đằng 1288"))
	var mod_type: String = str(stage_meta.get("modeling_type", "historical_claim"))
	var src_ref: String = str(stage_meta.get("source_ref", "Đại Việt Sử Ký Toàn Thư (1288)"))
	_briefing_title_label.text = "📜 BRIEFING CHIẾN TRẬN: %s (ID: %d)" % [st_name, st_id]
	_briefing_meta_label.text = "Nhãn minh bạch Lịch sử: [%s] | Nguồn: %s" % [mod_type, src_ref]
	_briefing_body_label.text = (
		"• Mục tiêu Chiến thắng:\n"
		+ "  (1) Tiêu diệt Soái hạm Ô Mã Nhi (9001) khi giữ vững Bến Tín Hiệu (2,8); HOẶC\n"
		+ "  (2) Giữ vững Bến Tín Hiệu (2,8) & loại >= 75% quân Đại Nguyên khi hết Vòng 10.\n"
		+ "• Tiêu chuẩn 3 Sao: ★ Thắng trận | ★★ Hoàn thành <= 8 vòng | ★★★ Tổn thất HP <= 20%."
	)


# ---------------------------------------------------------------------------
# UI Builders
# ---------------------------------------------------------------------------

func _make_panel_style(bg: Color, border: Color, bw_top: int, bw_bottom: int, bw_sides: int = 0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.border_width_top = bw_top
	st.border_width_bottom = bw_bottom
	st.border_width_left = bw_sides
	st.border_width_right = bw_sides
	st.content_margin_left = 10.0
	st.content_margin_right = 10.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	return st


func _build_top_status_bar() -> void:
	_top_bar = Panel.new()
	_top_bar.name = "TopStatusBar"
	_top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_top_bar.clip_contents = true
	_top_bar.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.10, 0.09, 0.08, 0.92), Color(0.78, 0.62, 0.26, 0.92), 0, 2, 0)
	)
	_hud_layer.add_child(_top_bar)

	_top_bar_hbox = HBoxContainer.new()
	_top_bar_hbox.add_theme_constant_override("separation", 10)
	_top_bar.add_child(_top_bar_hbox)
	var hbox: HBoxContainer = _top_bar_hbox

	_pause_btn = Button.new()
	_pause_btn.name = "PauseButton"
	_pause_btn.text = "⏸ TẠM DỪNG"
	_pause_btn.add_theme_font_size_override("font_size", 12)
	# Idempotent open: closing is done via [TIẾP TỤC] / Esc, so rapid double-clicks never re-close the modal.
	_pause_btn.pressed.connect(open_pause_modal)
	hbox.add_child(_pause_btn)

	if ResourceLoader.exists("res://assets_clean/emblems/dai_viet_emblem.png"):
		var dv_icon := TextureRect.new()
		dv_icon.texture = load("res://assets_clean/emblems/dai_viet_emblem.png") as Texture2D
		dv_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dv_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dv_icon.custom_minimum_size = Vector2(24.0, 24.0)
		hbox.add_child(dv_icon)

	_mode_round_label = Label.new()
	_mode_round_label.name = "ModeRoundLabel"
	_mode_round_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	_mode_round_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(_mode_round_label)

	_mana_label = Label.new()
	_mana_label.name = "ManaLabel"
	_mana_label.text = "🔮 Mana: 0"
	_mana_label.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0))
	_mana_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(_mana_label)

	_economy_container = HBoxContainer.new()
	_economy_container.name = "EconomyContainer"
	_economy_container.add_theme_constant_override("separation", 8)
	_economy_container.visible = false
	hbox.add_child(_economy_container)

	_coin_label = Label.new()
	_coin_label.name = "CoinLabel"
	_coin_label.text = "🪙 Tiền: 0"
	_coin_label.visible = false
	_coin_label.add_theme_font_size_override("font_size", 12)
	_economy_container.add_child(_coin_label)

	_food_label = Label.new()
	_food_label.name = "FoodLabel"
	_food_label.text = "🌾 Lương: 0"
	_food_label.visible = false
	_food_label.add_theme_font_size_override("font_size", 12)
	_economy_container.add_child(_food_label)

	_tech_label = Label.new()
	_tech_label.name = "TechLabel"
	_tech_label.text = "⚙️ Kỹ nghệ: 0"
	_tech_label.visible = false
	_tech_label.add_theme_font_size_override("font_size", 12)
	_economy_container.add_child(_tech_label)

	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.text = _objective_text
	_objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_label.clip_text = true
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_objective_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80))
	_objective_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(_objective_label)

	_perf_label = Label.new()
	_perf_label.name = "PerfLabel"
	_perf_label.add_theme_color_override("font_color", Color(0.68, 0.94, 0.74))
	_perf_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(_perf_label)

	if ResourceLoader.exists("res://assets_clean/emblems/dai_nguyen_emblem.png"):
		var dn_icon := TextureRect.new()
		dn_icon.texture = load("res://assets_clean/emblems/dai_nguyen_emblem.png") as Texture2D
		dn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dn_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dn_icon.custom_minimum_size = Vector2(24.0, 24.0)
		hbox.add_child(dn_icon)


func _build_bottom_command_dock() -> void:
	_bottom_dock = Panel.new()
	_bottom_dock.name = "BottomCommandDock"
	_bottom_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_bottom_dock.clip_contents = true
	_bottom_dock.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.10, 0.09, 0.08, 0.92), Color(0.72, 0.56, 0.24, 0.90), 2, 0, 0)
	)
	_hud_layer.add_child(_bottom_dock)

	_bottom_dock_hbox = HBoxContainer.new()
	_bottom_dock_hbox.add_theme_constant_override("separation", 10)
	_bottom_dock.add_child(_bottom_dock_hbox)
	var hbox: HBoxContainer = _bottom_dock_hbox

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	_unit_card_label = Label.new()
	_unit_card_label.name = "UnitCardLabel"
	_unit_card_label.text = "Chưa chọn đạo quân"
	_unit_card_label.clip_text = true
	_unit_card_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_unit_card_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72))
	_unit_card_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(_unit_card_label)

	_banner_label = Label.new()
	_banner_label.name = "BottomInspectBar"
	_banner_label.text = "Click trái: Chọn/Đi/Ngắm đánh 2 bước | [Z] Hoàn tác | [W] Đợi | [K] Mưu lược | [Space] Kết thúc lượt | [R] Replay"
	_banner_label.clip_text = true
	_banner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_banner_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.80))
	_banner_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(_banner_label)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	hbox.add_child(btn_box)

	_move_btn = _make_dock_button("MoveButton", "ĐI", _on_move_btn_pressed)
	_attack_btn = _make_dock_button("AttackButton", "ĐÁNH", _on_attack_btn_pressed)
	_skill_btn = _make_dock_button("SkillButton", "MƯU LƯỢC", _on_skill_btn_pressed)
	_undo_btn = _make_dock_button("UndoButton", "HOÀN TÁC", _on_undo_btn_pressed)
	_wait_btn = _make_dock_button("WaitButton", "ĐỢI", _on_wait_btn_pressed)
	_end_turn_btn = _make_dock_button("EndTurnButton", "KẾT THÚC LƯỢT", _on_end_turn_btn_pressed)

	btn_box.add_child(_move_btn)
	btn_box.add_child(_attack_btn)
	btn_box.add_child(_skill_btn)
	btn_box.add_child(_undo_btn)
	btn_box.add_child(_wait_btn)
	btn_box.add_child(_end_turn_btn)


func _make_dock_button(btn_name: String, text_val: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = text_val
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(64.0, 32.0)
	btn.pressed.connect(cb)
	return btn


func _build_combat_preview_box() -> void:
	_preview_box = Panel.new()
	_preview_box.name = "CombatPreviewBox"
	_preview_box.visible = false
	_preview_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_box.clip_contents = true
	_preview_box.custom_minimum_size = PREVIEW_BOX_SIZE
	_preview_box.size = PREVIEW_BOX_SIZE
	_preview_box.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.11, 0.08, 0.08, 0.95), Color(0.94, 0.42, 0.28, 0.95), 2, 2, 2)
	)
	_hud_layer.add_child(_preview_box)

	_preview_vbox = VBoxContainer.new()
	_preview_vbox.position = Vector2(10.0, 6.0)
	_preview_vbox.size = PREVIEW_BOX_SIZE - Vector2(20.0, 12.0)
	_preview_vbox.add_theme_constant_override("separation", 4)
	_preview_box.add_child(_preview_vbox)
	var vbox: VBoxContainer = _preview_vbox

	_preview_title_label = Label.new()
	_preview_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_preview_title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_preview_title_label)

	_preview_hp_label = Label.new()
	_preview_hp_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.66))
	_preview_hp_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_preview_hp_label)

	_preview_stats_label = Label.new()
	_preview_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_stats_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	_preview_stats_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_preview_stats_label)

	_preview_mods_label = Label.new()
	_preview_mods_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_mods_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.76))
	_preview_mods_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_preview_mods_label)


func _build_briefing_modal() -> void:
	_briefing_modal = Panel.new()
	_briefing_modal.name = "BriefingModal"
	_briefing_modal.visible = false
	_briefing_modal.clip_contents = true
	_briefing_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing_modal.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.11, 0.10, 0.08, 0.96), Color(0.86, 0.68, 0.28, 0.96), 2, 2, 2)
	)
	_hud_layer.add_child(_briefing_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_briefing_modal.add_child(vbox)

	_briefing_title_label = Label.new()
	_briefing_title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	_briefing_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_briefing_title_label)

	_briefing_meta_label = Label.new()
	_briefing_meta_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.80))
	_briefing_meta_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_briefing_meta_label)

	_briefing_body_label = Label.new()
	_briefing_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_briefing_body_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	_briefing_body_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_briefing_body_label)

	_briefing_start_btn = Button.new()
	_briefing_start_btn.name = "StartButton"
	_briefing_start_btn.text = "BẮT ĐẦU TRẬN ĐÁNH"
	_briefing_start_btn.custom_minimum_size = Vector2(200.0, 36.0)
	_briefing_start_btn.pressed.connect(dismiss_briefing)
	vbox.add_child(_briefing_start_btn)


func _build_dialogue_modal() -> void:
	_dialogue_modal = Panel.new()
	_dialogue_modal.name = "DialogueModal"
	_dialogue_modal.visible = false
	_dialogue_modal.clip_contents = true
	_dialogue_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_modal.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.09, 0.09, 0.12, 0.95), Color(0.84, 0.68, 0.30, 0.95), 2, 2, 2)
	)
	_hud_layer.add_child(_dialogue_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_dialogue_modal.add_child(vbox)

	_dialogue_speaker_label = Label.new()
	_dialogue_speaker_label.name = "SpeakerLabel"
	_dialogue_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_dialogue_speaker_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_dialogue_speaker_label)

	_dialogue_line_label = Label.new()
	_dialogue_line_label.name = "DialogueLineLabel"
	_dialogue_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_line_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	_dialogue_line_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_dialogue_line_label)

	_dialogue_continue_btn = Button.new()
	_dialogue_continue_btn.name = "ContinueButton"
	_dialogue_continue_btn.text = "TIẾP TỤC ▶"
	_dialogue_continue_btn.custom_minimum_size = Vector2(140.0, 30.0)
	_dialogue_continue_btn.pressed.connect(advance_dialogue)
	vbox.add_child(_dialogue_continue_btn)


func _build_result_summary_modal() -> void:
	_summary_modal = Panel.new()
	_summary_modal.name = "ResultSummaryModal"
	_summary_modal.visible = false
	_summary_modal.clip_contents = true
	_summary_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_summary_modal.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.10, 0.09, 0.08, 0.97), Color(0.92, 0.74, 0.28, 0.98), 2, 2, 2)
	)
	_hud_layer.add_child(_summary_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_summary_modal.add_child(vbox)

	_summary_title_label = Label.new()
	_summary_title_label.name = "SummaryTitleLabel"
	_summary_title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	_summary_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_summary_title_label)

	_summary_stars_label = Label.new()
	_summary_stars_label.name = "SummaryStarsLabel"
	_summary_stars_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_stars_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
	_summary_stars_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_summary_stars_label)

	_combat_log_panel = PanelContainer.new()
	_combat_log_panel.name = "CombatLogPanel"
	_combat_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_log_panel.custom_minimum_size = Vector2(0.0, 140.0)
	_combat_log_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.06, 0.06, 0.07, 0.92), Color(0.45, 0.38, 0.22, 0.80), 1, 1, 1)
	)
	vbox.add_child(_combat_log_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_log_panel.add_child(scroll)

	_combat_log_label = Label.new()
	_combat_log_label.name = "CombatLog"
	_combat_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_log_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.84))
	_combat_log_label.add_theme_font_size_override("font_size", 11)
	scroll.add_child(_combat_log_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_retry_btn = Button.new()
	_retry_btn.name = "RetryButton"
	_retry_btn.text = "CHƠI LẠI (RETRY)"
	_retry_btn.custom_minimum_size = Vector2(150.0, 34.0)
	_retry_btn.pressed.connect(_on_retry_btn_pressed)
	btn_row.add_child(_retry_btn)

	_replay_btn = Button.new()
	_replay_btn.name = "ReplayButton"
	_replay_btn.text = "KIỂM CHỨNG REPLAY"
	_replay_btn.custom_minimum_size = Vector2(160.0, 34.0)
	_replay_btn.pressed.connect(_on_replay_btn_pressed)
	btn_row.add_child(_replay_btn)

	_next_stage_btn = Button.new()
	_next_stage_btn.name = "NextStageButton"
	_next_stage_btn.text = "MÀN TIẾP (NEXT)"
	_next_stage_btn.custom_minimum_size = Vector2(150.0, 34.0)
	_next_stage_btn.pressed.connect(func() -> void: next_stage_requested.emit())
	btn_row.add_child(_next_stage_btn)


func _build_pause_settings_modal() -> void:
	_pause_modal = Panel.new()
	_pause_modal.name = "PauseSettingsModal"
	_pause_modal.visible = false
	_pause_modal.clip_contents = true
	_pause_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_modal.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.10, 0.10, 0.12, 0.97), Color(0.82, 0.66, 0.28, 0.95), 2, 2, 2)
	)
	_hud_layer.add_child(_pause_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_pause_modal.add_child(vbox)

	var title := Label.new()
	title.text = "⚙ TẠM DỪNG & TRỢ NĂNG (PAUSE & ACCESSIBILITY)"
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var shake_row := HBoxContainer.new()
	vbox.add_child(shake_row)
	var shake_lbl := Label.new()
	shake_lbl.text = "Cường độ Rung màn hình (0-100%):"
	shake_lbl.custom_minimum_size = Vector2(220.0, 0.0)
	shake_row.add_child(shake_lbl)
	_shake_slider = HSlider.new()
	_shake_slider.name = "ShakeScaleSlider"
	_shake_slider.min_value = 0.0
	_shake_slider.max_value = 100.0
	_shake_slider.step = 1.0
	_shake_slider.value = 100.0
	_shake_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shake_slider.value_changed.connect(func(_v: float) -> void: _sync_accessibility_widgets())
	shake_row.add_child(_shake_slider)

	_reduce_flashing_check = CheckBox.new()
	_reduce_flashing_check.name = "ReduceFlashingCheck"
	_reduce_flashing_check.text = "Giảm chớp sáng (Reduce Flashing — WCAG 2.3.1)"
	_reduce_flashing_check.toggled.connect(func(_p: bool) -> void: _sync_accessibility_widgets())
	vbox.add_child(_reduce_flashing_check)

	var vfx_row := HBoxContainer.new()
	vbox.add_child(vfx_row)
	var vfx_lbl := Label.new()
	vfx_lbl.text = "Chất lượng Hiệu ứng (VFX Quality):"
	vfx_lbl.custom_minimum_size = Vector2(220.0, 0.0)
	vfx_row.add_child(vfx_lbl)
	_vfx_quality_option = OptionButton.new()
	_vfx_quality_option.name = "VfxQualityOption"
	_vfx_quality_option.add_item("Low (Thấp - 40%)", 0)
	_vfx_quality_option.add_item("Medium (Vừa - 75%)", 1)
	_vfx_quality_option.add_item("High (Cao - 100%)", 2)
	_vfx_quality_option.select(2)
	_vfx_quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vfx_quality_option.item_selected.connect(func(_idx: int) -> void: _sync_accessibility_widgets())
	vfx_row.add_child(_vfx_quality_option)

	_master_vol_slider = _add_audio_slider_row(vbox, "MasterVolumeSlider", "Âm lượng Tổng (Master):", "Master", 85.0)
	_bgm_vol_slider = _add_audio_slider_row(vbox, "BgmVolumeSlider", "Âm lượng Nhạc nền (BGM):", "BGM", 80.0)
	_sfx_vol_slider = _add_audio_slider_row(vbox, "SfxVolumeSlider", "Âm lượng Hiệu ứng (SFX):", "SFX", 85.0)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_resume_btn = Button.new()
	_resume_btn.name = "ResumeButton"
	_resume_btn.text = "TIẾP TỤC (RESUME)"
	_resume_btn.custom_minimum_size = Vector2(140.0, 32.0)
	_resume_btn.pressed.connect(close_pause_modal)
	btn_row.add_child(_resume_btn)

	_restart_btn = Button.new()
	_restart_btn.name = "RestartButton"
	_restart_btn.text = "CHƠI LẠI (RESTART)"
	_restart_btn.custom_minimum_size = Vector2(140.0, 32.0)
	_restart_btn.pressed.connect(_on_restart_from_pause_pressed)
	btn_row.add_child(_restart_btn)

	_save_exit_btn = Button.new()
	_save_exit_btn.name = "SaveAndExitButton"
	_save_exit_btn.text = "LƯU & THOÁT (SAVE & EXIT)"
	_save_exit_btn.custom_minimum_size = Vector2(160.0, 32.0)
	_save_exit_btn.pressed.connect(_on_save_and_exit_pressed)
	btn_row.add_child(_save_exit_btn)


func _add_audio_slider_row(parent: VBoxContainer, s_name: String, label_txt: String, bus_name: String, default_v: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(220.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.name = s_name
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		if _sandbox != null and _sandbox.has_method("get_audio_manager"):
			var am: Variant = _sandbox.call("get_audio_manager")
			if am is Object and (am as Object).has_method("set_bus_linear_volume"):
				(am as Object).call("set_bus_linear_volume", bus_name, clampf(v / 100.0, 0.0, 1.0))
	)
	row.add_child(slider)
	return slider


# ---------------------------------------------------------------------------
# Button Callbacks
# ---------------------------------------------------------------------------

func _on_move_btn_pressed() -> void:
	if _input_fsm == null:
		return
	var u: BattleUnit = _input_fsm.get_active_unit()
	if u != null:
		set_bottom_banner("Chọn ô xanh dương trên bản đồ để hành quân [%s]." % u.display_name)


func _on_attack_btn_pressed() -> void:
	if _input_fsm == null or _controller == null:
		return
	if _input_fsm.get_state() == BattleInputFSM.State.AIMING_TARGET:
		_input_fsm.confirm_attack()
		return
	var u: BattleUnit = _input_fsm.get_active_unit()
	if u == null or _controller.context == null:
		return
	var ms: BattleMapState = _controller.context.map_state
	var nav: HexGridNavigator = _controller.context.navigator
	for ah: Vector2i in nav.get_attackable_hexes(ms, u, u.hex_position):
		var occ: BattleUnit = ms.get_unit_at(ah)
		if occ != null and ms.is_hostile(u.faction_id, occ.faction_id):
			_input_fsm.tap_hex(ah)
			return


func _on_skill_btn_pressed() -> void:
	if _sandbox != null and _sandbox.has_method("try_enter_skill_targeting"):
		_sandbox.call("try_enter_skill_targeting")


func _on_undo_btn_pressed() -> void:
	if _sandbox != null and _sandbox.has_method("try_undo_march"):
		_sandbox.call("try_undo_march")


func _on_wait_btn_pressed() -> void:
	if _sandbox != null and _sandbox.has_method("try_wait_selected"):
		_sandbox.call("try_wait_selected")


func _on_end_turn_btn_pressed() -> void:
	if _sandbox != null and _sandbox.has_method("end_active_faction_turn"):
		_sandbox.call("end_active_faction_turn")


func _on_retry_btn_pressed() -> void:
	_summary_modal.visible = false
	retry_requested.emit()
	if _sandbox != null and _sandbox.has_method("load_bach_dang_preview_12x10"):
		_sandbox.call("load_bach_dang_preview_12x10")
		dismiss_all_modals()


func _on_replay_btn_pressed() -> void:
	replay_requested.emit()
	if _sandbox != null and _sandbox.has_method("verify_deterministic_replay_live"):
		_sandbox.call("verify_deterministic_replay_live")


func _on_restart_from_pause_pressed() -> void:
	close_pause_modal()
	retry_requested.emit()
	if _sandbox != null and _sandbox.has_method("load_bach_dang_preview_12x10"):
		_sandbox.call("load_bach_dang_preview_12x10")
		dismiss_all_modals()


func _on_save_and_exit_pressed() -> void:
	if _sandbox != null and _sandbox.has_method("save_session_and_profile"):
		_sandbox.call("save_session_and_profile")
	close_pause_modal()
	save_and_exit_requested.emit()
