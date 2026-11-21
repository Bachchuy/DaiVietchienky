class_name DialogueModal
extends Control

signal continue_pressed()
signal skip_all_pressed()
signal dialogue_finished()

@onready var _frame: ModalFrame = $ModalFrame
@onready var _body_label: Label = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/DialogueBodyLabel
@onready var _skip_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/SkipDialogueButton
@onready var _continue_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/ContinueButton

var _dialogues: Dictionary = {}
var _queue: Array[Dictionary] = []
var _index: int = 0


func _ready() -> void:
	if _skip_btn != null:
		_skip_btn.pressed.connect(func() -> void: skip_all_pressed.emit())
	if _continue_btn != null:
		_continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	if _frame != null:
		_frame.accept_requested.connect(func() -> void: continue_pressed.emit())
		_frame.cancel_requested.connect(func() -> void: skip_all_pressed.emit())


func set_dialogues(dialogues_dict: Dictionary) -> void:
	_dialogues = dialogues_dict.duplicate(true)
	_queue.clear()
	_index = 0


func has_dialogue(dialogue_id: String) -> bool:
	return _dialogues.has(dialogue_id)


func queue_dialogue_id(dialogue_id: String, camera: BattleCameraController = null) -> void:
	if not _dialogues.has(dialogue_id):
		push_warning("BattleHud: Unknown dialogue_id '%s' ignored safely." % dialogue_id)
		return
	var raw: Variant = _dialogues.get(dialogue_id)
	if raw is Dictionary:
		_queue.append((raw as Dictionary).duplicate(true))
	elif raw is Array:
		for item: Variant in raw as Array:
			if item is Dictionary:
				_queue.append((item as Dictionary).duplicate(true))
	if not visible and not _queue.is_empty():
		_index = 0
		_present_current_dialogue(camera)


func show_dialogue_entries(entries: Array, camera: BattleCameraController = null) -> void:
	_queue.clear()
	for item: Variant in entries:
		if item is Dictionary:
			_queue.append((item as Dictionary).duplicate(true))
	_index = 0
	if not _queue.is_empty():
		_present_current_dialogue(camera)


func advance_dialogue(camera: BattleCameraController = null) -> void:
	_index += 1
	if _index >= _queue.size():
		skip_dialogue_queue(camera)
	else:
		_present_current_dialogue(camera)


func skip_dialogue_queue(camera: BattleCameraController = null) -> void:
	_queue.clear()
	_index = 0
	close_dialogue()
	if camera != null:
		camera.camera_locked = false
	dialogue_finished.emit()


func show_line(speaker: String, line_text: String, line_idx: int = 0, total_lines: int = 1) -> void:
	if _frame != null:
		var count_tag: String = " (%d/%d)" % [line_idx + 1, total_lines] if total_lines > 1 else ""
		_frame.set_header("💬 %s%s" % [speaker, count_tag], "")
	if _body_label != null:
		_body_label.text = "\"%s\"" % line_text
	visible = true
	if _frame != null:
		_frame.fit_to_viewport()
		_frame.focus_button(_continue_btn)


func close_dialogue() -> void:
	visible = false


func fit_to_viewport(vp_size: Vector2 = Vector2.ZERO) -> void:
	if _frame != null:
		_frame.fit_to_viewport(vp_size)


func _present_current_dialogue(camera: BattleCameraController = null) -> void:
	if _index >= _queue.size():
		return
	var entry: Dictionary = _queue[_index]
	if camera != null:
		camera.camera_locked = true
	show_line(str(entry.get("speaker", "Tướng lĩnh")), str(entry.get("line", "")), _index, _queue.size())
