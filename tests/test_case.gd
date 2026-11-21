class_name GdTestCase
extends RefCounted

var _failures: Array[String] = []
var _assertions: int = 0
var _autofree_nodes: Array[Node] = []
var _scene_tree: SceneTree = null
var stress_mode: bool = false


func setup_context(tree: SceneTree) -> void:
	_scene_tree = tree
	_failures.clear()
	_assertions = 0
	_autofree_nodes.clear()


func before_each() -> void:
	pass


func _stop_audio_in_subtree(node: Node) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stop()
	for child: Node in node.get_children():
		_stop_audio_in_subtree(child)


func after_each() -> void:
	for i: int in range(_autofree_nodes.size() - 1, -1, -1):
		var node: Node = _autofree_nodes[i]
		if is_instance_valid(node):
			_stop_audio_in_subtree(node)
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	_autofree_nodes.clear()


func add_child_autofree(node: Node) -> Node:
	_autofree_nodes.append(node)
	if _scene_tree != null and _scene_tree.root != null:
		_scene_tree.root.add_child(node)
	return node


func get_scene_tree() -> SceneTree:
	return _scene_tree


func get_failures() -> Array[String]:
	return _failures


func get_assertion_count() -> int:
	return _assertions


func _record_failure(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, msg: String = "") -> void:
	_assertions += 1
	if not condition:
		_record_failure("assert_true failed" + (": " + msg if not msg.is_empty() else ""))


func assert_false(condition: bool, msg: String = "") -> void:
	_assertions += 1
	if condition:
		_record_failure("assert_false failed" + (": " + msg if not msg.is_empty() else ""))


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assertions += 1
	if actual != expected:
		var detail: String = "Expected <%s> but got <%s>" % [str(expected), str(actual)]
		if not msg.is_empty():
			detail += " (%s)" % msg
		_record_failure(detail)


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	_assertions += 1
	if actual == unexpected:
		var detail: String = "Expected value != <%s>" % [str(unexpected)]
		if not msg.is_empty():
			detail += " (%s)" % msg
		_record_failure(detail)


func assert_null(actual: Variant, msg: String = "") -> void:
	_assertions += 1
	if actual != null:
		_record_failure("Expected null but got <%s>%s" % [str(actual), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_not_null(actual: Variant, msg: String = "") -> void:
	_assertions += 1
	if actual == null:
		_record_failure("Expected non-null value%s" % [" (" + msg + ")" if not msg.is_empty() else ""])


func assert_almost_eq(actual: float, expected: float, margin: float = 0.001, msg: String = "") -> void:
	_assertions += 1
	if absf(actual - expected) > margin:
		var detail: String = "Expected ~%f (+/-%f) but got %f" % [expected, margin, actual]
		if not msg.is_empty():
			detail += " (%s)" % msg
		_record_failure(detail)


func assert_gt(actual: float, threshold: float, msg: String = "") -> void:
	_assertions += 1
	if not (actual > threshold):
		_record_failure("Expected %s > %s%s" % [str(actual), str(threshold), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_gte(actual: float, threshold: float, msg: String = "") -> void:
	_assertions += 1
	if not (actual >= threshold):
		_record_failure("Expected %s >= %s%s" % [str(actual), str(threshold), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_lt(actual: float, threshold: float, msg: String = "") -> void:
	_assertions += 1
	if not (actual < threshold):
		_record_failure("Expected %s < %s%s" % [str(actual), str(threshold), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_lte(actual: float, threshold: float, msg: String = "") -> void:
	_assertions += 1
	if not (actual <= threshold):
		_record_failure("Expected %s <= %s%s" % [str(actual), str(threshold), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_has(collection: Variant, item: Variant, msg: String = "") -> void:
	_assertions += 1
	var found: bool = false
	if collection is Array or collection is Dictionary:
		found = collection.has(item)
	if not found:
		_record_failure("Expected collection to contain <%s>%s" % [str(item), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_does_not_have(collection: Variant, item: Variant, msg: String = "") -> void:
	_assertions += 1
	var found: bool = false
	if collection is Array or collection is Dictionary:
		found = collection.has(item)
	if found:
		_record_failure("Expected collection NOT to contain <%s>%s" % [str(item), " (" + msg + ")" if not msg.is_empty() else ""])


func assert_button_reachable(btn: BaseButton, vp_size: Vector2, label: String = "") -> void:
	var tag: String = label if not label.is_empty() else "Button"
	assert_not_null(btn, "%s: exists" % tag)
	if btn == null:
		return
	assert_true(btn.is_visible_in_tree(), "%s: visible_in_tree" % tag)
	assert_false(btn.disabled, "%s: enabled" % tag)
	var rect: Rect2 = btn.get_global_rect()
	assert_true(rect.size.x >= 20.0 and rect.size.y >= 20.0, "%s: size >= 20x20 (got %s)" % [tag, str(rect.size)])
	assert_true(
		rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= vp_size.x + 1.0 and rect.end.y <= vp_size.y + 1.0,
		"%s: rect %s inside viewport %s" % [tag, str(rect), str(vp_size)]
	)
	var anc: Node = btn.get_parent()
	while anc is Control:
		var anc_ctrl: Control = anc as Control
		if anc_ctrl.clip_contents:
			var ar: Rect2 = anc_ctrl.get_global_rect()
			assert_true(
				rect.position.x >= ar.position.x - 1.0 and rect.position.y >= ar.position.y - 1.0 and rect.end.x <= ar.end.x + 1.0 and rect.end.y <= ar.end.y + 1.0,
				"%s: rect %s clipped by %s %s" % [tag, str(rect), anc_ctrl.name, str(ar)]
			)
		anc = anc_ctrl.get_parent()


func push_click_control(ctrl: Control) -> void:
	if _scene_tree == null or _scene_tree.root == null or ctrl == null:
		return
	var click_pos: Vector2 = ctrl.get_global_rect().get_center()
	for pressed_flag: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed_flag
		ev.position = click_pos
		ev.global_position = click_pos
		_scene_tree.root.push_input(ev)
