class_name SeededRng
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(initial_seed: int = 1) -> void:
	_rng.seed = initial_seed


func get_seed() -> int:
	return _rng.seed


func get_state() -> int:
	return _rng.state


func restore(seed_val: int, state_val: int) -> void:
	_rng.seed = seed_val
	_rng.state = state_val


func clone() -> SeededRng:
	var copy := SeededRng.new(_rng.seed)
	copy.restore(_rng.seed, _rng.state)
	return copy


func roll_float_range(min_val: float, max_val: float) -> float:
	return _rng.randf_range(min_val, max_val)


func roll_int_range(min_val: int, max_val: int) -> int:
	return _rng.randi_range(min_val, max_val)


func to_dict() -> Dictionary:
	return {
		"rng_seed": str(_rng.seed),
		"rng_state": str(_rng.state),
	}


func from_dict(data: Dictionary) -> void:
	var s_val: int = int(str(data.get("rng_seed", "1")))
	var st_val: int = int(str(data.get("rng_state", "0")))
	_rng.seed = s_val
	if data.has("rng_state"):
		_rng.state = st_val
