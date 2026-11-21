class_name BriefingModal
extends Control

signal start_pressed()
signal skip_pressed()

@onready var _frame: ModalFrame = $ModalFrame
@onready var _body_label: Label = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/BriefingBodyLabel
@onready var _skip_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/SkipButton
@onready var _start_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/StartButton


func _ready() -> void:
	if _skip_btn != null:
		_skip_btn.pressed.connect(func() -> void: skip_pressed.emit())
	if _start_btn != null:
		_start_btn.pressed.connect(func() -> void: start_pressed.emit())
	if _frame != null:
		_frame.accept_requested.connect(func() -> void: start_pressed.emit())
		_frame.cancel_requested.connect(func() -> void: skip_pressed.emit())


func open_briefing(stage_meta: Dictionary) -> void:
	var st_id: int = int(stage_meta.get("id", stage_meta.get("stage_id", 10101)))
	var st_name: String = str(stage_meta.get("name", "Đại Chiến Bạch Đằng 1288"))
	var mod_type: String = str(stage_meta.get("modeling_type", "historical_claim"))
	var src_ref: String = str(stage_meta.get("source_ref", "Đại Việt Sử Ký Toàn Thư (1288)"))
	if _frame != null:
		_frame.set_header(
			"📜 BRIEFING CHIẾN TRẬN: %s (ID: %d)" % [st_name, st_id],
			"Nhãn minh bạch Lịch sử: [%s] | Nguồn: %s" % [mod_type, src_ref]
		)
	if _body_label != null:
		_body_label.text = (
			"• Mục tiêu Chiến thắng:\n"
			+ "  (1) Tiêu diệt Soái hạm Ô Mã Nhi (9001) khi giữ vững Bến Tín Hiệu (2,8); HOẶC\n"
			+ "  (2) Giữ vững Bến Tín Hiệu (2,8) & loại >= 75% quân Đại Nguyên khi hết Vòng 10.\n"
			+ "• Tiêu chuẩn 3 Sao:\n"
			+ "  ★ Thắng trận | ★★ Hoàn thành <= 8 vòng | ★★★ Tổn thất HP <= 20%.\n"
			+ "• Mẹo: Chạm 1 lần vào quân địch trong tầm đỏ để tấn công ngay; chạm vào quân ngoài tầm hoặc chuột phải để xem thông số."
		)
	visible = true
	if _frame != null:
		_frame.fit_to_viewport()
		_frame.focus_button(_start_btn)


func fit_to_viewport(vp_size: Vector2 = Vector2.ZERO) -> void:
	if _frame != null:
		_frame.fit_to_viewport(vp_size)
