class_name BuildingDef
extends RefCounted
## Datendefinition eines Gebäudes aus data/buildings.json.

var id: String
var name_key: String
var size := Vector2i.ONE
var cost: Dictionary = {}        # item_id → Basis-Menge
var cost_growth := 1.0           # Faktor pro bereits gebautem Exemplar
var sprite := ""
var ports: Array = []            # [{side, dir, cell}] – relevant ab MS4 (Bänder)
var category := "building"       # "building" oder "decor"
var requires_feature := ""       # z. B. "decor": baubar, sobald das Feature frei ist (statt per unlock_building)


static func from_dict(d: Dictionary) -> BuildingDef:
	var def := BuildingDef.new()
	def.id = str(d.get("id", ""))
	def.name_key = str(d.get("name_key", def.id))
	var s: Array = d.get("size", [1, 1])
	def.size = Vector2i(int(s[0]), int(s[1]))
	for k in d.get("cost", {}):
		def.cost[str(k)] = int(d["cost"][k])
	def.cost_growth = float(d.get("cost_growth", 1.0))
	def.sprite = str(d.get("sprite", ""))
	def.ports = d.get("ports", [])
	def.category = str(d.get("category", "building"))
	def.requires_feature = str(d.get("requires_feature", ""))
	return def


## Lädt alle Definitionen: id → BuildingDef.
static func load_all(path: String) -> Dictionary:
	var result: Dictionary = {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("buildings.json nicht lesbar: " + path)
		return result
	for entry: Dictionary in parsed.get("buildings", []):
		var def := from_dict(entry)
		result[def.id] = def
	return result


func rotated_size(rot: int) -> Vector2i:
	return size if rot % 2 == 0 else Vector2i(size.y, size.x)
