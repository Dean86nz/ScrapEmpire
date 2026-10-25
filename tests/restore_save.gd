extends SceneTree
## Einmal-Werkzeug: erzeugt einen Spielstand mit vorgegebenen Werten (nach versehentlichem Löschen).
## Aufruf: Godot --headless --path . -s tests/restore_save.gd -- bolts=1980 level=4 points=3 "inv=scrap:6,copper:30,chrome:20,plastic:2"


func _initialize() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.progression = Progression.load_config("res://data/progression.json")
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	var start := MapLoader.load_into(w, "res://data/maps/tutorial.json")
	var args := OS.get_cmdline_user_args()
	var level := 1
	var points := 0
	for a in args:
		var kv := a.split("=")
		match kv[0]:
			"bolts":
				w.bolts = int(kv[1])
			"level":
				level = int(kv[1])
			"points":
				points = int(kv[1])
			"inv":
				for pair in kv[1].split(","):
					var ic := pair.split(":")
					w.player.inventory.add(ic[0], int(ic[1]))
	# XP bis zum gewünschten Level, danach Skillpunkte setzen
	var total := 0
	for n in range(2, level + 1):
		total += w.progression.xp_for_level(n)
	w.progression.add_xp(total)
	w.progression.skill_points = points
	var data := SaveCodec.encode(w, "tutorial", Vector2(start), 0)
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	sm._ready()
	var ok: bool = sm.write(data)
	print("restore: bolts=%d level=%d points=%d ok=%s" % [w.bolts, w.progression.level, w.progression.skill_points, str(ok)])
	sm.free()
	quit(0 if ok else 1)
