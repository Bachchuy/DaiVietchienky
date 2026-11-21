class_name UnitView
extends Node2D
## Component-based unit visual presentation bound read-only from BattleUnit & TroopDef.

const FACTION_TINT_SHADER_PATH: String = "res://assets_clean/hexcrown/shaders/faction_tint.gdshader"
const DEFAULT_SPRITE_PATH: String = "res://assets_clean/hexcrown/units/mini_spear_man.png"
const TROOP_SPRITE_PATHS: Dictionary[int, String] = {
	40101: "res://assets_clean/hexcrown/units/mini_spear_man.png",
	40102: "res://assets_clean/hexcrown/units/mini_crossbow_man.png",
	40103: "res://assets_clean/hexcrown/units/mini_horse_man.png",
	40104: "res://assets_clean/hexcrown/units/mini_shield_man.png",
	40105: "res://assets_clean/hexcrown/units/mini_prince_man.png",
	40106: "res://assets_clean/hexcrown/units/mini_halberd_man.png",
	40201: "res://assets_clean/hexcrown/units/mini_sword_man.png",
	40202: "res://assets_clean/hexcrown/units/mini_arch_mage.png",
	40901: "res://assets_clean/hexcrown/units/mini_archer_man.png",
	40902: "res://assets_clean/hexcrown/units/mini_king_man.png",
	40903: "res://assets_clean/hexcrown/units/mini_cavalier_man.png",
	40904: "res://assets_clean/hexcrown/units/mini_mage.png",
}
const BRANCH_TOKEN_PATHS: Dictionary[int, String] = {
	0: "res://assets_clean/icons/token_infantry.svg",
	1: "res://assets_clean/icons/token_archer.svg",
	2: "res://assets_clean/icons/token_cavalry.svg",
	3: "res://assets_clean/icons/token_cavalry.svg",
	4: "res://assets_clean/icons/token_naval.svg",
	5: "res://assets_clean/icons/token_naval.svg",
}

@export_group("Components")
@export var sprite: Sprite2D
@export var strategic_token: Sprite2D
@export var anim_player: AnimationPlayer
@export var animator: UnitAnimatorComponent
@export var health_bar: HealthBarComponent
@export var status_badges: StatusBadgeComponent

@export_group("Faction Palette")
@export var dai_viet_tint: Color = Color(0.86, 0.18, 0.16, 1.0)
@export var dai_nguyen_tint: Color = Color(0.20, 0.42, 0.88, 1.0)
@export var ally_tint: Color = Color(0.20, 0.72, 0.42, 1.0)
@export var neutral_tint: Color = Color(0.62, 0.62, 0.64, 1.0)

var _unit_id: int = 0
var _faction_id: int = 1
var _troop_id: int = 0
var _strategic_lod: bool = false
var _shader_mat: ShaderMaterial = null


func _ready() -> void:
	_resolve_nodes()
	_ensure_unique_shader_material()


func _resolve_nodes() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if strategic_token == null:
		strategic_token = get_node_or_null("StrategicToken") as Sprite2D
	if anim_player == null:
		anim_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animator == null:
		animator = get_node_or_null("UnitAnimatorComponent") as UnitAnimatorComponent
	if health_bar == null:
		health_bar = get_node_or_null("HealthBarComponent") as HealthBarComponent
	if status_badges == null:
		status_badges = get_node_or_null("StatusBadgeComponent") as StatusBadgeComponent


func _ensure_unique_shader_material() -> ShaderMaterial:
	_resolve_nodes()
	if sprite == null:
		return null
	if _shader_mat != null and sprite.material == _shader_mat:
		return _shader_mat

	if sprite.material is ShaderMaterial:
		_shader_mat = (sprite.material as ShaderMaterial).duplicate(true) as ShaderMaterial
	else:
		_shader_mat = ShaderMaterial.new()
		if ResourceLoader.exists(FACTION_TINT_SHADER_PATH):
			_shader_mat.shader = ResourceLoader.load(FACTION_TINT_SHADER_PATH) as Shader
	sprite.material = _shader_mat
	return _shader_mat


## Resolves a unit sprite sheet texture from TroopDef.sprite_sheet or canonical troop_id mapping.
static func resolve_sprite_texture(troop_id: int, troop_def: TroopDef = null) -> Texture2D:
	if troop_def != null and troop_def.sprite_sheet != null:
		return troop_def.sprite_sheet
	var path: String = str(TROOP_SPRITE_PATHS.get(troop_id, DEFAULT_SPRITE_PATH))
	return ResourceLoader.load(path) as Texture2D


## Resolves the simplified strategic zoom token texture for a unit command branch.
static func resolve_token_texture(command_branch: int) -> Texture2D:
	var path: String = str(BRANCH_TOKEN_PATHS.get(command_branch, "res://assets_clean/icons/token_infantry.svg"))
	return ResourceLoader.load(path) as Texture2D


## Returns the configured tint color for a given faction_id.
func get_faction_color(faction_id: int) -> Color:
	match faction_id:
		1:
			return dai_viet_tint
		2:
			return dai_nguyen_tint
		3:
			return ally_tint
		_:
			return neutral_tint


## Binds this UnitView to a BattleUnit and optional TroopDef, configuring sprite, shader, and animations.
func bind_unit(unit: BattleUnit, troop_def: TroopDef = null) -> void:
	if unit == null:
		return
	_resolve_nodes()
	_unit_id = unit.unit_id
	_faction_id = unit.faction_id
	_troop_id = unit.troop_id

	var tex: Texture2D = resolve_sprite_texture(unit.troop_id, troop_def)
	if animator != null and tex != null:
		animator.reset_alive()
		animator.setup_sprite_texture(tex)
	elif sprite != null and tex != null:
		sprite.texture = tex

	if strategic_token != null:
		strategic_token.texture = resolve_token_texture(int(unit.command_branch))

	var tint: Color = get_faction_color(unit.faction_id)
	var mat: ShaderMaterial = _ensure_unique_shader_material()
	if mat != null:
		mat.set_shader_parameter("target_color", tint)
		mat.set_shader_parameter("swap_amount", 1.0)
	if strategic_token != null:
		strategic_token.modulate = tint
	if health_bar != null:
		health_bar.set_faction_accent(tint)
	if status_badges != null:
		status_badges.visible = true

	sync_from_unit(unit)


## Refreshes health bar, status badges, facing, acted dim, invisibility, and death state from BattleUnit.
func sync_from_unit(unit: BattleUnit) -> void:
	if unit == null or unit.state == null:
		return
	_resolve_nodes()
	if health_bar != null:
		health_bar.set_health(
			unit.state.current_hp,
			unit.state.max_hp,
			unit.get_active_banners(),
			unit.get_effective_stack()
		)
	if status_badges != null:
		status_badges.sync_from_unit(unit)
	if animator != null:
		animator.set_facing_left(unit.facing in [2, 3, 4])

	var base_alpha: float = 0.52 if unit.state.is_invisible else 1.0
	var acted_tone: float = 0.70 if unit.state.has_acted else 1.0
	if sprite != null:
		sprite.modulate = Color(acted_tone, acted_tone, acted_tone, base_alpha)
	if strategic_token != null:
		var tint: Color = get_faction_color(_faction_id)
		strategic_token.modulate = Color(tint.r * acted_tone, tint.g * acted_tone, tint.b * acted_tone, base_alpha)

	if not unit.state.is_alive():
		play_death()


## Sets selection outline highlight state on this unit's unique shader material.
func set_selected(selected: bool) -> void:
	var mat: ShaderMaterial = _ensure_unique_shader_material()
	if mat != null:
		mat.set_shader_parameter("is_selected", 1.0 if selected else 0.0)


## Sets attack target red outline highlight state on this unit's unique shader material.
func set_attack_target(targeted: bool) -> void:
	var mat: ShaderMaterial = _ensure_unique_shader_material()
	if mat != null:
		mat.set_shader_parameter("is_attack_target", 1.0 if targeted else 0.0)


## Sets heal/support green outline highlight state on this unit's unique shader material.
func set_heal_target(targeted: bool) -> void:
	var mat: ShaderMaterial = _ensure_unique_shader_material()
	if mat != null:
		mat.set_shader_parameter("is_heal_target", 1.0 if targeted else 0.0)


## Switches between detailed pixel sprite mode and zoomed-out strategic token LOD mode.
func set_strategic_lod(enabled: bool) -> void:
	_resolve_nodes()
	_strategic_lod = enabled
	if sprite != null:
		sprite.visible = not enabled
	if strategic_token != null:
		strategic_token.visible = enabled


## Animates unit movement toward a world position and returns the Tween (or null if outside tree).
func play_move_to(target_world_pos: Vector2, duration: float = 0.22) -> Tween:
	_resolve_nodes()
	if animator != null:
		animator.set_facing_left(target_world_pos.x < position.x)
		animator.play_anim("walk")
	if not is_inside_tree():
		position = target_world_pos
		if animator != null:
			animator.play_anim("idle")
		return null
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_world_pos, maxf(0.01, duration))
	tween.finished.connect(func() -> void:
		if is_instance_valid(animator):
			animator.play_anim("idle")
	)
	return tween


## Plays attack animation facing the target world coordinate.
func play_attack(target_world_pos: Vector2) -> void:
	_resolve_nodes()
	if animator != null:
		animator.set_facing_left(target_world_pos.x < position.x)
		animator.play_anim("attack", true)


## Plays hurt animation clip.
func play_hurt() -> void:
	_resolve_nodes()
	if animator != null:
		animator.play_anim("hurt", true)


## Plays death animation clip and hides status/health overlays.
func play_death() -> void:
	_resolve_nodes()
	if health_bar != null:
		health_bar.visible = false
	if status_badges != null:
		status_badges.visible = false
	if animator != null:
		animator.play_anim("death", true)


func get_unit_id() -> int:
	return _unit_id


func get_faction_id() -> int:
	return _faction_id


func get_troop_id() -> int:
	return _troop_id


func get_shader_material() -> ShaderMaterial:
	return _ensure_unique_shader_material()


func is_strategic_lod() -> bool:
	return _strategic_lod
