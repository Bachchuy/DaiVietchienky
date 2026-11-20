extends "res://tests/test_case.gd"

const SAVES_DIR: String = "user://saves"

var e2e_seed: int = 12880409
var verbose: bool = false

var _saved_user_files: Dictionary[String, PackedByteArray] = {}
var _had_saves_dir: bool = false
var _orig_viewport_size: Vector2i = Vector2i.ZERO
var _viewport_resized: bool = false
var _signal_watchers: Array[Dictionary] = []


func before_each() -> void:
	super.before_each()
	_signal_watchers.clear()
	_backup_user_saves()
	Engine.time_scale = 1.0


func after_each() -> void:
	Engine.time_scale = 1.0
	for w: Dictionary in _signal_watchers:
		var obj: Variant = w.get("obj")
		var sig: String = str(w.get("sig", ""))
		var cb: Variant = w.get("cb")
		if obj is Object and is_instance_valid(obj) and cb is Callable:
			var o: Object = obj as Object
			if o.is_connected(sig, cb as Callable):
				o.disconnect(sig, cb as Callable)
	_signal_watchers.clear()

	if _viewport_resized and _scene_tree != null and _scene_tree.root != null:
		_scene_tree.root.size = _orig_viewport_size
		_viewport_resized = false

	super.after_each()
	_restore_user_saves()


func fail(msg: String) -> void:
	_assertions += 1
	_record_failure(msg)


func pump_frames(count: int = 1) -> void:
	if _scene_tree == null:
		return
	for _i: int in range(maxi(1, count)):
		await _scene_tree.process_frame


func set_test_viewport_size(target_size: Vector2i) -> void:
	if _scene_tree == null or _scene_tree.root == null:
		return
	if not _viewport_resized:
		_orig_viewport_size = _scene_tree.root.size
		_viewport_resized = true
	_scene_tree.root.size = target_size


func clear_user_saves() -> void:
	var dir: DirAccess = DirAccess.open(SAVES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and not dir.current_is_dir():
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _backup_user_saves() -> void:
	_saved_user_files.clear()
	_had_saves_dir = DirAccess.dir_exists_absolute(SAVES_DIR)
	if not _had_saves_dir:
		return
	var dir: DirAccess = DirAccess.open(SAVES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and not dir.current_is_dir():
			var full: String = SAVES_DIR.path_join(entry)
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(full)
			_saved_user_files[entry] = bytes
		entry = dir.get_next()
	dir.list_dir_end()


func _restore_user_saves() -> void:
	clear_user_saves()
	if not _had_saves_dir:
		if DirAccess.dir_exists_absolute(SAVES_DIR):
			DirAccess.remove_absolute(SAVES_DIR)
		return
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	for entry: String in _saved_user_files.keys():
		var full: String = SAVES_DIR.path_join(entry)
		var fa: FileAccess = FileAccess.open(full, FileAccess.WRITE)
		if fa != null:
			fa.store_buffer(_saved_user_files[entry])
			fa.close()


# ---------------------------------------------------------------------------
# Dynamic Runtime Contract Resolution (Zero static preload of M1-M6!)
# ---------------------------------------------------------------------------

func find_global_class_script(target_class: String) -> GDScript:
	if target_class.is_empty():
		return null
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == target_class:
			var path: String = str(entry.get("path", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				var res: Resource = load(path)
				if res is GDScript:
					return res as GDScript
	return null


func resolve_script(paths: Array[String], global_class: String = "") -> GDScript:
	for p: String in paths:
		if ResourceLoader.exists(p):
			var res: Resource = load(p)
			if res is GDScript:
				return res as GDScript
	if not global_class.is_empty():
		return find_global_class_script(global_class)
	return null


func require_script(
	paths: Array[String],
	global_class: String,
	milestone: String,
	desc: String
) -> GDScript:
	var scr: GDScript = resolve_script(paths, global_class)
	if scr == null:
		fail("Missing %s contract: %s (expected script in %s or class_name %s)" % [
			milestone,
			desc,
			str(paths),
			global_class if not global_class.is_empty() else "<none>",
		])
		return null
	return scr


func require_instance(
	paths: Array[String],
	global_class: String,
	milestone: String,
	desc: String,
	init_args: Array = []
) -> Variant:
	var scr: GDScript = require_script(paths, global_class, milestone, desc)
	if scr == null:
		return null
	if not scr.can_instantiate():
		fail("Broken %s contract: script cannot instantiate (%s)" % [milestone, scr.resource_path])
		return null
	if init_args.is_empty():
		return scr.new()
	return scr.callv("new", init_args)


func require_scene_instantiate(
	paths: Array[String],
	milestone: String,
	desc: String,
	attach_autofree: bool = true
) -> Node:
	for p: String in paths:
		if ResourceLoader.exists(p):
			var packed: Resource = load(p)
			if packed is PackedScene:
				var inst: Node = (packed as PackedScene).instantiate()
				if inst != null:
					if attach_autofree:
						add_child_autofree(inst)
					return inst
	fail("Missing %s contract: scene %s (expected one of %s)" % [milestone, desc, str(paths)])
	return null


func spawn_battle_sandbox() -> Node:
	return require_scene_instantiate(
		["res://scenes/battle/battle_sandbox_cp1.tscn"],
		"Baseline",
		"BattleSandboxCP1",
		true
	)


func require_fsm(sandbox: Node, milestone: String = "M1") -> Object:
	if sandbox != null:
		if sandbox.has_method("get_input_fsm"):
			var fsm_obj: Variant = sandbox.call("get_input_fsm")
			if fsm_obj is Object:
				return fsm_obj as Object
		var by_name: Node = find_node_by_name_recursive(sandbox, "BattleInputFSM")
		if by_name != null:
			return by_name
		if sandbox.get("input_fsm") is Object:
			return sandbox.get("input_fsm") as Object
		if sandbox.get("_input_fsm") is Object:
			return sandbox.get("_input_fsm") as Object

	var fsm_scr: GDScript = resolve_script(
		[
			"res://scripts/presentation/battle_input_fsm.gd",
			"res://scripts/presentation/input/battle_input_fsm.gd",
		],
		"BattleInputFSM"
	)
	if fsm_scr == null:
		fail("Missing %s contract: BattleInputFSM (res://scripts/presentation/battle_input_fsm.gd)" % milestone)
		return null
	fail("Missing %s contract: BattleInputFSM is not wired into BattleSandboxCP1" % milestone)
	return null


func get_fsm_state_value(fsm: Object) -> int:
	if fsm == null:
		return -1
	if fsm.has_method("get_state"):
		return int(fsm.call("get_state"))
	if fsm.has_method("get_current_state"):
		return int(fsm.call("get_current_state"))
	var st: Variant = fsm.get("current_state")
	if st != null:
		return int(st)
	var st2: Variant = fsm.get("state")
	if st2 != null:
		return int(st2)
	return -1


func get_fsm_state_enum(fsm: Object) -> Dictionary:
	if fsm == null:
		return {}
	var scr: Script = fsm.get_script() as Script
	if scr != null:
		var consts: Dictionary = scr.get_script_constant_map()
		if consts.has("State") and consts["State"] is Dictionary:
			return consts["State"] as Dictionary
	return {}


func require_hud_controller(sandbox: Node, milestone: String = "M2") -> Object:
	if sandbox != null:
		if sandbox.has_method("get_hud_controller"):
			var hc: Variant = sandbox.call("get_hud_controller")
			if hc is Object:
				return hc as Object
		for n_name: String in ["BattleHudController", "BattleHud", "BattleHUD"]:
			var found: Node = find_node_by_name_recursive(sandbox, n_name)
			if found != null:
				return found
	var hud_scr: GDScript = resolve_script(
		[
			"res://scripts/presentation/battle_hud.gd",
			"res://scripts/presentation/battle_hud_controller.gd",
			"res://scripts/presentation/ui/battle_hud.gd",
			"res://scripts/presentation/ui/battle_hud_controller.gd",
		],
		"BattleHudController"
	)
	if hud_scr == null:
		fail("Missing %s contract: BattleHudController / Map-First HUD" % milestone)
		return null
	fail("Missing %s contract: BattleHudController not attached to BattleSandboxCP1" % milestone)
	return null


func require_hud_node(
	root_node: Node,
	candidate_names: Array[String],
	milestone: String,
	desc: String
) -> Node:
	if root_node != null:
		for c_name: String in candidate_names:
			var found: Node = find_node_by_name_recursive(root_node, c_name)
			if found != null:
				return found
	if _scene_tree != null and _scene_tree.root != null:
		for c_name: String in candidate_names:
			var found_root: Node = find_node_by_name_recursive(_scene_tree.root, c_name)
			if found_root != null:
				return found_root
	fail("Missing %s contract: HUD node %s (expected one of %s)" % [milestone, desc, str(candidate_names)])
	return null


func require_save_manager(milestone: String = "M3") -> Object:
	var inst: Variant = require_instance(
		["res://scripts/core/battle_save_manager.gd"],
		"BattleSaveManager",
		milestone,
		"BattleSaveManager (pure RefCounted Tier 2/3 Save/Load)"
	)
	return inst as Object if inst is Object else null


func require_juice_helper(sandbox: Node, milestone: String = "M3") -> Object:
	if sandbox != null:
		if sandbox.has_method("get_juice_helper"):
			var jh: Variant = sandbox.call("get_juice_helper")
			if jh is Object:
				return jh as Object
		var found: Node = find_node_by_name_recursive(sandbox, "CombatJuiceHelper")
		if found != null:
			return found
	var scr: GDScript = resolve_script(
		[
			"res://scripts/presentation/combat_juice_helper.gd",
			"res://scripts/presentation/vfx/combat_juice_helper.gd",
		],
		"CombatJuiceHelper"
	)
	if scr == null:
		fail("Missing %s contract: CombatJuiceHelper" % milestone)
		return null
	fail("Missing %s contract: CombatJuiceHelper not attached/exposed on BattleSandboxCP1" % milestone)
	return null


func require_audio_manager(sandbox: Node, milestone: String = "M3") -> Object:
	if sandbox != null:
		if sandbox.has_method("get_audio_manager"):
			var am: Variant = sandbox.call("get_audio_manager")
			if am is Object:
				return am as Object
		var found: Node = find_node_by_name_recursive(sandbox, "BattleAudioManager")
		if found != null:
			return found
	var scr: GDScript = resolve_script(
		[
			"res://scripts/presentation/battle_audio_manager.gd",
			"res://scripts/presentation/audio/battle_audio_manager.gd",
		],
		"BattleAudioManager"
	)
	if scr == null:
		fail("Missing %s contract: BattleAudioManager" % milestone)
		return null
	fail("Missing %s contract: BattleAudioManager not attached/exposed on BattleSandboxCP1" % milestone)
	return null


func require_economy_script(milestone: String = "M4") -> GDScript:
	return require_script(
		[
			"res://scripts/core/battle_economy.gd",
			"res://scripts/core/battle_economy_resolver.gd",
		],
		"BattleEconomy",
		milestone,
		"BattleEconomy / BattleEconomyResolver"
	)


func assert_has_signal(obj: Object, sig_name: String, milestone: String) -> bool:
	_assertions += 1
	if obj == null or not obj.has_signal(sig_name):
		_record_failure("Missing %s contract: signal '%s' on %s" % [milestone, sig_name, str(obj)])
		return false
	return true


func assert_has_method(obj: Object, method_name: String, milestone: String) -> bool:
	_assertions += 1
	if obj == null or not obj.has_method(method_name):
		_record_failure("Missing %s contract: method '%s' on %s" % [milestone, method_name, str(obj)])
		return false
	return true


func assert_has_property(obj: Object, prop_name: String, milestone: String) -> bool:
	_assertions += 1
	if obj == null:
		_record_failure("Missing %s contract: null object for property '%s'" % [milestone, prop_name])
		return false
	for p: Dictionary in obj.get_property_list():
		if str(p.get("name", "")) == prop_name:
			return true
	_record_failure("Missing %s contract: property '%s' on %s" % [milestone, prop_name, str(obj)])
	return false


# ---------------------------------------------------------------------------
# Node Tree, Signal & Opaque-Box Input Helpers
# ---------------------------------------------------------------------------

func find_node_by_name_recursive(root_node: Node, target_name: String) -> Node:
	if root_node == null:
		return null
	if str(root_node.name).to_lower() == target_name.to_lower():
		return root_node
	for child: Node in root_node.get_children():
		var hit: Node = find_node_by_name_recursive(child, target_name)
		if hit != null:
			return hit
	return null


func find_nodes_by_class_recursive(root_node: Node, class_str: String) -> Array[Node]:
	var results: Array[Node] = []
	if root_node == null:
		return results
	if root_node.is_class(class_str):
		results.append(root_node)
	for child: Node in root_node.get_children():
		results.append_array(find_nodes_by_class_recursive(child, class_str))
	return results


func find_button_matching(
	root_node: Node,
	names: Array[String],
	text_tokens: Array[String]
) -> BaseButton:
	if root_node == null:
		return null
	var buttons: Array[Node] = find_nodes_by_class_recursive(root_node, "BaseButton")
	for b_node: Node in buttons:
		var btn: BaseButton = b_node as BaseButton
		var b_name: String = str(btn.name).to_lower()
		for n: String in names:
			if b_name == n.to_lower() or b_name.contains(n.to_lower()):
				return btn
	for b_node: Node in buttons:
		var btn: BaseButton = b_node as BaseButton
		var b_text: String = ""
		if btn is Button:
			b_text = (btn as Button).text.to_lower()
		if not b_text.is_empty():
			for tok: String in text_tokens:
				if b_text.contains(tok.to_lower()):
					return btn
	return null


func collect_labels_text(root_node: Node) -> String:
	if root_node == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for lbl: Node in find_nodes_by_class_recursive(root_node, "Label"):
		var l: Label = lbl as Label
		if l.visible and not l.text.is_empty():
			parts.append(l.text)
	for rlbl: Node in find_nodes_by_class_recursive(root_node, "RichTextLabel"):
		var rl: RichTextLabel = rlbl as RichTextLabel
		if rl.visible and not rl.text.is_empty():
			parts.append(rl.text)
	return "\n".join(parts)


func watch_signal(obj: Object, sig_name: String) -> Array:
	var events: Array = []
	if obj == null or not obj.has_signal(sig_name):
		return events
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
		var args: Array = []
		if a != null:
			args.append(a)
		if b != null:
			args.append(b)
		if c != null:
			args.append(c)
		if d != null:
			args.append(d)
		events.append(args)
	obj.connect(sig_name, cb)
	_signal_watchers.append({"obj": obj, "sig": sig_name, "cb": cb})
	return events


func axial_to_screen(sandbox: Node, axial: Vector2i) -> Vector2:
	var map_view: Node = sandbox.call("get_map_view") if sandbox.has_method("get_map_view") else null
	var hex_sz: float = float(map_view.get("hex_size")) if map_view != null else HexMath.DEFAULT_HEX_SIZE
	var world_pos: Vector2 = HexMath.axial_to_world(axial, hex_sz)
	if sandbox is CanvasItem:
		return (sandbox as CanvasItem).get_canvas_transform() * world_pos
	return world_pos


func inject_left_click_screen(screen_pos: Vector2) -> void:
	if _scene_tree == null or _scene_tree.root == null:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pos
	motion.global_position = screen_pos
	Input.parse_input_event(motion)
	Input.flush_buffered_events()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	Input.parse_input_event(press)
	Input.flush_buffered_events()

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func inject_tap_screen(screen_pos: Vector2) -> void:
	if _scene_tree == null or _scene_tree.root == null:
		return
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = screen_pos
	Input.parse_input_event(press)
	Input.flush_buffered_events()

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = screen_pos
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func inject_right_click_screen(screen_pos: Vector2, drag_delta: Vector2 = Vector2.ZERO) -> void:
	if _scene_tree == null or _scene_tree.root == null:
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	Input.parse_input_event(press)
	Input.flush_buffered_events()

	if drag_delta != Vector2.ZERO:
		var motion := InputEventMouseMotion.new()
		motion.position = screen_pos + drag_delta
		motion.global_position = screen_pos + drag_delta
		motion.relative = drag_delta
		Input.parse_input_event(motion)
		Input.flush_buffered_events()

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = screen_pos + drag_delta
	release.global_position = screen_pos + drag_delta
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func inject_key_press(keycode: Key) -> void:
	if _scene_tree == null or _scene_tree.root == null:
		return
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()

	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func compute_hud_coverage_ratio(hud_layer: CanvasLayer, viewport_size: Vector2) -> Dictionary:
	var vp_area: float = maxf(1.0, viewport_size.x * viewport_size.y)
	var hud_area: float = 0.0
	var counted_rects: Array[Rect2] = []
	if hud_layer != null:
		for child: Node in hud_layer.get_children():
			if child is Control:
				var ctrl: Control = child as Control
				if not ctrl.visible:
					continue
				var r: Rect2 = ctrl.get_global_rect()
				# Ignore full-viewport pass-through wrapper containers
				if r.size.x >= viewport_size.x * 0.95 and r.size.y >= viewport_size.y * 0.95:
					for sub: Node in ctrl.get_children():
						if sub is Control and (sub as Control).visible:
							var sr: Rect2 = (sub as Control).get_global_rect()
							if sr.size.y < viewport_size.y * 0.5:
								hud_area += sr.size.x * sr.size.y
								counted_rects.append(sr)
				elif r.size.x > 0.0 and r.size.y > 0.0:
					hud_area += r.size.x * r.size.y
					counted_rects.append(r)
	var map_ratio: float = clampf(1.0 - (hud_area / vp_area), 0.0, 1.0)
	return {
		"hud_area": hud_area,
		"viewport_area": vp_area,
		"map_ratio": map_ratio,
		"rects": counted_rects,
	}


# ---------------------------------------------------------------------------
# File / Repo Audit Helpers
# ---------------------------------------------------------------------------

func list_files_recursive(dir_path: String, extensions: Array[String] = []) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				found.append_array(list_files_recursive(full, extensions))
			else:
				if extensions.is_empty():
					found.append(full)
				else:
					var low: String = entry.to_lower()
					for ext: String in extensions:
						if low.ends_with(ext.to_lower()):
							found.append(full)
							break
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func read_text_file(res_path: String) -> String:
	if not FileAccess.file_exists(res_path):
		return ""
	var fa: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if fa == null:
		return ""
	var txt: String = fa.get_as_text()
	fa.close()
	return txt


func read_json_file(res_path: String) -> Variant:
	var txt: String = read_text_file(res_path)
	if txt.is_empty():
		return null
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		return null
	return parser.data
