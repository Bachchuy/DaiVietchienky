class_name PauseModal
extends Control

signal resume_requested()
signal restart_requested()
signal save_and_exit_requested()
signal accessibility_changed(reduce_flashing: bool, vfx_quality: int, shake_scale: float)
signal bus_volume_changed(bus_name: String, linear_val: float)

@onready var _frame: ModalFrame = $ModalFrame
@onready var _shake_slider: HSlider = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/ShakeRow/ShakeScaleSlider
@onready var _reduce_flashing_check: CheckBox = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/ReduceFlashingCheck
@onready var _vfx_option: OptionButton = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/VfxRow/VfxQualityOption
@onready var _master_slider: HSlider = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/MasterRow/MasterVolumeSlider
@onready var _bgm_slider: HSlider = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/BgmRow/BgmVolumeSlider
@onready var _sfx_slider: HSlider = $ModalFrame/Center/Panel/Margin/VBox/BodyScroll/BodyContent/SfxRow/SfxVolumeSlider
@onready var _save_exit_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/SaveAndExitButton
@onready var _restart_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/RestartButton
@onready var _resume_btn: Button = $ModalFrame/Center/Panel/Margin/VBox/ButtonRow/ResumeButton

var _reduce_flashing: bool = false
var _vfx_quality_index: int = 2
var _shake_scale: float = 1.0


func _ready() -> void:
	if _frame != null:
		_frame.set_header("⚙ TẠM DỪNG & TRỢ NĂNG", "Điều chỉnh rung màn hình, hiệu ứng và âm lượng")
		_frame.accept_requested.connect(func() -> void: resume_requested.emit())
		_frame.cancel_requested.connect(func() -> void: resume_requested.emit())
	if _vfx_option != null and _vfx_option.item_count == 0:
		_vfx_option.add_item("Low (Thấp - 40%)", 0)
		_vfx_option.add_item("Medium (Vừa - 75%)", 1)
		_vfx_option.add_item("High (Cao - 100%)", 2)
		_vfx_option.select(2)

	if _shake_slider != null:
		_shake_slider.value_changed.connect(_on_shake_changed)
	if _reduce_flashing_check != null:
		_reduce_flashing_check.toggled.connect(_on_flashing_toggled)
	if _vfx_option != null:
		_vfx_option.item_selected.connect(_on_vfx_selected)
	if _master_slider != null:
		_master_slider.value_changed.connect(func(v: float) -> void: bus_volume_changed.emit("Master", clampf(v / 100.0, 0.0, 1.0)))
	if _bgm_slider != null:
		_bgm_slider.value_changed.connect(func(v: float) -> void: bus_volume_changed.emit("BGM", clampf(v / 100.0, 0.0, 1.0)))
	if _sfx_slider != null:
		_sfx_slider.value_changed.connect(func(v: float) -> void: bus_volume_changed.emit("SFX", clampf(v / 100.0, 0.0, 1.0)))

	if _resume_btn != null:
		_resume_btn.pressed.connect(func() -> void: resume_requested.emit())
	if _restart_btn != null:
		_restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	if _save_exit_btn != null:
		_save_exit_btn.pressed.connect(func() -> void: save_and_exit_requested.emit())


func open_modal(shake_scale: float = 1.0, reduce_flashing: bool = false, vfx_quality: int = 2) -> void:
	_shake_scale = clampf(shake_scale, 0.0, 1.0)
	_reduce_flashing = reduce_flashing
	_vfx_quality_index = clampi(vfx_quality, 0, 2)
	if _shake_slider != null:
		_shake_slider.set_value_no_signal(_shake_scale * 100.0)
	if _reduce_flashing_check != null:
		_reduce_flashing_check.set_pressed_no_signal(_reduce_flashing)
	if _vfx_option != null and _vfx_option.item_count > _vfx_quality_index:
		_vfx_option.select(_vfx_quality_index)
	visible = true
	if _frame != null:
		_frame.fit_to_viewport()
		_frame.focus_button(_resume_btn)


func close_modal() -> void:
	visible = false


func fit_to_viewport(vp_size: Vector2 = Vector2.ZERO) -> void:
	if _frame != null:
		_frame.fit_to_viewport(vp_size)


func _on_shake_changed(raw_val: float) -> void:
	_shake_scale = clampf(raw_val / 100.0 if _shake_slider != null and _shake_slider.max_value > 2.0 else raw_val, 0.0, 1.0)
	accessibility_changed.emit(_reduce_flashing, _vfx_quality_index, _shake_scale)


func _on_flashing_toggled(pressed_val: bool) -> void:
	_reduce_flashing = pressed_val
	accessibility_changed.emit(_reduce_flashing, _vfx_quality_index, _shake_scale)


func _on_vfx_selected(idx: int) -> void:
	_vfx_quality_index = clampi(idx, 0, 2)
	accessibility_changed.emit(_reduce_flashing, _vfx_quality_index, _shake_scale)
