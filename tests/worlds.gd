class_name TestWorlds
extends RefCounted
## Gemeinsame Test-Welten mit allen Datendateien (kein test_-Präfix: der Runner lädt diese Datei nicht als Test).


static func make(width: int = 40, height: int = 30) -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(width, height)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.helper_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))
	w.drone_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/drones.json"))
	w.ship_cfg = ShipSystem.load_config()
	w.collectible_cfg = {"collectibles": []}
	w.quests.setup(QuestState.load_defs())
	w.milestones.setup(MilestoneState.load_defs())
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.player.pos = Vector2i(320, 352)
	w.player.aim = Vector2.RIGHT
	return w


## Schiff bei `tile` (3×3) aufstellen und Stufe anwenden.
static func with_ship(w: SimWorld, tile: Vector2i = Vector2i(2, 2)) -> Ship:
	var s := w.place_free("ship", tile, 0) as Ship
	ShipSystem.apply_stage(w, s)
	return s


static func run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.tick()
