class_name GdTestCase
extends RefCounted

var _failures: Array[String] = []
var _assertions: int = 0
var _autofree_nodes: Array[Node] = []
var _scene_tree: SceneTree = null


func setup_context(tree: SceneTree) -> void:
	_scene_tree = tree
	_failures.clear()
	_assertions = 0
	_autofree_nodes.clear()


func before_each() -> void:
	pass


func after_each() -> void:
	for i: int in range(_autofree_nodes.size() - 1, -1, -1):
		var node: Node = _autofree_nodes[i]
		if is_instance_valid(node):
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
