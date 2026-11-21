class_name NamedAreaDef
extends Resource
## Named map region (objective dock, ambush zone, pass) editable in Godot Inspector (`res://data/defs/`).

@export var area_id: String = ""
@export var display_name: String = ""
@export var hexes: Array[Vector2i] = []
@export var initial_owner: int = 0
@export var is_objective: bool = false


## Constructs a NamedAreaDef from a JSON-parsed area dictionary.
static func from_dict(d: Dictionary) -> NamedAreaDef:
	var def := NamedAreaDef.new()
	def.area_id = str(d.get("area_id", ""))
	def.display_name = str(d.get("display_name", d.get("name", def.area_id)))
	def.initial_owner = int(d.get("initial_owner", 0))
	def.is_objective = bool(d.get("is_objective", false))

	var parsed_hexes: Array[Vector2i] = []
	var raw_hexes: Variant = d.get("hexes", [])
	if raw_hexes is Array:
		for h_var: Variant in raw_hexes:
			if h_var is Dictionary:
				var hd: Dictionary = h_var as Dictionary
				parsed_hexes.append(Vector2i(int(hd.get("q", hd.get("col", 0))), int(hd.get("r", hd.get("row", 0)))))
			elif h_var is Vector2i:
				parsed_hexes.append(h_var as Vector2i)
	def.hexes = parsed_hexes
	return def


## Serializes this NamedAreaDef to a dictionary matching battle JSON `areas` entries.
func to_dict() -> Dictionary:
	var hex_dicts: Array[Dictionary] = []
	for h: Vector2i in hexes:
		hex_dicts.append({"q": h.x, "r": h.y})
	return {
		"area_id": area_id,
		"name": display_name,
		"hexes": hex_dicts,
		"initial_owner": initial_owner,
		"is_objective": is_objective,
	}
