class_name HexMath
extends RefCounted

const DEFAULT_HEX_SIZE: float = 48.0
const SQRT_3: float = 1.7320508075688772

## Clockwise neighbors around Pointy-topped Axial (q, r); opposite direction is (d + 3) % 6.
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

## Deterministic epsilon nudge to prevent exact edge-grazing ties in LOS linedraw.
const LOS_NUDGE: Vector3 = Vector3(0.000001, 0.000002, -0.000003)


static func odd_r_to_axial(offset: Vector2i) -> Vector2i:
	var parity: int = offset.y & 1
	@warning_ignore("integer_division")
	var q: int = offset.x - ((offset.y - parity) / 2)
	return Vector2i(q, offset.y)


static func axial_to_odd_r(axial: Vector2i) -> Vector2i:
	var parity: int = axial.y & 1
	@warning_ignore("integer_division")
	var col: int = axial.x + ((axial.y - parity) / 2)
	return Vector2i(col, axial.y)


static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = absi(a.x - b.x)
	var dr: int = absi(a.y - b.y)
	var ds: int = absi((a.x + a.y) - (b.x + b.y))
	@warning_ignore("integer_division")
	return (dq + dr + ds) / 2


static func opposite_direction_index(dir_idx: int) -> int:
	return (posmod(dir_idx, 6) + 3) % 6


static func get_neighbors(axial: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: Vector2i in AXIAL_DIRECTIONS:
		out.append(axial + dir)
	return out


static func hex_linedraw(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n: int = hex_distance(a, b)
	if n == 0:
		return [a]

	var ac: Vector3 = Vector3(float(a.x), float(-a.x - a.y), float(a.y)) + LOS_NUDGE
	var bc: Vector3 = Vector3(float(b.x), float(-b.x - b.y), float(b.y)) + LOS_NUDGE
	var results: Array[Vector2i] = []

	for i: int in range(n + 1):
		var t: float = float(i) / float(n)
		results.append(cube_round(ac.lerp(bc, t)))
	return results


static func cube_round(frac: Vector3) -> Vector2i:
	var rx: float = roundf(frac.x)
	var ry: float = roundf(frac.y)
	var rz: float = roundf(frac.z)

	var x_diff: float = absf(rx - frac.x)
	var y_diff: float = absf(ry - frac.y)
	var z_diff: float = absf(rz - frac.z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


static func axial_to_world(axial: Vector2i, hex_size: float = DEFAULT_HEX_SIZE) -> Vector2:
	var x: float = hex_size * SQRT_3 * (float(axial.x) + 0.5 * float(axial.y))
	var y: float = hex_size * 1.5 * float(axial.y)
	return Vector2(x, y)


static func world_to_axial(world_pos: Vector2, hex_size: float = DEFAULT_HEX_SIZE) -> Vector2i:
	var safe_size: float = maxf(hex_size, 0.0001)
	var frac_q: float = ((SQRT_3 / 3.0) * world_pos.x - (1.0 / 3.0) * world_pos.y) / safe_size
	var frac_r: float = ((2.0 / 3.0) * world_pos.y) / safe_size
	return cube_round(Vector3(frac_q, -frac_q - frac_r, frac_r))


static func get_hex_corners(center: Vector2, hex_size: float = DEFAULT_HEX_SIZE) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(6)
	for i: int in range(6):
		var angle_rad: float = deg_to_rad(60.0 * float(i) - 30.0)
		pts[i] = center + Vector2(cos(angle_rad), sin(angle_rad)) * hex_size
	return pts


static func compute_map_world_bounds(
	cols: int,
	rows: int,
	hex_size: float = DEFAULT_HEX_SIZE,
	margin: float = 24.0
) -> Rect2:
	if cols <= 0 or rows <= 0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var half_w: float = hex_size * SQRT_3 * 0.5
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF

	for row: int in range(rows):
		for col: int in [0, cols - 1]:
			var c: Vector2 = axial_to_world(odd_r_to_axial(Vector2i(col, row)), hex_size)
			min_x = minf(min_x, c.x - half_w)
			max_x = maxf(max_x, c.x + half_w)
			min_y = minf(min_y, c.y - hex_size)
			max_y = maxf(max_y, c.y + hex_size)

	var top_left := Vector2(min_x - margin, min_y - margin)
	var size := Vector2((max_x - min_x) + margin * 2.0, (max_y - min_y) + margin * 2.0)
	return Rect2(top_left, size)
