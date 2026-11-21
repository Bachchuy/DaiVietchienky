class_name CodexEntryDef
extends Resource
## Historical codex or gameplay mechanics transparency entry (`res://data/defs/`).

@export_group("Identity")
@export var entry_id: String = ""
@export var title: String = ""
@export var era: String = ""
@export_enum("historical", "mechanics") var category: String = "historical"

@export_group("Historical Integrity")
## Use `"A"`–`"D"` for historical entries; leave `""` for mechanics or benchmark references.
@export var evidence_grade: String = ""
@export_enum("historical_claim", "fixture", "abstraction", "what_if") var modeling_type: String = "historical_claim"
@export_multiline var source_ref: String = ""

@export_group("Content")
@export_multiline var summary: String = ""


## Returns true if the search query matches this entry (empty query always matches).
func matches_query(query: String) -> bool:
	var q: String = query.strip_edges().to_lower()
	if q.is_empty():
		return true
	var haystack: String = (
		entry_id + " " + title + " " + era + " " + source_ref + " " + summary
	).to_lower()
	return haystack.contains(q)


## Constructs a CodexEntryDef from a JSON-parsed codex dictionary.
static func from_dict(d: Dictionary) -> CodexEntryDef:
	var def := CodexEntryDef.new()
	def.entry_id = str(d.get("entry_id", d.get("id", "")))
	def.title = str(d.get("title", ""))
	def.era = str(d.get("era", ""))
	def.category = str(d.get("category", "historical"))
	def.evidence_grade = str(d.get("evidence_grade", ""))
	def.modeling_type = str(d.get("modeling_type", "historical_claim"))
	def.source_ref = str(d.get("source_ref", ""))
	def.summary = str(d.get("summary", ""))
	return def


## Serializes this CodexEntryDef to a dictionary matching codex_entries.json structure.
func to_dict() -> Dictionary:
	return {
		"id": entry_id,
		"title": title,
		"era": era,
		"category": category,
		"evidence_grade": evidence_grade,
		"modeling_type": modeling_type,
		"source_ref": source_ref,
		"summary": summary,
	}
