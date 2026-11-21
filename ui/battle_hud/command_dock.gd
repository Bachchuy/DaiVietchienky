class_name CommandDock
extends PanelContainer

signal move_pressed()
signal attack_pressed()
signal skill_pressed()
signal undo_pressed()
signal wait_pressed()
signal end_turn_pressed()

const MORALE_TEXT: Dictionary[int, String] = {
	0: "Hỗn Loạn",
	1: "Dao Động",
	2: "Ổn Định",
	3: "Hưng Phấn",
}

@onready var _unit_summary_label: Label = $Row/InfoVBox/UnitSummaryLabel
@onready var _banner_label: Label = $Row/InfoVBox/BannerLabel
@onready var _move_btn: Button = $Row/ButtonsRow/MoveButton
@onready var _attack_btn: Button = $Row/ButtonsRow/AttackButton
@onready var _skill_btn: Button = $Row/ButtonsRow/SkillButton
@onready var _undo_btn: Button = $Row/ButtonsRow/UndoButton
@onready var _wait_btn: Button = $Row/ButtonsRow/WaitButton
@onready var _end_turn_btn: Button = $Row/ButtonsRow/EndTurnButton


func _ready() -> void:
	if _move_btn != null:
		_move_btn.pressed.connect(func() -> void: move_pressed.emit())
	if _attack_btn != null:
		_attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	if _skill_btn != null:
		_skill_btn.pressed.connect(func() -> void: skill_pressed.emit())
	if _undo_btn != null:
		_undo_btn.pressed.connect(func() -> void: undo_pressed.emit())
	if _wait_btn != null:
		_wait_btn.pressed.connect(func() -> void: wait_pressed.emit())
	if _end_turn_btn != null:
		_end_turn_btn.pressed.connect(func() -> void: end_turn_pressed.emit())


func show_unit_summary(unit: BattleUnit, player_faction_id: int) -> void:
	if unit == null:
		update_unit_summary("Chưa chọn đạo quân")
		return
	var fac: String = "Đại Việt" if unit.faction_id == player_faction_id else "Đại Nguyên"
	var mor: String = MORALE_TEXT.get(int(unit.state.morale), "Ổn Định")
	var name_part: String = unit.display_name
	if not unit.general_name.is_empty() and not name_part.contains(unit.general_name):
		name_part = "%s — %s" % [unit.general_name, name_part]
	update_unit_summary("[%s] %s | HP: %d/%d (%d cờ) | Sĩ khí: %s | MP: %d/%d" % [
		fac, name_part, unit.state.current_hp, unit.state.max_hp, unit.get_active_banners(), mor, unit.state.current_mp, unit.max_mp
	])


func update_unit_summary(text_val: String) -> void:
	if _unit_summary_label != null:
		_unit_summary_label.text = text_val


func show_move_hint(fsm: BattleInputFSM) -> void:
	var u: BattleUnit = fsm.get_active_unit() if fsm != null else null
	if u != null:
		set_banner("Chọn ô xanh dương trên bản đồ để hành quân [%s]." % u.display_name)


func execute_attack_in_range(ctrl: BattleGameController, fsm: BattleInputFSM) -> void:
	if fsm == null or ctrl == null or ctrl.context == null or ctrl.context.map_state == null:
		return
	var u: BattleUnit = fsm.get_active_unit()
	if u == null:
		return
	var ms: BattleMapState = ctrl.context.map_state
	for ah: Vector2i in ctrl.context.navigator.get_attackable_hexes(ms, u, u.hex_position):
		var occ: BattleUnit = ms.get_unit_at(ah)
		if occ != null and ms.is_hostile(u.faction_id, occ.faction_id):
			fsm.tap_hex(ah)
			return


func set_banner(msg: String) -> void:
	if _banner_label != null:
		_banner_label.text = msg


func get_banner() -> String:
	return _banner_label.text if _banner_label != null else ""


func get_selection_label() -> Label:
	return _unit_summary_label


func update_button_states(ctrl: BattleGameController, fsm: BattleInputFSM) -> void:
	if ctrl == null or fsm == null:
		return
	var is_player_turn: bool = (
		ctrl.outcome == BattleGameController.BattleOutcome.ONGOING
		and ctrl.current_faction_id == ctrl.player_faction_id
	)
	var st: BattleInputFSM.State = fsm.get_state()
	var active_u: BattleUnit = fsm.get_active_unit()
	var can_act: bool = (
		is_player_turn
		and active_u != null
		and active_u.state.is_alive()
		and not active_u.state.has_acted
	)

	var has_target_in_range: bool = false
	if can_act and ctrl.context != null and ctrl.context.map_state != null:
		var ms: BattleMapState = ctrl.context.map_state
		for ah: Vector2i in ctrl.context.navigator.get_attackable_hexes(ms, active_u, active_u.hex_position):
			var occ: BattleUnit = ms.get_unit_at(ah)
			if occ != null and ms.is_hostile(active_u.faction_id, occ.faction_id):
				has_target_in_range = true
				break

	if _move_btn != null:
		_move_btn.disabled = not (can_act and st == BattleInputFSM.State.UNIT_SELECTED and active_u.state.can_move())
	if _attack_btn != null:
		_attack_btn.disabled = not (
			can_act
			and (st == BattleInputFSM.State.UNIT_SELECTED or st == BattleInputFSM.State.POST_MOVE_ACTION)
			and has_target_in_range
		)
	if _skill_btn != null:
		_skill_btn.disabled = not (
			can_act
			and fsm.can_active_unit_use_skill()
			and (st == BattleInputFSM.State.UNIT_SELECTED or st == BattleInputFSM.State.POST_MOVE_ACTION or st == BattleInputFSM.State.SKILL_TARGETING)
		)
	if _undo_btn != null:
		_undo_btn.disabled = not (is_player_turn and fsm.can_undo_post_move())
	if _wait_btn != null:
		_wait_btn.disabled = not (can_act and (st == BattleInputFSM.State.UNIT_SELECTED or st == BattleInputFSM.State.POST_MOVE_ACTION))
	if _end_turn_btn != null:
		_end_turn_btn.disabled = not is_player_turn
