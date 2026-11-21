class_name ModalFrame
extends Control

signal accept_requested()
signal cancel_requested()

@export var preferred_width: float = 580.0
@export var max_body_height_ratio: float = 0.48
@export var min_body_height: float = 120.0

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var _subtitle_label: Label = $Center/Panel/Margin/VBox/SubtitleLabel
@onready var _body_scroll: ScrollContainer = $Center/Panel/Margin/VBox/BodyScroll
@onready var _body_content: VBoxContainer = $Center/Panel/Margin/VBox/BodyScroll/BodyContent
@onready var _button_row: HBoxContainer = $Center/Panel/Margin/VBox/ButtonRow

var _default_focus_button: BaseButton = null


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	fit_to_viewport()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		if ke.keycode == KEY_ESCAPE or ke.is_action_pressed("ui_cancel"):
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			cancel_requested.emit()
		elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.is_action_pressed("ui_accept"):
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			accept_requested.emit()


func set_header(title_text: String, subtitle_text: String = "") -> void:
	if _title_label != null:
		_title_label.text = title_text
	if _subtitle_label != null:
		_subtitle_label.text = subtitle_text
		_subtitle_label.visible = not subtitle_text.is_empty()


func get_body_content() -> VBoxContainer:
	return _body_content


func get_button_row() -> HBoxContainer:
	return _button_row


func get_panel() -> PanelContainer:
	return _panel


func focus_button(btn: BaseButton) -> void:
	_default_focus_button = btn
	if btn != null and is_visible_in_tree() and btn.is_visible_in_tree():
		btn.call_deferred("grab_focus")


func fit_to_viewport(vp_override: Vector2 = Vector2.ZERO) -> void:
	var vp: Vector2 = vp_override
	if vp == Vector2.ZERO and get_viewport() != null:
		vp = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1280.0, 720.0)
	if _panel != null:
		var w: float = minf(preferred_width, maxf(280.0, vp.x - 48.0))
		_panel.custom_minimum_size = Vector2(w, 0.0)
		_panel.custom_maximum_size = Vector2(maxf(280.0, vp.x - 32.0), maxf(240.0, vp.y * 0.86))
	if _body_scroll != null:
		var max_h: float = maxf(min_body_height, vp.y * max_body_height_ratio)
		var content_h: float = min_body_height
		if _body_content != null:
			content_h = maxf(min_body_height, _body_content.get_combined_minimum_size().y + 8.0)
		_body_scroll.custom_minimum_size = Vector2(0.0, minf(content_h, max_h))


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		fit_to_viewport()
		call_deferred("fit_to_viewport")
		if _default_focus_button != null and _default_focus_button.is_visible_in_tree():
			_default_focus_button.call_deferred("grab_focus")


func _on_viewport_size_changed() -> void:
	if is_visible_in_tree():
		fit_to_viewport()
