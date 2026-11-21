class_name DialogueLineDef
extends Resource
## Single scripted dialogue line tied to a stage `dialogue_id` (`res://data/defs/`).

@export var dialogue_id: String = ""
@export var speaker: String = ""
@export_multiline var line: String = ""
@export var portrait: Texture2D
@export var faction_id: int = 0


## Constructs a DialogueLineDef from a dialogue_id and JSON-parsed line dictionary.
static func from_dict(p_dialogue_id: String, d: Dictionary) -> DialogueLineDef:
	var def := DialogueLineDef.new()
	def.dialogue_id = p_dialogue_id
	def.speaker = str(d.get("speaker", ""))
	def.line = str(d.get("line", ""))
	def.faction_id = int(d.get("faction_id", 0))
	return def


## Serializes this DialogueLineDef to a dictionary compatible with DialogueModal.
func to_line_dict() -> Dictionary:
	return {
		"speaker": speaker,
		"line": line,
	}
