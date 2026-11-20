class_name CodexPanel
extends Panel

const CODEX_DATA_PATH: String = "res://data/settings/codex_entries.json"

var _entries: Array = []
var _search_edit: LineEdit = null
var _list_label: Label = null
var _close_btn: Button = null


func _init() -> void:
	name = "CodexPanel"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(720.0, 420.0)
	size = Vector2(720.0, 420.0)
	position = Vector2(280.0, 140.0)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.09, 0.08, 0.97)
	st.border_color = Color(0.86, 0.68, 0.28, 0.96)
	st.border_width_top = 2
	st.border_width_bottom = 2
	st.border_width_left = 2
	st.border_width_right = 2
	add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(14.0, 12.0)
	vbox.size = Vector2(692.0, 396.0)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "📖 BÁCH KHOA SỬ KÝ & MINH BẠCH TƯ LIỆU (HISTORICAL CODEX)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)

	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.text = "ĐÓNG ✕"
	_close_btn.custom_minimum_size = Vector2(88.0, 28.0)
	_close_btn.pressed.connect(func() -> void: visible = false)
	header.add_child(_close_btn)

	_search_edit = LineEdit.new()
	_search_edit.name = "CodexSearchEdit"
	_search_edit.placeholder_text = "Tìm theo niên đại (938, 981, 1288), danh tướng hoặc nguồn sử liệu..."
	_search_edit.text_changed.connect(func(q: String) -> void: filter_entries(q))
	vbox.add_child(_search_edit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list_label = Label.new()
	_list_label.name = "CodexEntriesLabel"
	_list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	_list_label.add_theme_font_size_override("font_size", 12)
	scroll.add_child(_list_label)

	_load_entries()
	filter_entries("")


func _load_entries() -> void:
	_entries = StaticDataLoader.load_json_array(CODEX_DATA_PATH)


func get_all_entries() -> Array:
	if _entries.is_empty():
		_load_entries()
	return _entries


func filter_entries(query: String) -> Array:
	if _entries.is_empty():
		_load_entries()
	var q: String = query.strip_edges().to_lower()
	var matched: Array = []
	var lines: PackedStringArray = PackedStringArray()

	for item: Variant in _entries:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		var hay: String = (
			str(d.get("id", "")) + " "
			+ str(d.get("title", "")) + " "
			+ str(d.get("era", "")) + " "
			+ str(d.get("source_ref", "")) + " "
			+ str(d.get("summary", ""))
		).to_lower()
		if q.is_empty() or hay.contains(q):
			matched.append(d)
			var grade_str: String = str(d.get("evidence_grade", ""))
			var grade_tag: String = (" | Hạng tư liệu: %s" % grade_str) if not grade_str.is_empty() else ""
			lines.append("• [%s] %s (%s%s | Nhãn: %s)\n  Nguồn: %s\n  %s" % [
				str(d.get("era", "")),
				str(d.get("title", "")),
				str(d.get("category", "")),
				grade_tag,
				str(d.get("modeling_type", "")),
				str(d.get("source_ref", "")),
				str(d.get("summary", "")),
			])

	if _list_label != null:
		_list_label.text = "\n\n".join(lines) if not lines.is_empty() else "Không tìm thấy mục tư liệu phù hợp."
	return matched
