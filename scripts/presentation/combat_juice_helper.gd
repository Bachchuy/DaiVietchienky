class_name CombatJuiceHelper
extends Node

const HIT_FLASH_SHADER_PATH: String = "res://assets_clean/shaders/hit_flash.gdshader"
const POOL_SIZE: int = 16

const VALID_PRESETS: Array[String] = [
	"DustTrailCPU2D",
	"MetalSparksCPU2D",
	"WaterSplashCPU2D",
	"FireEmbersCPU2D",
	"MoraleAuraCPU2D",
	"GunpowderSmokeCPU2D",
]

class PooledParticleCPU2D extends CPUParticles2D:
	var amount_ratio: float = 1.0:
		set(value):
			amount_ratio = clampf(value, 0.05, 1.0)
			amount = maxi(1, int(round(16.0 * amount_ratio)))


var reduce_flashing: bool = false:
	set(value):
		reduce_flashing = value
		_recent_flash_timestamps_ms.clear()
var vfx_quality: String = "High"

var _map_view: BattleMap = null
var _camera: BattleCameraController = null
var _shared_hit_flash_material: ShaderMaterial = null
var _particle_pool: Array[PooledParticleCPU2D] = []
var _pool_cursor: int = 0
var _active_tweens: Dictionary = {}
var _recent_flash_timestamps_ms: Array[int] = []


func _ready() -> void:
	_init_shared_shader_material()


func setup(map_view: BattleMap, camera: BattleCameraController = null) -> void:
	_map_view = map_view
	_camera = camera
	_init_shared_shader_material()
	_prewarm_particle_pool()


func _init_shared_shader_material() -> void:
	if _shared_hit_flash_material != null:
		return
	_shared_hit_flash_material = ShaderMaterial.new()
	if ResourceLoader.exists(HIT_FLASH_SHADER_PATH):
		var sh: Shader = load(HIT_FLASH_SHADER_PATH) as Shader
		if sh != null:
			_shared_hit_flash_material.shader = sh
			_shared_hit_flash_material.set_shader_parameter("flash_modifier", 1.0)
			_shared_hit_flash_material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))


func _prewarm_particle_pool() -> void:
	if _map_view == null:
		return
	var effect_layer: Node2D = _map_view.get_layer_node("MapEffectLayer")
	if effect_layer == null:
		return
	_particle_pool.clear()
	for child: Node in effect_layer.get_children():
		if child is PooledParticleCPU2D:
			_particle_pool.append(child as PooledParticleCPU2D)

	while _particle_pool.size() < POOL_SIZE:
		var cpu := PooledParticleCPU2D.new()
		cpu.name = "PooledParticleCPU2D_%02d" % _particle_pool.size()
		cpu.emitting = false
		cpu.one_shot = true
		cpu.amount = 16
		cpu.lifetime = 0.35
		cpu.explosiveness = 0.85
		cpu.spread = 180.0
		cpu.gravity = Vector2(0.0, 40.0)
		cpu.initial_velocity_min = 24.0
		cpu.initial_velocity_max = 68.0
		cpu.scale_amount_min = 2.0
		cpu.scale_amount_max = 4.0
		cpu.amount_ratio = _get_quality_amount_ratio()
		effect_layer.add_child(cpu)
		_particle_pool.append(cpu)


func set_vfx_quality(quality: Variant) -> void:
	if quality is int:
		match int(quality):
			0:
				vfx_quality = "Low"
			1:
				vfx_quality = "Medium"
			_:
				vfx_quality = "High"
	else:
		var q_str: String = str(quality).strip_edges().to_lower()
		if q_str.begins_with("low") or q_str == "0":
			vfx_quality = "Low"
		elif q_str.begins_with("med") or q_str == "1":
			vfx_quality = "Medium"
		else:
			vfx_quality = "High"

	var ratio: float = _get_quality_amount_ratio()
	for cpu: PooledParticleCPU2D in _particle_pool:
		if is_instance_valid(cpu):
			cpu.amount_ratio = ratio


func _get_quality_amount_ratio() -> float:
	match vfx_quality:
		"Low":
			return 0.4
		"Medium":
			return 0.75
		_:
			return 1.0


func trigger_hit_flash(target: CanvasItem, _is_crit: bool = false) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	_init_shared_shader_material()

	var now_ms: int = Time.get_ticks_msec()
	var kept: Array[int] = []
	for ts: int in _recent_flash_timestamps_ms:
		if now_ms - ts < 1000:
			kept.append(ts)
	_recent_flash_timestamps_ms = kept

	var target_id: int = target.get_instance_id()
	if reduce_flashing:
		# WCAG 2.3.1 rate cap: strictly < 3 flashes per second (max 2 within 1000ms window)
		if _recent_flash_timestamps_ms.size() >= 2:
			target.material = null
			return false
		_recent_flash_timestamps_ms.append(now_ms)
		target.material = null
		var orig_a: float = target.self_modulate.a
		target.self_modulate = Color(1.0, 0.55, 0.55, orig_a)
		if get_tree() != null:
			get_tree().create_timer(0.06, true, false, true).timeout.connect(func() -> void:
				var inst: Object = instance_from_id(target_id)
				if inst is CanvasItem and is_instance_valid(inst):
					(inst as CanvasItem).self_modulate = Color(1.0, 1.0, 1.0, orig_a)
			)
		return true

	if vfx_quality == "Low":
		target.material = null
		return true

	_recent_flash_timestamps_ms.append(now_ms)
	target.material = _shared_hit_flash_material
	if get_tree() != null:
		get_tree().create_timer(0.05, true, false, true).timeout.connect(func() -> void:
			var inst2: Object = instance_from_id(target_id)
			if inst2 is CanvasItem and is_instance_valid(inst2):
				(inst2 as CanvasItem).material = null
		)
	return true


func play_local_hit_stop(visual_nodes: Array, duration_sec: float = 0.08) -> void:
	# Strictly local hit-stop: NEVER set Engine.time_scale = 0.0
	var clamped_dur: float = clampf(duration_sec, 0.0, 0.15)
	var node_ids: Array[int] = []
	for node_var: Variant in visual_nodes:
		if node_var is Object and is_instance_valid(node_var):
			var obj: Object = node_var as Object
			node_ids.append(obj.get_instance_id())
			if "speed_scale" in obj:
				obj.set("speed_scale", 0.0)

	if clamped_dur <= 0.0 or get_tree() == null:
		for nid: int in node_ids:
			var obj2: Object = instance_from_id(nid)
			if obj2 != null and is_instance_valid(obj2) and ("speed_scale" in obj2):
				obj2.set("speed_scale", 1.0)
		return

	get_tree().create_timer(clamped_dur, true, false, true).timeout.connect(func() -> void:
		for nid2: int in node_ids:
			var obj3: Object = instance_from_id(nid2)
			if obj3 != null and is_instance_valid(obj3) and ("speed_scale" in obj3):
				obj3.set("speed_scale", 1.0)
	)


func classify_impact_tier(is_crit: bool, is_staked_water: bool, damage: int) -> Dictionary:
	if is_crit or is_staked_water or damage >= 120:
		return {
			"tier": "heavy",
			"hit_stop_sec": 0.12,
			"trauma": 0.80,
		}
	elif damage >= 35:
		return {
			"tier": "medium",
			"hit_stop_sec": 0.05,
			"trauma": 0.35,
		}
	return {
		"tier": "small",
		"hit_stop_sec": 0.0,
		"trauma": 0.0,
	}


func play_squash_stretch(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var iid: int = target.get_instance_id()
	if _active_tweens.has(iid):
		var old_tw: Variant = _active_tweens[iid]
		if old_tw is Tween and (old_tw as Tween).is_valid():
			(old_tw as Tween).kill()
		_active_tweens.erase(iid)

	target.scale = Vector2(1.22, 0.78)
	if get_tree() == null:
		return
	var tw: Tween = target.create_tween()
	_active_tweens[iid] = tw
	tw.tween_property(target, "scale", Vector2(0.94, 1.06), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		_active_tweens.erase(iid)
		var inst: Object = instance_from_id(iid)
		if inst is Node2D and is_instance_valid(inst):
			(inst as Node2D).scale = Vector2.ONE
	)


func spawn_floating_text(
	parent_layer: Node,
	world_pos: Vector2,
	damage: int,
	kind: StringName = &"normal"
) -> Label:
	var target_parent: Node = parent_layer
	if target_parent == null and _map_view != null:
		target_parent = _map_view.get_layer_node("WorldSpaceUnitHudAndTextLayer")
	var lbl := Label.new()
	lbl.position = world_pos + Vector2(-28.0, -34.0)
	var k_str: String = str(kind).to_lower()
	if k_str == "crit":
		lbl.text = "💥 -%d!" % maxi(1, damage)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
		lbl.add_theme_font_size_override("font_size", 15)
	elif k_str == "blocked" or damage <= 0:
		lbl.text = "🛡️ 0"
		lbl.add_theme_color_override("font_color", Color(0.76, 0.88, 1.0))
		lbl.add_theme_font_size_override("font_size", 13)
	elif k_str == "trap":
		lbl.text = "⚠️ -%d!" % maxi(1, damage)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.36, 0.30))
		lbl.add_theme_font_size_override("font_size", 15)
	else:
		lbl.text = "⚔️ -%d" % maxi(1, damage)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.88))
		lbl.add_theme_font_size_override("font_size", 13)

	if target_parent != null:
		target_parent.add_child(lbl)

	if lbl.is_inside_tree():
		var lbl_id: int = lbl.get_instance_id()
		var tw: Tween = lbl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -24.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.55)
		tw.chain().tween_callback(func() -> void:
			var inst: Object = instance_from_id(lbl_id)
			if inst is Node and is_instance_valid(inst):
				(inst as Node).queue_free()
		)
	return lbl


func spawn_particle_preset(
	preset_id: String,
	world_pos: Vector2,
	era: String = "Tran_Nguyen"
) -> bool:
	if not VALID_PRESETS.has(preset_id):
		return false

	var era_low: String = era.to_lower()
	if preset_id == "GunpowderSmokeCPU2D":
		if era_low.contains("tran") or era_low.contains("1288") or era_low.contains("ly"):
			return false

	if _particle_pool.is_empty():
		_prewarm_particle_pool()
	if _particle_pool.is_empty():
		return false

	var cpu: PooledParticleCPU2D = _particle_pool[_pool_cursor % _particle_pool.size()]
	_pool_cursor = (_pool_cursor + 1) % _particle_pool.size()
	if not is_instance_valid(cpu):
		return false

	cpu.position = world_pos
	cpu.amount_ratio = _get_quality_amount_ratio()
	match preset_id:
		"DustTrailCPU2D":
			cpu.color = Color(0.76, 0.68, 0.52, 0.80)
			cpu.gravity = Vector2(0.0, -12.0)
		"MetalSparksCPU2D":
			cpu.color = Color(1.0, 0.84, 0.32, 0.95)
			cpu.gravity = Vector2(0.0, 80.0)
		"WaterSplashCPU2D":
			cpu.color = Color(0.56, 0.84, 0.98, 0.90)
			cpu.gravity = Vector2(0.0, 95.0)
		"FireEmbersCPU2D":
			cpu.color = Color(1.0, 0.44, 0.16, 0.92)
			cpu.gravity = Vector2(0.0, -45.0)
		"MoraleAuraCPU2D":
			cpu.color = Color(1.0, 0.92, 0.42, 0.88)
			cpu.gravity = Vector2(0.0, -35.0)
		"GunpowderSmokeCPU2D":
			cpu.color = Color(0.42, 0.42, 0.44, 0.85)
			cpu.gravity = Vector2(0.0, -20.0)

	cpu.emitting = false
	cpu.restart()
	cpu.emitting = true
	return true
