class_name RecipeDef
extends RefCounted
## Rezeptdefinition aus data/recipes.json.

var id: String
var machine: String          # def_id der Maschine (furnace, press)
var inputs: Dictionary = {}  # item_id → Menge
var output_item: String
var output_count: int = 1
var ticks: int = 20
var tech: String = ""        # "" = ohne Tech verfügbar


static func from_dict(d: Dictionary) -> RecipeDef:
	var r := RecipeDef.new()
	r.id = str(d.get("id", ""))
	r.machine = str(d.get("machine", ""))
	for k in d.get("inputs", {}):
		r.inputs[str(k)] = int(d["inputs"][k])
	var out: Dictionary = d.get("output", {})
	r.output_item = str(out.get("item", ""))
	r.output_count = int(out.get("count", 1))
	r.ticks = int(d.get("ticks", 20))
	r.tech = str(d.get("tech", ""))
	return r


## Lädt alle Rezepte in Dateireihenfolge (Reihenfolge = Priorität bei der Rezeptwahl).
static func load_all(path: String) -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("recipes.json nicht lesbar: " + path)
		return result
	for entry: Dictionary in parsed.get("recipes", []):
		result.append(from_dict(entry))
	return result
