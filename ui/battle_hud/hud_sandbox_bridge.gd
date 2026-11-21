class_name HudSandboxBridge
extends RefCounted

## Bridges BattleHud actions cleanly to sandbox presentation helpers (VFX, audio, camera, stage reload).


static func trigger_method(sandbox: Node, method_name: String) -> void:
	if sandbox != null and sandbox.has_method(method_name):
		sandbox.call(method_name)


static func apply_accessibility(
	sandbox: Node,
	camera: BattleCameraController,
	reduce_flashing: bool,
	vfx_quality_index: int,
	shake_scale: float
) -> void:
	if camera != null:
		camera.shake_user_scale = shake_scale
	if sandbox != null and sandbox.has_method("get_juice_helper"):
		var jh: Variant = sandbox.call("get_juice_helper")
		if jh is Object:
			(jh as Object).set("reduce_flashing", reduce_flashing)
			if (jh as Object).has_method("set_vfx_quality"):
				(jh as Object).call("set_vfx_quality", vfx_quality_index)


static func apply_bus_volume(sandbox: Node, bus_name: String, linear_val: float) -> void:
	if sandbox != null and sandbox.has_method("get_audio_manager"):
		var am: Variant = sandbox.call("get_audio_manager")
		if am is Object and (am as Object).has_method("set_bus_linear_volume"):
			(am as Object).call("set_bus_linear_volume", bus_name, linear_val)


static func focus_camera_on_hex(
	camera: BattleCameraController,
	map_view: BattleMapView,
	target_hex: Vector2i
) -> void:
	if camera == null or map_view == null:
		return
	var was_locked: bool = camera.camera_locked
	camera.camera_locked = false
	camera.pan_to_world_pos(HexMath.axial_to_world(target_hex, map_view.hex_size), true)
	camera.camera_locked = was_locked
