class_name TutorialOverlay
extends Panel

const TIP_TEXTS: Dictionary[String, String] = {
	"tip_select_unit": "💡 Hướng dẫn: Chạm đạo quân Đại Việt để xem vùng hành quân xanh dương (Reachable) và tầm công kích đỏ (Attackable).",
	"tip_post_move_undo": "💡 Hướng dẫn: Sau khi di chuyển, bạn có thể nhấn [HOÀN TÁC] (hoặc phím Z / chuột phải) tối đa 1 lần/lượt nếu chưa lộ sương mù hay vào ZoC địch.",
	"tip_two_step_attack": "💡 Hướng dẫn: Chạm mục tiêu lần 1 để mở Hộp Dự Báo Giao Chiến (CombatPreviewBox), chạm lần 2 hoặc nhấn [ĐÁNH] để xác nhận công kích.",
	"tip_tide_fall_stakes": "💡 Hướng dẫn: Đầu Vòng 4 thủy triều rút sẽ lộ diện Bãi Cọc Ngầm Bạch Đằng, gây sát thương lớn và khóa di chuyển thuyền địch.",
	"tip_economy_starvation": "💡 Hướng dẫn Hậu cần: Đầu mỗi vòng quân đội tiêu hao Lương (MealFood). Nếu Lương < 0 (Starvation), quân bị giảm 1 bậc Sĩ khí (tối đa xuống LOW) và chỉ còn 75% sát thương.",
}

var _seen_tips: Dictionary = {}
var _active_tip_id: String = ""
var _tip_label: Label = null
var _dismiss_btn: Button = null


func _init() -> void:
	name = "TutorialOverlay"
	visible = false
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(540.0, 54.0)
	size = Vector2(540.0, 54.0)
	position = Vector2(370.0, 46.0)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.14, 0.18, 0.95)
	st.border_color = Color(0.46, 0.80, 0.96, 0.95)
	st.border_width_top = 2
	st.border_width_bottom = 2
	st.border_width_left = 2
	st.border_width_right = 2
	add_theme_stylebox_override("panel", st)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(10.0, 6.0)
	hbox.size = Vector2(520.0, 42.0)
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	_tip_label = Label.new()
	_tip_label.name = "TutorialTipLabel"
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_tip_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(_tip_label)

	_dismiss_btn = Button.new()
	_dismiss_btn.name = "CloseButton"
	_dismiss_btn.text = "ĐÃ HIỂU ✕"
	_dismiss_btn.custom_minimum_size = Vector2(88.0, 32.0)
	_dismiss_btn.pressed.connect(dismiss_current_tip)
	hbox.add_child(_dismiss_btn)


func _ready() -> void:
	_load_persisted_flags()


func _load_persisted_flags() -> void:
	var save_mgr := BattleSaveManager.new()
	var prof: Dictionary = save_mgr.load_player_profile()
	var raw_flags: Variant = prof.get("tutorial_flags", {})
	if raw_flags is Dictionary:
		_seen_tips = (raw_flags as Dictionary).duplicate(true)


func _persist_flags() -> void:
	var save_mgr := BattleSaveManager.new()
	var prof: Dictionary = save_mgr.load_player_profile()
	prof["tutorial_flags"] = _seen_tips.duplicate(true)
	save_mgr.save_player_profile(prof)


func should_show_economy_tip(enable_economy: bool) -> bool:
	return enable_economy


func trigger_tip(tip_id: String, enable_economy: bool = true) -> bool:
	if tip_id.is_empty():
		return false
	if tip_id.contains("economy") and not should_show_economy_tip(enable_economy):
		return false
	if bool(_seen_tips.get(tip_id, false)):
		return false

	_seen_tips[tip_id] = true
	_active_tip_id = tip_id
	_persist_flags()
	if _tip_label != null:
		_tip_label.text = TIP_TEXTS.get(tip_id, "💡 Hướng dẫn chiến thuật: " + tip_id)
	visible = true
	return true


func dismiss_current_tip() -> void:
	_active_tip_id = ""
	visible = false


func reset_tutorial_flags() -> void:
	_seen_tips.clear()
	_active_tip_id = ""
	visible = false
	_persist_flags()
