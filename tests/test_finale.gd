extends TestCase
## Finale (MS37): Abflug merkt sich die Zeit, Abspann-Bilanz zeigt die Kennzahlen.


func _launched_world() -> SimWorld:
	var w := TestWorlds.make()
	MapLoader.apply(w, {"width": 40, "height": 30, "zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}],
		"nodes": [{"kind": "toaster", "x": 20, "y": 20}]})
	var s := TestWorlds.with_ship(w)
	s.stage = 4
	ShipSystem.apply_stage(w, s)
	w.bolts = ShipSystem.next_stage_cost(w, s) + 40000
	w.flags["final_boss"] = true
	w.flags["boss_a"] = true
	for n in w.nodes.values():
		w._remove_node(n)
	w.tick_count = 20 * 60 * 75  # 1 h 15 min
	w.quests.counters["sold_value"] = 12345
	w.queue_command({"type": "upgrade_ship"})
	w.tick()
	return w


func test_launch_remembers_the_time() -> void:
	var w := _launched_world()
	assert_true(w.flags.has("launch_tick"))
	assert_eq(int(w.flags["launch_tick"]) / 20 / 60, 75)


func test_stats_show_time_bolts_and_bosses() -> void:
	var w := _launched_world()
	TestWorlds.run(w, 20 * 60 * 10)  # später weiterspielen ändert die Spielzeit im Abspann nicht
	var rows := {}
	for r: Array in FinaleStats.rows(w):
		rows[r[0]] = r[1]
	assert_eq(rows["STAT_TIME"], "1:15 h")
	assert_true(str(rows["STAT_BOLTS"]).begins_with("12"))
	assert_eq(rows["STAT_BOSSES"], "1 / 1")
	assert_eq(rows.size(), 11)


func test_credits_data_is_valid() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/credits.json"))
	assert_true(d is Dictionary)
	for sec: Dictionary in d["sections"]:
		assert_true(TranslationServer.translate(str(sec["title_key"])) != str(sec["title_key"]), "Text fehlt: " + str(sec["title_key"]))


func test_boss_count_ignores_other_boss_flags() -> void:
	# Ally-Fehler v2.22.0: Abspann zeigte „Bosse geknackt 7 / 6“ (Flag boss_help_seen mitgezählt).
	var w := _launched_world()
	w.flags["boss_help_seen"] = true
	var rows := {}
	for r: Array in FinaleStats.rows(w):
		rows[r[0]] = r[1]
	assert_eq(rows["STAT_BOSSES"], "1 / 1")
