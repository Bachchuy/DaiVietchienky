class_name UnitInspector
extends PanelContainer

const MORALE_TEXT: Dictionary[int, String] = {
	0: "Hỗn Loạn (CHAOS)",
	1: "Dao Động (LOW)",
	2: "Ổn Định (NORMAL)",
	3: "Hưng Phấn (HIGH)",
}

const TERRAIN_TEXT: Dictionary[int, String] = {
	0: "Đồng bằng (2 MP)",
	1: "Rừng tre (+20% Thủ)",
	2: "Đồi cao (+15% Thủ)",
	3: "Đầm lầy (-10% Thủ)",
	4: "Sông cạn / Bờ bãi",
	5: "Sông sâu Bạch Đằng",
	6: "Thành lũy (+30% Thủ)",
	7: "Bến / Đường (1 MP)",
	8: "Bãi cọc ngầm lộ diện",
}

const BRANCH_TEXT: Dictionary[int, String] = {
	0: "Bộ Binh",
	1: "Cung / Nỏ",
	2: "Kỵ Binh",
	3: "Thủy Quân Nhẹ",
	4: "Thủy Quân Nặng",
	5: "Công Thành",
}

@onready var _name_label: Label = $Margin/VBox/UnitNameLabel
@onready var _faction_label: Label = $Margin/VBox/FactionLabel
@onready var _hp_label: Label = $Margin/VBox/HpLabel
@onready var _atk_label: Label = $Margin/VBox/StatsGrid/AtkLabel
@onready var _def_label: Label = $Margin/VBox/StatsGrid/DefLabel
@onready var _mp_label: Label = $Margin/VBox/StatsGrid/MpLabel
@onready var _range_label: Label = $Margin/VBox/StatsGrid/RangeLabel
@onready var _morale_label: Label = $Margin/VBox/MoraleLabel
@onready var _terrain_label: Label = $Margin/VBox/TerrainLabel
@onready var _status_label: Label = $Margin/VBox/StatusLabel


func _ready() -> void:
	visible = false


func show_unit(unit: BattleUnit, axial: Vector2i, map_state: BattleMapState, player_faction_id: int = 1) -> void:
	if unit == null:
		clear()
		return
	var branch_str: String = BRANCH_TEXT.get(int(unit.command_branch), "Đạo quân")
	var title_str: String = unit.display_name
	if not unit.general_name.is_empty() and not title_str.contains(unit.general_name):
		title_str = "%s — %s" % [unit.general_name, title_str]
	_name_label.text = "%s (%s)" % [title_str, branch_str]

	var is_hostile: bool = map_state != null and map_state.is_hostile(player_faction_id, unit.faction_id)
	var fac_name: String = "Đại Nguyên" if is_hostile else ("Đại Việt" if unit.faction_id == player_faction_id else "Đồng Minh")
	_faction_label.text = "Phe: %s" % fac_name
	_faction_label.add_theme_color_override("font_color", Color(0.96, 0.56, 0.52) if is_hostile else Color(0.56, 0.86, 1.0))

	_hp_label.text = "HP: %d/%d (%d/%d cờ)" % [unit.state.current_hp, unit.state.max_hp, unit.get_active_banners(), unit.max_stack]
	_atk_label.text = "Công: %d" % unit.base_atk
	_def_label.text = "Thủ: %d" % unit.base_def
	_mp_label.text = "MP: %d/%d" % [unit.state.current_mp, unit.max_mp]
	_range_label.text = "Tầm: %d-%d" % [unit.min_range, unit.max_range]
	_morale_label.text = "Sĩ khí: %s" % MORALE_TEXT.get(int(unit.state.morale), "Ổn Định")

	var off: Vector2i = HexMath.axial_to_odd_r(axial)
	var t_name: String = TERRAIN_TEXT.get(int(map_state.get_terrain(axial)), "Địa hình") if map_state != null and map_state.is_valid_hex(axial) else "Địa hình"
	_terrain_label.text = "Ô (%d,%d): %s" % [off.x, off.y, t_name]

	var tags: PackedStringArray = PackedStringArray()
	if unit.state.has_acted:
		tags.append("Đã hành động")
	if unit.state.chaos_turns > 0:
		tags.append("Hỗn loạn (%d lượt)" % unit.state.chaos_turns)
	if unit.state.march_disabled_turns > 0:
		tags.append("Khóa di chuyển (%d lượt)" % unit.state.march_disabled_turns)
	if unit.state.attack_disabled_turns > 0:
		tags.append("Khóa tấn công (%d lượt)" % unit.state.attack_disabled_turns)
	_status_label.text = "Trạng thái: %s" % ", ".join(tags)
	_status_label.visible = not tags.is_empty()
	visible = true


func clear() -> void:
	visible = false
