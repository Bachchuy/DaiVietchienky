class_name FacilityDef
extends Resource
## Battlefield economy facility definition editable in the Godot Inspector (`res://data/defs/`).

@export_group("Identity")
@export var facility_id: String = ""
@export var type_code: int = 10
@export var display_name: String = ""
@export var icon: Texture2D

@export_group("Yields Per Level")
@export var food_yield_per_level: Array[int] = []
@export var coin_yield_per_level: Array[int] = []
@export var tech_yield_per_level: Array[int] = []
@export var mana_yield_per_level: Array[int] = []

@export_group("Capacity & Limits")
@export var food_cap_bonus_per_level: Array[int] = []
@export_range(0.0, 1.0, 0.05) var rob_protection_multiplier: float = 1.0
@export var max_tech_tier_per_level: Array[int] = []
@export var max_recruit_stack_per_level: Array[int] = []

@export_group("Upgrade Costs")
@export var upgrade_coin_cost: Array[int] = []
@export var upgrade_tech_cost: Array[int] = []


## Returns the 1-based level value from a per-level integer array, or `0` if empty.
static func get_level_value(arr: Array[int], level: int) -> int:
	if arr.is_empty():
		return 0
	var idx: int = clampi(level - 1, 0, arr.size() - 1)
	return arr[idx]


static func _to_int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for item: Variant in raw:
			out.append(int(item))
	return out


## Constructs a FacilityDef from a JSON-parsed facility dictionary.
static func from_dict(d: Dictionary) -> FacilityDef:
	var def := FacilityDef.new()
	def.facility_id = str(d.get("facility_id", d.get("id", "")))
	def.type_code = int(d.get("type_code", d.get("type", 10)))
	def.display_name = str(d.get("display_name", d.get("name", def.facility_id)))
	def.food_yield_per_level = _to_int_array(d.get("food_yield_per_level", []))
	def.coin_yield_per_level = _to_int_array(d.get("coin_yield_per_level", []))
	def.tech_yield_per_level = _to_int_array(d.get("tech_yield_per_level", []))
	def.mana_yield_per_level = _to_int_array(d.get("mana_yield_per_level", []))
	def.food_cap_bonus_per_level = _to_int_array(d.get("food_cap_bonus_per_level", []))
	def.rob_protection_multiplier = float(d.get("rob_protection_multiplier", 1.0))
	def.max_tech_tier_per_level = _to_int_array(d.get("max_tech_tier_per_level", []))
	def.max_recruit_stack_per_level = _to_int_array(d.get("max_recruit_stack_per_level", []))
	def.upgrade_coin_cost = _to_int_array(d.get("upgrade_coin_cost", []))
	def.upgrade_tech_cost = _to_int_array(d.get("upgrade_tech_cost", []))
	return def


## Serializes this FacilityDef to a dictionary matching facility_settings.json structure.
func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id": facility_id,
		"type": type_code,
		"name": display_name,
		"upgrade_coin_cost": Array(upgrade_coin_cost),
		"upgrade_tech_cost": Array(upgrade_tech_cost),
	}
	if not food_yield_per_level.is_empty():
		d["food_yield_per_level"] = Array(food_yield_per_level)
	if not coin_yield_per_level.is_empty():
		d["coin_yield_per_level"] = Array(coin_yield_per_level)
	if not tech_yield_per_level.is_empty():
		d["tech_yield_per_level"] = Array(tech_yield_per_level)
	if not mana_yield_per_level.is_empty():
		d["mana_yield_per_level"] = Array(mana_yield_per_level)
	if not food_cap_bonus_per_level.is_empty():
		d["food_cap_bonus_per_level"] = Array(food_cap_bonus_per_level)
	if not is_equal_approx(rob_protection_multiplier, 1.0):
		d["rob_protection_multiplier"] = rob_protection_multiplier
	if not max_tech_tier_per_level.is_empty():
		d["max_tech_tier_per_level"] = Array(max_tech_tier_per_level)
	if not max_recruit_stack_per_level.is_empty():
		d["max_recruit_stack_per_level"] = Array(max_recruit_stack_per_level)
	return d
