extends TestCase
## Fortschritt im Hintergrund (MS81): höchstens 8 h, nichts bei kurzer/negativer Zeit,
## deterministisch, begrenzt durch vorhandenen Müll, Rustys Anteil zählt nicht.


func _world(piles := 30) -> SimWorld:
	var w := TestWorlds.make(60, 30)
	TestWorlds.with_ship(w, Vector2i(2, 2))
	var st := w.place_free(StationSystem.DEF, Vector2i(20, 15)) as Station
	StationSystem.apply(w, st)
	StationSystem.bind(w.add_helper(st.tile, st.tile), st)
	for i in piles:
		w.add_pile("scrap_pile", Vector2i(10 + (i * 7) % 45, 3 + (i * 5) % 24), 10)
	# Gemessene Rate: 60 Teile/min am Schiff, davon 0 von Rusty, 2 Bolts je Teil
	w.tick_count = 2000
	w.perf.add("trash", 60, 800)
	w.perf.add("bolts", 120, 800)
	w.tick_count = 2000
	return w


func test_short_or_negative_time_does_nothing() -> void:
	var w := _world()
	assert_eq(OfflineSystem.apply(w, 30), {}, "unter 1 Minute")
	assert_eq(OfflineSystem.apply(w, -5000), {}, "Uhr zurückgestellt")


func test_capped_at_eight_hours() -> void:
	var a := OfflineSystem.apply(_world(2000), 8 * 3600)
	var b := OfflineSystem.apply(_world(2000), 30 * 3600)
	assert_eq(b["seconds"], 8 * 3600)
	assert_eq(b["trash"], a["trash"], "mehr als 8 h bringt nichts")
	assert_eq(b["bolts"], a["bolts"])


func test_deterministic_and_bounded_by_trash() -> void:
	var w1 := _world(5)
	var w2 := _world(5)
	var r1 := OfflineSystem.apply(w1, 4 * 3600)
	var r2 := OfflineSystem.apply(w2, 4 * 3600)
	assert_eq(r1, r2, "gleicher Stand, gleiches Ergebnis")
	assert_eq(int(r1["trash"]), 50, "nur so viel, wie da ist (5 Haufen à 10)")
	assert_eq(int(r1["bolts"]), 100, "2 Bolts je Teil")
	assert_eq(w1.nodes.size(), 0, "Müll ist weg")


func test_rusty_share_does_not_count() -> void:
	var w := _world()
	w.perf.add("rusty", 60, 800)
	assert_eq(OfflineSystem.apply(w, 3600), {}, "alles kam von Rusty: im Hintergrund nichts")
