class_name BattleHud
extends Control

## Root Map-First HUD & modal coordinator instantiated from res://ui/battle_hud/battle_hud.tscn.
## Reads battle state via BattleSession/controller signals and dispatches commands cleanly.

signal briefing_dismissed()
signal dialogue_finished()
signal retry_requested()
signal replay_requested()
signal next_stage_requested()
signal save_and_exit_requested()
signal accessibility_changed(reduce_flashing: bool, vfx_quality: int, shake_scale: float)

@export var session: BattleSession = null

var reduce_flashing: bool = false
var vfx_quality_index: int = 2

var _sandbox: Node = null
var _controller: BattleGameController = null
var _map_view: BattleMapView = null
var _camera: BattleCameraController = null
var _input_fsm: BattleInputFSM = null
var _combat_log_entries: PackedStringArray = PackedStringArray()
var _mode_title: String = "ĐẠI VIỆT CHIẾN KỲ"
var _opened_opening_dialogue: bool = false
var _last_unit_count_sync: int = -1

@onready var _top_bar: BattleTopBar = $TopStatusBar
@onready var _unit_inspector: UnitInspector = $UnitInspector
@onready var _command_dock: CommandDock = $BottomCommandDock
@onready var _briefing_modal: BriefingModal = $BriefingModal
@onready var _dialogue_modal: DialogueModal = $DialogueModal
@onready var _pause_modal: PauseModal = $PauseSettingsModal
@onready var _summary_modal: ResultSummaryModal = $ResultSummaryModal

var _tutorial_overlay: TutorialOverlay = null
var _codex_panel: CodexPanel = null


func _ready() -> void:
	_connect_child_signals()
	if get_viewport() != null:
		get_viewport().size_changed.connect(func() -> void: _fit_all_modals(_get_current_viewport_size()))
	_fit_all_modals(_get_current_viewport_size())


func setup(sandbox: Node, p_session: Variant, map_view: BattleMapView, camera: BattleCameraController, input_fsm: BattleInputFSM) -> void:
	_sandbox = sandbox
	if p_session is BattleSession:
		session = p_session as BattleSession
	_map_view = map_view
	_camera = camera
	_input_fsm = input_fsm
	if _input_fsm != null:
		if not _input_fsm.unit_focused.is_connected(_on_fsm_unit_focused):
			_input_fsm.unit_focused.connect(_on_fsm_unit_focused)
		if not _input_fsm.hex_inspected.is_connected(update_unit_card):
			_input_fsm.hex_inspected.connect(update_unit_card)
		if not _input_fsm.state_changed.is_connected(_on_fsm_state_changed):
			_input_fsm.state_changed.connect(_on_fsm_state_changed)
	if _tutorial_overlay == null:
		_tutorial_overlay = TutorialOverlay.new()
		_tutorial_overlay.visible = false
		add_child(_tutorial_overlay)
	if _codex_panel == null:
		_codex_panel = CodexPanel.new()
		_codex_panel.visible = false
		add_child(_codex_panel)


func bind_battle(controller: BattleGameController, stage_meta: Dictionary, dialogues_dict: Dictionary = {}, show_briefing: bool = true) -> void:
	_controller = controller
	if _dialogue_modal != null:
		_dialogue_modal.set_dialogues(dialogues_dict)
	_combat_log_entries.clear()
	_opened_opening_dialogue = false
	_last_unit_count_sync = -1
	if _unit_inspector != null:
		_unit_inspector.clear()

	if _controller != null:
		if not _controller.round_started.is_connected(_on_controller_round_started):
			_controller.round_started.connect(_on_controller_round_started)
		if not _controller.faction_turn_started.is_connected(_on_controller_faction_turn_started):
			_controller.faction_turn_started.connect(_on_controller_faction_turn_started)
		if _controller.event_manager != null:
			if not _controller.event_manager.dialogue_requested.is_connected(queue_dialogue_id):
				_controller.event_manager.dialogue_requested.connect(queue_dialogue_id)
			if not _controller.event_manager.camera_focus_requested.is_connected(_on_event_camera_focus_requested):
				_controller.event_manager.camera_focus_requested.connect(_on_event_camera_focus_requested)

	sync_with_controller(_controller)
	update_dock_buttons()
	if show_briefing and _briefing_modal != null:
		dismiss_all_modals()
		_briefing_modal.open_briefing(stage_meta)
	else:
		dismiss_all_modals()


func _process(_delta: float) -> void:
	if _controller != null and _controller.context != null and _controller.context.map_state != null:
		var u_cnt: int = _controller.context.map_state.get_all_units().size()
		if u_cnt != _last_unit_count_sync:
			_last_unit_count_sync = u_cnt
			sync_with_controller(_controller)


func apply_viewport_layout(vp_size: Vector2) -> void:
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var actual_vp: Vector2 = _get_current_viewport_size()
	if is_equal_approx(vp_size.x, actual_vp.x) and is_equal_approx(vp_size.y, actual_vp.y):
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		size = vp_size
	_fit_all_modals(vp_size)


func set_mode_title(title: String) -> void:
	_mode_title = title
	sync_with_controller(_controller)


func set_objective_text(text_val: String) -> void:
	if _top_bar != null:
		_top_bar.set_objective_text(text_val)


func set_bottom_banner(msg: String) -> void:
	if _command_dock != null:
		_command_dock.set_banner(msg)


func get_bottom_banner() -> String:
	return _command_dock.get_banner() if _command_dock != null else ""


func get_top_bar() -> PanelContainer: return _top_bar
func get_bottom_dock() -> PanelContainer: return _command_dock
func get_unit_inspector() -> UnitInspector: return _unit_inspector
func get_selection_label() -> Label: return _command_dock.get_selection_label() if _command_dock != null else null
func get_mode_label() -> Label: return _top_bar.get_mode_label() if _top_bar != null else null
func get_perf_label() -> Label: return _top_bar.get_perf_label() if _top_bar != null else null
func get_tutorial_overlay() -> TutorialOverlay: return _tutorial_overlay
func get_codex_panel() -> CodexPanel: return _codex_panel


func is_any_modal_open() -> bool:
	for m: Control in _get_modal_controls():
		if m != null and m.visible:
			return true
	return false


func dismiss_briefing() -> void:
	if _briefing_modal == null or not _briefing_modal.visible:
		return
	_briefing_modal.visible = false
	briefing_dismissed.emit()
	if not _opened_opening_dialogue and _dialogue_modal != null and _dialogue_modal.has_dialogue("talk_opening_bach_dang"):
		_opened_opening_dialogue = true
		queue_dialogue_id("talk_opening_bach_dang")


func skip_intro() -> void:
	if _briefing_modal != null:
		_briefing_modal.visible = false
	_opened_opening_dialogue = true
	briefing_dismissed.emit()
	skip_dialogue_queue()


func dismiss_all_modals() -> void:
	if _briefing_modal != null:
		_briefing_modal.visible = false
	if _dialogue_modal != null:
		_dialogue_modal.close_dialogue()
	if _pause_modal != null:
		_pause_modal.close_modal()
	if _summary_modal != null:
		_summary_modal.visible = false
	if _camera != null:
		_camera.camera_locked = false


func sync_with_controller(ctrl: BattleGameController = null) -> void:
	if ctrl != null:
		_controller = ctrl
	if _top_bar != null:
		_top_bar.sync_from_controller(_controller, _mode_title)


func update_unit_card(axial: Vector2i, unit: BattleUnit) -> void:
	var ms: BattleMapState = _controller.context.map_state if _controller != null and _controller.context != null else null
	var pf: int = _controller.player_faction_id if _controller != null else 1
	if _unit_inspector != null:
		_unit_inspector.show_unit(unit, axial, ms, pf)
	if _command_dock != null:
		_command_dock.show_unit_summary(unit, pf)


func update_dock_buttons() -> void:
	if _command_dock != null:
		_command_dock.update_button_states(_controller, _input_fsm)


func queue_dialogue_id(dialogue_id: String) -> void:
	if _dialogue_modal != null:
		_dialogue_modal.queue_dialogue_id(dialogue_id, _camera)


func show_dialogue_entries(entries: Array) -> void:
	if _dialogue_modal != null:
		_dialogue_modal.show_dialogue_entries(entries, _camera)


func advance_dialogue() -> void:
	if _dialogue_modal != null:
		_dialogue_modal.advance_dialogue(_camera)


func skip_dialogue_queue() -> void:
	if _dialogue_modal != null:
		_dialogue_modal.skip_dialogue_queue(_camera)


func append_combat_log(entry: String) -> void:
	if not entry.is_empty():
		_combat_log_entries.append(entry)


func show_result_summary(outcome_code: int) -> void:
	if _dialogue_modal != null:
		_dialogue_modal.close_dialogue()
	if _camera != null:
		_camera.camera_locked = false
	if _summary_modal != null:
		_summary_modal.show_result(_controller, outcome_code, _combat_log_entries)


func open_pause_modal() -> void:
	if _pause_modal == null:
		return
	if (_briefing_modal != null and _briefing_modal.visible) or (_dialogue_modal != null and _dialogue_modal.visible) or (_summary_modal != null and _summary_modal.visible):
		return
	_pause_modal.open_modal(_camera.shake_user_scale if _camera != null else 1.0, reduce_flashing, vfx_quality_index)


func close_pause_modal() -> void:
	if _pause_modal != null:
		_pause_modal.close_modal()
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = false
	if _codex_panel != null:
		_codex_panel.visible = false


func toggle_pause_modal() -> void:
	if _pause_modal != null and _pause_modal.visible:
		close_pause_modal()
	else:
		open_pause_modal()


func _get_modal_controls() -> Array[Control]:
	return [_briefing_modal, _dialogue_modal, _pause_modal, _summary_modal]


func _fit_all_modals(vp_size: Vector2) -> void:
	for m: Control in _get_modal_controls():
		if m != null and m.has_method("fit_to_viewport"):
			m.call("fit_to_viewport", vp_size)


func _connect_child_signals() -> void:
	if _top_bar != null:
		_top_bar.pause_requested.connect(open_pause_modal)
	if _command_dock != null:
		_command_dock.move_pressed.connect(func() -> void: _command_dock.show_move_hint(_input_fsm))
		_command_dock.attack_pressed.connect(func() -> void: _command_dock.execute_attack_in_range(_controller, _input_fsm))
		_command_dock.skill_pressed.connect(func() -> void: HudSandboxBridge.trigger_method(_sandbox, "try_enter_skill_targeting"))
		_command_dock.undo_pressed.connect(func() -> void: HudSandboxBridge.trigger_method(_sandbox, "try_undo_march"))
		_command_dock.wait_pressed.connect(func() -> void: HudSandboxBridge.trigger_method(_sandbox, "try_wait_selected"))
		_command_dock.end_turn_pressed.connect(func() -> void: HudSandboxBridge.trigger_method(_sandbox, "end_active_faction_turn"))
	if _briefing_modal != null:
		_briefing_modal.start_pressed.connect(dismiss_briefing)
		_briefing_modal.skip_pressed.connect(skip_intro)
	if _dialogue_modal != null:
		_dialogue_modal.continue_pressed.connect(advance_dialogue)
		_dialogue_modal.skip_all_pressed.connect(skip_dialogue_queue)
		_dialogue_modal.dialogue_finished.connect(func() -> void: dialogue_finished.emit())
	if _pause_modal != null:
		_pause_modal.resume_requested.connect(close_pause_modal)
		_pause_modal.restart_requested.connect(_on_restart_requested)
		_pause_modal.save_and_exit_requested.connect(_on_save_and_exit_requested)
		_pause_modal.accessibility_changed.connect(_on_accessibility_changed)
		_pause_modal.bus_volume_changed.connect(func(bus: String, val: float) -> void: HudSandboxBridge.apply_bus_volume(_sandbox, bus, val))
	if _summary_modal != null:
		_summary_modal.retry_requested.connect(_on_restart_requested)
		_summary_modal.replay_requested.connect(_on_replay_requested)


func _get_current_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280.0, 720.0)


func _on_fsm_unit_focused(unit: BattleUnit) -> void:
	update_unit_card(unit.hex_position if unit != null else Vector2i.ZERO, unit)


func _on_fsm_state_changed(_old_state: int, _new_state: int) -> void:
	update_dock_buttons()


func _on_restart_requested() -> void:
	dismiss_all_modals()
	retry_requested.emit()
	HudSandboxBridge.trigger_method(_sandbox, "load_bach_dang_preview_12x10")


func _on_replay_requested() -> void:
	if _summary_modal != null:
		_summary_modal.visible = false
	replay_requested.emit()
	HudSandboxBridge.trigger_method(_sandbox, "verify_deterministic_replay_live")


func _on_save_and_exit_requested() -> void:
	HudSandboxBridge.trigger_method(_sandbox, "save_session_and_profile")
	save_and_exit_requested.emit()
	close_pause_modal()


func _on_accessibility_changed(rf: bool, vfx_q: int, shake_s: float) -> void:
	reduce_flashing = rf
	vfx_quality_index = vfx_q
	HudSandboxBridge.apply_accessibility(_sandbox, _camera, reduce_flashing, vfx_quality_index, shake_s)
	accessibility_changed.emit(reduce_flashing, vfx_quality_index, shake_s)


func _on_event_camera_focus_requested(target_hex: Vector2i, _duration: float) -> void:
	HudSandboxBridge.focus_camera_on_hex(_camera, _map_view, target_hex)


func _on_controller_round_started(round_num: int) -> void:
	append_combat_log("--- Bắt đầu Vòng %02d ---" % round_num)
	sync_with_controller(_controller)


func _on_controller_faction_turn_started(fac_id: int, round_num: int) -> void:
	var fac_str: String = "Đại Việt" if fac_id == 1 else "Đại Nguyên"
	append_combat_log("Vòng %02d: Lượt của phe %s" % [round_num, fac_str])
	sync_with_controller(_controller)
	update_dock_buttons()
