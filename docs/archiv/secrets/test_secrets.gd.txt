extends TestCase
## Secrets (MS60): Fortschritt, Fund, Bonus, Speicherung über Flags, Steam-IDs eindeutig.


func test_ducks_count_up_and_give_bonus() -> void:
	var w := TestWorlds.make()
	SecretSystem.load_defs()
	var found := []
	w.secret_found.connect(func(id: String) -> void: found.append(id))
	var before := float(w.mods["sell_mult"])
	for i in 11:
		assert_false(SecretSystem.progress(w, "ducks"))
	assert_true(SecretSystem.progress(w, "ducks"), "zwölfte Ente: gefunden")
	assert_eq(found, ["ducks"])
	assert_true(float(w.mods["sell_mult"]) > before, "kleiner Bolts-Bonus")
	assert_true(bool(w.flags["secret_ducks_done"]), "steht in den Flags (wird gespeichert)")


func test_secret_object_counts_when_removed() -> void:
	var w := TestWorlds.make()
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var n := w.add_object("golden_heap", Vector2i(5, 5))
	w._remove_node(n)
	assert_true(SecretSystem.is_found(w, "golden_heap"))


func test_steam_ids_unique_and_map_has_all_secret_objects() -> void:
	SecretSystem.load_defs()
	var ids := {}
	for s: Dictionary in SecretSystem.defs:
		assert_false(ids.has(s["steam_id"]), "Steam-ID doppelt: " + str(s["steam_id"]))
		ids[s["steam_id"]] = true
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/main.json"))
	var c := {}
	for nd: Dictionary in m["nodes"]:
		c[nd["kind"]] = int(c.get(nd["kind"], 0)) + 1
	assert_eq(int(c.get("cracked_wall", 0)), 6)
	assert_eq(int(c.get("rubber_duck", 0)), 12)
	for k in ["golden_heap", "toilet", "kaltholz_fridge", "dev_wall"]:
		assert_eq(int(c.get(k, 0)), 1, k)
