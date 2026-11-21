extends "res://tests/test_case.gd"

const HEX_MATH_PATH: String = "res://sim/rules/hex_math.gd"


func _load_hex_math() -> GDScript:
	var script: GDScript = load(HEX_MATH_PATH) as GDScript
	assert_not_null(script, "HexMath script must exist at " + HEX_MATH_PATH)
	return script


func test_odd_r_axial_roundtrip_12x10_and_30x30() -> void:
	var hex_math: GDScript = _load_hex_math()
	if hex_math == null:
		return

	# Check explicit known values from GDD formula
	assert_eq(hex_math.odd_r_to_axial(Vector2i(0, 0)), Vector2i(0, 0), "Origin (0,0)")
	assert_eq(hex_math.odd_r_to_axial(Vector2i(2, 8)), Vector2i(-2, 8), "SignalDock odd-r (2,8) -> axial (-2,8)")
	assert_eq(hex_math.axial_to_odd_r(Vector2i(-2, 8)), Vector2i(2, 8), "SignalDock axial -> odd-r")

	# Full 30x30 stress grid + negative offset coordinates round-trip
	for row: int in range(-4, 30):
		for col: int in range(-4, 30):
			var offset := Vector2i(col, row)
			var axial: Vector2i = hex_math.odd_r_to_axial(offset)
			var back: Vector2i = hex_math.axial_to_odd_r(axial)
			assert_eq(back, offset, "Round-trip failed at offset %s" % str(offset))


func test_hex_distance_and_opposite_directions() -> void:
	var hex_math: GDScript = _load_hex_math()
	if hex_math == null:
		return

	assert_eq(hex_math.hex_distance(Vector2i(3, -2), Vector2i(3, -2)), 0)
	assert_eq(hex_math.hex_distance(Vector2i(0, 0), Vector2i(3, -1)), 3)
	assert_eq(hex_math.hex_distance(Vector2i(3, -1), Vector2i(0, 0)), 3)
	assert_eq(hex_math.hex_distance(Vector2i(-2, 8), Vector2i(2, 5)), 4)

	var dirs: Array[Vector2i] = hex_math.AXIAL_DIRECTIONS
	assert_eq(dirs.size(), 6, "Must have 6 axial directions")
	for d: int in range(6):
		var step: Vector2i = dirs[d]
		assert_eq(hex_math.hex_distance(Vector2i.ZERO, step), 1, "Neighbor distance must be 1")
		var opp_idx: int = hex_math.opposite_direction_index(d)
		assert_eq(opp_idx, (d + 3) % 6)
		assert_eq(step + dirs[opp_idx], Vector2i.ZERO, "Opposite direction must sum to zero for pincer check")

	var neighbors: Array[Vector2i] = hex_math.get_neighbors(Vector2i(2, 3))
	assert_eq(neighbors.size(), 6)
	for nb: Vector2i in neighbors:
		assert_eq(hex_math.hex_distance(Vector2i(2, 3), nb), 1)


func test_hex_linedraw_continuity_and_determinism() -> void:
	var hex_math: GDScript = _load_hex_math()
	if hex_math == null:
		return

	var single: Array[Vector2i] = hex_math.hex_linedraw(Vector2i(4, 4), Vector2i(4, 4))
	assert_eq(single.size(), 1)
	assert_eq(single[0], Vector2i(4, 4))

	var a := Vector2i(0, 0)
	var b := Vector2i(4, 2)
	var line1: Array[Vector2i] = hex_math.hex_linedraw(a, b)
	var line2: Array[Vector2i] = hex_math.hex_linedraw(a, b)
	assert_eq(line1, line2, "hex_linedraw must be 100% deterministic")
	assert_eq(line1.size(), hex_math.hex_distance(a, b) + 1)
	assert_eq(line1[0], a)
	assert_eq(line1[line1.size() - 1], b)
	for i: int in range(line1.size() - 1):
		assert_eq(hex_math.hex_distance(line1[i], line1[i + 1]), 1, "Adjacent line steps must touch")


func test_pointy_top_world_pixel_conversions_and_bounds() -> void:
	var hex_math: GDScript = _load_hex_math()
	if hex_math == null:
		return

	var hex_size: float = 48.0
	var corners: PackedVector2Array = hex_math.get_hex_corners(Vector2.ZERO, hex_size)
	assert_eq(corners.size(), 6)
	# Pointy-topped hex must have top/bottom vertices aligned on X = 0 with |Y| = hex_size
	var has_top_peak: bool = false
	var has_bottom_peak: bool = false
	for c: Vector2 in corners:
		if absf(c.x) < 0.01 and absf(c.y + hex_size) < 0.01:
			has_top_peak = true
		if absf(c.x) < 0.01 and absf(c.y - hex_size) < 0.01:
			has_bottom_peak = true
	assert_true(has_top_peak, "Pointy-topped hex must have top vertex at (0, -size)")
	assert_true(has_bottom_peak, "Pointy-topped hex must have bottom vertex at (0, +size)")

	# Verify pixel <-> axial round-trip across 30x30 map including interior jitter
	var jitter_offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(10.0, -8.0),
		Vector2(-12.0, 9.0),
		Vector2(0.0, 20.0),
	]
	for row: int in range(30):
		for col: int in range(30):
			var axial: Vector2i = hex_math.odd_r_to_axial(Vector2i(col, row))
			var center: Vector2 = hex_math.axial_to_world(axial, hex_size)
			for jitter: Vector2 in jitter_offsets:
				var picked: Vector2i = hex_math.world_to_axial(center + jitter, hex_size)
				assert_eq(picked, axial, "Pixel picking mismatch at %s" % str(axial))

	var bounds_12x10: Rect2 = hex_math.compute_map_world_bounds(12, 10, hex_size)
	assert_gt(bounds_12x10.size.x, 950.0)
	assert_gt(bounds_12x10.size.y, 700.0)
