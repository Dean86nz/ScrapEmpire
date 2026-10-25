extends Node
## Lädt die JSON-Daten aus data/ (Items, Sprüche; ab MS2 Gebäude, Rezepte, Tech).
## Balancing ändert JSON, nie GDScript.

var items: Dictionary = {}          # id → Dictionary (id, name_key, sell_value, color, icon)
var quips: Dictionary = {}          # trigger → Array[String] (Übersetzungs-Keys)
var building_defs: Dictionary = {}  # id → BuildingDef
var recipes: Array[RecipeDef] = []
var _icon_cache: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	items.clear()
	for entry: Dictionary in _read_json("res://data/items.json").get("items", []):
		items[str(entry["id"])] = entry
	quips = _read_json("res://data/quips.json")
	building_defs = BuildingDef.load_all("res://data/buildings.json")
	recipes = RecipeDef.load_all("res://data/recipes.json")
	ResourceNode.load_defs("res://data/scrap_objects.json")


func new_progression() -> Progression:
	return Progression.load_config("res://data/progression.json")


func helper_config() -> Dictionary:
	return _read_json("res://data/helpers.json")


func drone_config() -> Dictionary:
	return _read_json("res://data/drones.json")


func collectible_config() -> Dictionary:
	return _read_json("res://data/collectibles.json")


func tech_defs() -> Array:
	return TechState.load_defs("res://data/tech.json")


func skill_data() -> Dictionary:
	return SkillState.load_file("res://data/skills.json")


## Items mit "rare": true (Kenner-Skill): item_id → true
func rare_items() -> Dictionary:
	var result: Dictionary = {}
	for id in items:
		if bool(items[id].get("rare", false)):
			result[id] = true
	return result


func node_name(kind: String) -> String:
	var d: Dictionary = ResourceNode.defs.get(kind, {})
	return tr(str(d.get("name_key", kind)))


func item_values() -> Dictionary:
	var result: Dictionary = {}
	for id in items:
		result[id] = int(items[id].get("sell_value", 0))
	return result


func item_name(item_id: String) -> String:
	if items.has(item_id):
		return tr(str(items[item_id].get("name_key", item_id)))
	return item_id


func item_color(item_id: String) -> Color:
	if items.has(item_id):
		return Color.html(str(items[item_id].get("color", "#FFFFFF")))
	return Color.WHITE


func item_icon(item_id: String) -> Texture2D:
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]
	var tex: Texture2D = null
	if items.has(item_id):
		tex = load(str(items[item_id].get("icon", "")))
	_icon_cache[item_id] = tex
	return tex


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Datendatei fehlt oder leer: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("Ungültiges JSON: " + path)
		return {}
	return parsed
