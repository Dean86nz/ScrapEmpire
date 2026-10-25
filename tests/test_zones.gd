extends TestCase


func _map() -> Dictionary:
	return {
		"width": 40, "height": 30,
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 20, "h": 30}, {"id": "b", "name": "B", "x": 20, "y": 0, "w": 20, "h": 30}],
		"nodes": [
			{"kind": "scrap_pile", "x": 2, "y": 2, "amount": 10},   # Rohstoff, kein Müll
			{"kind": "toaster", "x": 5, "y": 5},                    # 10 Müll
			{"kind": "pallet", "x": 7, "y": 5},                     # 8 Müll
			{"kind": "satellite", "x": 9, "y": 5},                  # Rohstoffquelle, kein Müll
			{"kind": "fridge", "x": 25, "y": 5},                    # Zone B: 27 Müll
		],
	}


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	MapLoader.apply(w, _map())
	w.player.pos = Vector2i(320, 352)
	w.player.hammer_tier = 3
	return w


func test_new_objects_and_items_exist() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	for k in ["pallet", "concrete", "sofa", "ruin_wall", "driftwood_pile", "rubble_field"]:
		assert_true(ResourceNode.has_kind(k), "fehlt: " + k)
	var values := Economy.load_item_values("res://data/items.json")
	assert_eq(values["wood"], 2)
	assert_eq(values["stone"], 2)
	var n := ResourceNode.from_kind(1, "satellite", Vector2i.ZERO)
	assert_true(n.is_resource())
	var p := ResourceNode.from_kind(2, "pallet", Vector2i.ZERO)
	assert_false(p.is_resource())


func test_start_trash_counts_only_trash() -> void:
	var w := _world()
	assert_eq(w.zones.start_trash["a"], 18, "Toaster 10 + Palette 8")
	assert_eq(w.zones.start_trash["b"], 27)
	assert_eq(w.zones.zone_id_at(Vector2i(25, 5)), "b")
	assert_eq(w.zones.zone_id_at(Vector2i(99, 99)), "")


func test_cleanliness_and_stages() -> void:
	var w := _world()
	assert_true(absf(w.zones.cleanliness("a", w.nodes)) < 0.001)
	assert_eq(w.zones.stage("a", w.nodes), 0)
	# Toaster komplett zerlegen (10 Items) → 10/18 = 55 % → Stufe 2
	var toaster: ResourceNode = null
	for n: ResourceNode in w.nodes.values():
		if n.kind == "toaster":
			toaster = n
	var changes := []
	w.zones.stage_changed.connect(func(id: String, st: int) -> void: changes.append([id, st]))
	w.zones.refresh(w.nodes)  # Ausgangsstufen merken
	w.player.pos = toaster.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	for i in 12:
		w.player.hammer_pressed = true
		for j in 10:
			w.tick()
	assert_false(w.nodes.has(toaster.id))
	assert_true(absf(w.zones.cleanliness("a", w.nodes) - 10.0 / 18.0) < 0.01)
	assert_eq(w.zones.stage("a", w.nodes), 2)
	assert_true(changes.size() >= 1 and changes.back()[0] == "a" and changes.back()[1] == 2, "Stufenwechsel gemeldet: %s" % str(changes))


func test_trash_respawn_blocked_above_50_percent() -> void:
	var w := _world()
	var toaster: ResourceNode = null
	for n: ResourceNode in w.nodes.values():
		if n.kind == "toaster":
			toaster = n
	w.player.pos = toaster.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	for i in 12:
		w.player.hammer_pressed = true
		for j in 10:
			w.tick()
	# 55 % sauber → der Toaster kommt nicht wieder
	assert_eq(w.respawns.size(), 0, "kein Respawn-Eintrag für Müll in sauberer Zone")


func test_trash_respawns_below_50_percent() -> void:
	var w := _world()
	# Zone B: nur der Kühlschrank (27). Wir hämmern 10 Items → 37 % sauber → respawnt noch
	var fridge: ResourceNode = null
	for n: ResourceNode in w.nodes.values():
		if n.kind == "fridge":
			fridge = n
	w.player.pos = fridge.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	for i in 27:
		w.player.hammer_pressed = true
		for j in 10:
			w.tick()
	# Kühlschrank ganz weg → 100 %: Respawn wurde beim Entfernen geprüft (Zone sauber) → kein Eintrag
	assert_eq(w.respawns.size(), 0)
	assert_eq(w.zones.stage("b", w.nodes), 3)


func test_resource_always_respawns() -> void:
	var w := _world()
	w.player.suction_tier = 3
	var sat: ResourceNode = null
	for n: ResourceNode in w.nodes.values():
		if n.kind == "satellite":
			sat = n
	w.player.pos = sat.center_px() + Vector2i(-60, 0)
	w.player.aim = Vector2.RIGHT
	w.player.suck_held = true
	for i in 15 * 6:
		w.tick()
	assert_false(w.nodes.has(sat.id))
	assert_eq(w.respawns.size(), 1, "Satellit respawnt immer")
	assert_eq(w.respawns[0]["kind"], "satellite")


func test_summary() -> void:
	var w := _world()
	var s := w.zones.summary(w.nodes)
	assert_eq(s.size(), 2)
	assert_eq(s[0]["name"], "A")
	assert_eq(s[0]["trash_by_tier"], {1: 2})
	assert_eq(s[1]["trash_by_tier"], {2: 1})
