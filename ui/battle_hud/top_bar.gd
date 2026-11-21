class_name BattleTopBar
extends PanelContainer

signal pause_requested()

@export var session: BattleSession = null

@onready var _pause_btn: Button = $Row/PauseButton
@onready var _mode_label: Label = $Row/ModeLabel
@onready var _mana_label: Label = $Row/ManaLabel
@onready var _eco_container: HBoxContainer = $Row/EconomyContainer
@onready var _coin_label: Label = $Row/EconomyContainer/CoinLabel
@onready var _food_label: Label = $Row/EconomyContainer/FoodLabel
@onready var _tech_label: Label = $Row/EconomyContainer/TechLabel
@onready var _objective_label: Label = $Row/ObjectiveLabel
@onready var _perf_label: Label = $Row/PerfLabel


func _ready() -> void:
	if _pause_btn != null:
		_pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	if _eco_container != null:
		_eco_container.visible = false


func get_mode_label() -> Label:
	return _mode_label


func get_perf_label() -> Label:
	return _perf_label


func set_objective_text(text_val: String) -> void:
	if _objective_label != null:
		_objective_label.text = text_val


func sync_from_controller(ctrl: BattleGameController, mode_title: String = "") -> void:
	if ctrl == null:
		return
	var fac_str: String = "ĐẠI VIỆT" if ctrl.current_faction_id == ctrl.player_faction_id else "ĐẠI NGUYÊN"
	if _mode_label != null:
		var prefix: String = mode_title if not mode_title.is_empty() else "ĐẠI VIỆT CHIẾN KỲ"
		_mode_label.text = "%s | VÒNG %02d/%02d | LƯỢT: %s" % [prefix, ctrl.current_round, ctrl.max_rounds, fac_str]

	var eco_enabled: bool = ctrl.enable_economy
	if _eco_container != null:
		_eco_container.visible = eco_enabled

	var eco_obj: Variant = ctrl.get("economy")
	var pf: int = ctrl.player_faction_id
	if eco_obj is Object and (eco_obj as Object).has_method("get_resource"):
		var eo: Object = eco_obj as Object
		if _mana_label != null:
			_mana_label.text = "Mưu: %d" % int(eo.call("get_resource", pf, "mana"))
		if eco_enabled:
			var food_v: int = int(eo.call("get_resource", pf, "food"))
			var starving_tag: String = " (ĐÓI!)" if food_v < 0 else ""
			if _coin_label != null:
				_coin_label.text = "Tiền: %d" % int(eo.call("get_resource", pf, "coin"))
			if _food_label != null:
				_food_label.text = "Lương: %d%s" % [food_v, starving_tag]
			if _tech_label != null:
				_tech_label.text = "Kỹ nghệ: %d" % int(eo.call("get_resource", pf, "tech"))
	elif _mana_label != null:
		_mana_label.text = "Mưu: 0"
