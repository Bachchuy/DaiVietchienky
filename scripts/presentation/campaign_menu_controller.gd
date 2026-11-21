class_name CampaignMenuController
extends Control

signal stage_selected(stage_id: int, is_free_replay: bool)
signal codex_requested()

var _stage_buttons: Dictionary = {}
var _codex_panel: CodexPanel = null


func _ready() -> void:
	name = "CampaignMenuController"
	_build_menu_ui()


func _load_stages_array() -> Array:
	var out: Array = []
	for st: StageDef in StaticDataLoader.load_stage_defs():
		if st != null:
			out.append(st.to_stage_meta_dict())
	return out


func is_stage_unlocked(stage_id: int, profile_dict: Dictionary = {}) -> bool:
	var stages: Array = _load_stages_array()
	if stages.is_empty():
		return stage_id == 10101
	var first_id: int = int((stages[0] as Dictionary).get("id", 10101))
	if stage_id == first_id:
		return true

	var stars_map: Dictionary = (
		profile_dict.get("stage_stars", profile_dict) as Dictionary
		if profile_dict.get("stage_stars", profile_dict) is Dictionary
		else {}
	)
	for i: int in range(1, stages.size()):
		var cur_id: int = int((stages[i] as Dictionary).get("id", 0))
		if cur_id == stage_id:
			var prev_id: int = int((stages[i - 1] as Dictionary).get("id", 0))
			var prev_stars: int = int(stars_map.get(str(prev_id), stars_map.get(prev_id, 0)))
			return prev_stars >= 1
	return false


func can_customize_general_seats(
	stage_id: int,
	is_free_replay: bool,
	stage_stars: Dictionary = {}
) -> bool:
	if not is_free_replay:
		return false
	var cleared_stars: int = int(stage_stars.get(str(stage_id), stage_stars.get(stage_id, 0)))
	return cleared_stars >= 1


func validate_general_loadout(general_ids: Array, max_seats: int = 3) -> bool:
	if general_ids.size() > max_seats:
		return false
	var seen: Dictionary = {}
	for gid_var: Variant in general_ids:
		var gid: int = int(gid_var)
		if gid <= 0:
			continue
		if seen.has(gid):
			return false
		seen[gid] = true
	return true


func is_troop_allowed_in_stage(troop_id: int, stage_def: Dictionary) -> bool:
	var banned: Variant = stage_def.get("banned_troop_ids", [])
	if banned is Array:
		for b_var: Variant in banned as Array:
			if int(b_var) == troop_id:
				return false
	return true


func _build_menu_ui() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1280.0, 720.0)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07, 0.98)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280.0, 720.0)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(140.0, 48.0)
	vbox.size = Vector2(1000.0, 620.0)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := Label.new()
	title.text = "ĐẠI VIỆT CHIẾN KỲ — CHIẾN DỊCH NHÀ TRẦN KHÁNG NGUYÊN (1282–1288)"
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var top_btns := HBoxContainer.new()
	top_btns.add_theme_constant_override("separation", 12)
	vbox.add_child(top_btns)

	var play_btn := Button.new()
	play_btn.name = "CampaignButton"
	play_btn.text = "⚔ VÀO CHIẾN DỊCH BẠCH ĐẰNG 1288"
	play_btn.custom_minimum_size = Vector2(280.0, 40.0)
	play_btn.pressed.connect(func() -> void: _launch_stage(10101, false))
	top_btns.add_child(play_btn)

	var codex_btn := Button.new()
	codex_btn.name = "CodexButton"
	codex_btn.text = "📖 SỬ KÝ & TƯ LIỆU (CODEX)"
	codex_btn.custom_minimum_size = Vector2(240.0, 40.0)
	codex_btn.pressed.connect(func() -> void:
		if _codex_panel != null:
			_codex_panel.visible = not _codex_panel.visible
		codex_requested.emit()
	)
	top_btns.add_child(codex_btn)

	var stages: Array = _load_stages_array()
	var save_mgr := BattleSaveManager.new()
	var prof: Dictionary = save_mgr.load_player_profile()
	var stars_map: Dictionary = prof.get("stage_stars", {}) as Dictionary if prof.get("stage_stars") is Dictionary else {}

	for s_var: Variant in stages:
		var sd: Dictionary = s_var as Dictionary
		var sid: int = int(sd.get("id", 10101))
		var sname: String = str(sd.get("name", "Màn chiến dịch"))
		var eco_tag: String = " [KINH TẾ HẬU CẦN]" if bool(sd.get("enable_economy", false)) else " [CHIẾN THUẬT]"
		var unlocked: bool = is_stage_unlocked(sid, prof)
		var st_cnt: int = int(stars_map.get(str(sid), 0))
		var btn := Button.new()
		btn.name = "Stage%dButton" % sid
		btn.text = "[%d] %s%s — %d/3 ★ (%s)" % [
			sid,
			sname,
			eco_tag,
			st_cnt,
			"Đã mở" if unlocked else "Khóa",
		]
		btn.disabled = not unlocked
		btn.custom_minimum_size = Vector2(960.0, 38.0)
		btn.pressed.connect(func() -> void: _launch_stage(sid, st_cnt > 0))
		vbox.add_child(btn)
		_stage_buttons[sid] = btn

	_codex_panel = CodexPanel.new()
	_codex_panel.visible = false
	add_child(_codex_panel)


func _launch_stage(p_stage_id: int, is_free_replay: bool) -> void:
	stage_selected.emit(p_stage_id, is_free_replay)
	if get_tree() != null and get_tree().current_scene == self:
		get_tree().set_meta(&"pending_stage_id", p_stage_id)
		get_tree().change_scene_to_file("res://game/battle/battle.tscn")
