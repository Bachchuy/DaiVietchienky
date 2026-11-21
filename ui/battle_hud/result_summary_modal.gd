class_name ResultSummaryModal
extends Control

signal retry_requested()
signal replay_requested()
signal close_requested()

@onready var _frame: ModalFrame = $ModalFrame
@onready var _stats_label: Label = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/SummaryStatsLabel
@onready var _log_label: Label = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/CombatLogPanel/LogMargin/CombatLogLabel
@onready var _replay_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/ReplayButton
@onready var _retry_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/RetryButton
@onready var _close_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/CloseResultButton


func _ready() -> void:
	if _replay_btn != null:
		_replay_btn.pressed.connect(func() -> void: replay_requested.emit())
	if _retry_btn != null:
		_retry_btn.pressed.connect(func() -> void: retry_requested.emit())
	if _close_btn != null:
		_close_btn.pressed.connect(func() -> void:
			visible = false
			close_requested.emit()
		)
	if _frame != null:
		_frame.accept_requested.connect(func() -> void:
			visible = false
			close_requested.emit()
		)
		_frame.cancel_requested.connect(func() -> void:
			visible = false
			close_requested.emit()
		)


func show_result(ctrl: BattleGameController, outcome_code: int, combat_log_entries: PackedStringArray) -> void:
	if ctrl == null:
		return
	if outcome_code == int(BattleGameController.BattleOutcome.VICTORY):
		var star_res: Dictionary = (
			ctrl.victory_evaluator.evaluate_stars(ctrl)
			if ctrl.victory_evaluator != null
			else {"stars": 1, "rounds_used": ctrl.current_round, "player_hp_loss_percent": 0.0, "enemy_defeated_percent": 100.0, "details": []}
		)
		var stars: int = int(star_res.get("stars", 1))
		if _frame != null:
			_frame.set_header("CHIẾN THẮNG ĐẠI VIỆT — %d/3 SAO (%d ★)" % [stars, stars], "Tổng kết chiến dịch")
		var lines: PackedStringArray = PackedStringArray()
		lines.append("Hoàn tất tại Vòng %d/%d | Tổn thất HP: %.1f%% | Địch bị loại: %.1f%%" % [
			ctrl.current_round,
			ctrl.max_rounds,
			float(star_res.get("player_hp_loss_percent", 0.0)),
			float(star_res.get("enemy_defeated_percent", 0.0)),
		])
		var raw_details: Variant = star_res.get("details", [])
		if raw_details is Array:
			for d_var: Variant in raw_details as Array:
				if d_var is Dictionary:
					var dd: Dictionary = d_var as Dictionary
					var mark: String = "[★ ĐẠT]" if bool(dd.get("passed", false)) else "[☆ CHƯA ĐẠT]"
					lines.append("%s Sao %d: %s" % [mark, int(dd.get("star", 1)), str(dd.get("description", ""))])
		if _stats_label != null:
			_stats_label.text = "\n".join(lines)
	else:
		var reason_str: String = _diagnose_defeat_cause(ctrl)
		if _frame != null:
			_frame.set_header("THẤT BẠI — %s" % reason_str, "Báo cáo nguyên nhân thất bại")
		var def_pct: float = ctrl.victory_evaluator.get_enemy_defeated_percent(ctrl.context.map_state) if ctrl.victory_evaluator != null else 0.0
		if _stats_label != null:
			_stats_label.text = "Kết thúc tại Vòng %d/%d | Địch bị loại: %.1f%%" % [ctrl.current_round, ctrl.max_rounds, def_pct]

	if _log_label != null:
		_log_label.text = "\n".join(combat_log_entries) if not combat_log_entries.is_empty() else "Chưa ghi nhận giao tranh."
	visible = true
	if _frame != null:
		_frame.fit_to_viewport()
		_frame.focus_button(_close_btn)


func fit_to_viewport(vp_size: Vector2 = Vector2.ZERO) -> void:
	if _frame != null:
		_frame.fit_to_viewport(vp_size)


func _diagnose_defeat_cause(ctrl: BattleGameController) -> String:
	if ctrl.context == null or ctrl.context.map_state == null:
		return "Thất bại chiến thuật"
	var ms: BattleMapState = ctrl.context.map_state
	var ve: ScenarioVictoryEvaluator = ctrl.victory_evaluator
	if ve != null:
		for d_cond: Dictionary in ve.defeat_conditions:
			var d_type: String = str(d_cond.get("type", ""))
			match d_type:
				"LoseKeyArea":
					if ctrl.director != null:
						var area_id: String = str(d_cond.get("area_id", "signal_dock"))
						var owner_id: int = ctrl.director.get_area_owner(area_id)
						if owner_id == 0 or ms.is_hostile(ctrl.player_faction_id, owner_id):
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
					var fac_id: int = int(d_cond.get("faction_id", ctrl.player_faction_id))
					var has_any: bool = false
					for u: BattleUnit in ms.get_all_units():
						if u.faction_id == fac_id and u.state.is_alive():
							has_any = true
							break
					if not has_any:
						return "AllUnitsEliminated — Toàn quân Đại Việt đã bị tiêu diệt"
				"MaxRoundsUnfulfilled":
					var lim: int = int(d_cond.get("max_rounds", ctrl.max_rounds))
					if ctrl.current_round >= lim:
						return "MaxRoundsUnfulfilled — Hết giới hạn %d vòng chưa hoàn thành mục tiêu" % lim
	if ctrl.current_round >= ctrl.max_rounds:
		return "MaxRoundsUnfulfilled — Hết giới hạn %d vòng" % ctrl.max_rounds
	return "AllUnitsEliminated — Toàn quân bại trận"
