extends TestCase
## Phase 2, Punkt 0: Jedes Müll-Objekt ist erreichbar, und die Karte bezahlt den Weg zum Abflug.


func _map() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/main.json"))


func _skill(id: String) -> Dictionary:
	for s: Dictionary in SkillState.load_file("res://data/skills.json").get("skills", []):
		if s["id"] == id:
			return s
	return {}


## Höchste Werkzeugstufe, die Rusty über den Skill „Werkzeug“ erreicht (Start 1).
func _max_rusty_tier() -> int:
	var tool := _skill("tool")
	var tier := 1
	for e: Dictionary in tool.get("effects", []):
		if e["key"] == "hammer_tier":
			tier += int(round(float(e.get("per_level", 1)) * int(tool["max_level"])))
	return tier


func test_every_map_object_is_reachable() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var max_tier := _max_rusty_tier()
	assert_true(max_tier >= 5, "Rusty erreicht mindestens Stufe 5: %d" % max_tier)
	var bad := []
	for n: Dictionary in _map().get("nodes", []):
		var d: Dictionary = ResourceNode.defs.get(str(n["kind"]), {})
		if int(d.get("tier", 1)) <= max_tier:
			continue
		# Bosse: nur gemeinsam, Stufe egal; aber so viele Bots muss man bauen können (MS42)
		if bool(d.get("boss", false)):
			var max_bots := int(JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))["max_helpers"])
			if int(d.get("bots_needed", 0)) >= 1 and int(d["bots_needed"]) <= max_bots:
				continue
		bad.append("%s (T%d)" % [n["kind"], int(d["tier"])])
	assert_eq(bad, [], "zu harte Objekte auf der Karte")


func test_every_zone_has_one_boss_and_one_final() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var bosses := {}
	var finals := 0
	var m := _map()
	for n: Dictionary in m.get("nodes", []):
		var d: Dictionary = ResourceNode.defs[str(n["kind"])]
		if bool(d.get("boss", false)):
			for z: Dictionary in m["zones"]:
				if int(n["x"]) >= int(z["x"]) and int(n["x"]) < int(z["x"]) + int(z["w"]) and int(n["y"]) >= int(z["y"]) and int(n["y"]) < int(z["y"]) + int(z["h"]):
					bosses[z["id"]] = int(bosses.get(z["id"], 0)) + 1
			if bool(d.get("final", false)):
				finals += 1
	assert_eq(bosses.size(), (m["zones"] as Array).size(), "jede Zone hat einen Boss")
	for k in bosses:
		assert_eq(int(bosses[k]), 1, "genau ein Boss in " + str(k))
	assert_eq(finals, 1, "genau ein Endboss")


func test_event_objects_are_reachable_from_the_start() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	for kind in ["trash_bag", "meteor"]:
		assert_eq(int(ResourceNode.defs[kind]["tier"]), 1, kind + " mit Startwerkzeug knackbar")


## Wert aller Karten-Objekte plus Kleinschrott aus dem Putzen, mit mittlerem Ertrag (halber Weg
## zum vollen Ertrags-Upgrade), muss die Pflichtkosten bis zum Abflug decken: alle Schiffsstufen
## und alle Ertrags-Stufen. Ereignisse sind Bonus und zählen nicht mit.
func test_map_pays_for_the_launch() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var values := Economy.load_item_values("res://data/items.json")
	var base := 0
	for n: Dictionary in _map().get("nodes", []):
		var d: Dictionary = ResourceNode.defs[str(n["kind"])]
		var items: Dictionary = {str(d.get("item", "scrap")): int(n.get("amount", d.get("max", 10)))} if str(d.get("type", "")) == "pile" else n.get("loot", d.get("yield", {}))
		for k in items:
			base += int(values.get(str(k), 0)) * int(items[k])
	# Kleinschrott: etwa jede 5. geputzte Kachel; geputzt wird die anfangs schmutzige Fläche
	var w := TestWorlds.make(120, 90)
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, _map())
	var dirty := 0
	for k in w.dirt.zone_start:
		dirty += int(w.dirt.zone_start[k])
	base += dirty / int(w.dirt_cfg.get("scrap_every_tiles", 5))
	var ship := ShipSystem.load_config()
	var yield_def: Dictionary = ship["upgrades"][0]
	var max_bonus := 0.0
	for e: Dictionary in yield_def["effects"]:
		if e["key"] == "sell_mult":
			# "mul": ×(1 + Wert) je Stufe (MS57), sonst additiv
			if str(e.get("op", "add")) == "mul":
				max_bonus = pow(1.0 + float(e["per_level"]), int(yield_def["max_level"])) - 1.0
			else:
				max_bonus = float(e["per_level"]) * int(yield_def["max_level"])
	var earnable := int(base * (1.0 + max_bonus * 0.5))
	var required := 0
	for st: Dictionary in ship["stages"]:
		required += int(st.get("cost_bolts", 0))
	# Realistisch (MS58): alle Schiffsstufen plus Ertrag bis Stufe 40 (nicht jede Stufe ist Pflicht)
	for lv in mini(40, int(yield_def["max_level"])):
		required += Costs.upgrade(yield_def, lv)
	print("   Wirtschaft: Kartenwert %d, verdienbar %d, nötig %d" % [base, earnable, required])
	assert_true(earnable >= required, "Karte reicht bis zum Abflug: verdienbar %d, nötig %d" % [earnable, required])
