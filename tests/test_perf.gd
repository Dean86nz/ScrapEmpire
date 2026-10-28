extends TestCase
## Leistung (MS35): 40 Bots, 12 Drohnen, viel Müll – ein Sim-Tick bleibt weit unter dem Budget.


func test_bot_army_tick_stays_cheap() -> void:
	var w := TestWorlds.make(120, 90)
	TestWorlds.with_ship(w, Vector2i(58, 43))
	for f in ["helpers", "drones", "collection", "courier"]:
		w.unlocked_features[f] = true
	for i in 160:
		w.add_pile("scrap_pile", Vector2i(5 + (i * 7) % 110, 5 + (i * 13) % 80), 10)
	for i in 40:
		w.add_helper(Vector2i(10 + (i * 11) % 100, 10 + (i * 17) % 70), w.ship().tile)
	for i in 12:
		w.add_drone()
	TestWorlds.run(w, 20)
	var t0 := Time.get_ticks_usec()
	TestWorlds.run(w, 100)
	var ms := (Time.get_ticks_usec() - t0) / 100000.0
	print("   Leistung: %.2f ms je Tick mit 40 Bots und 12 Drohnen" % ms)
	assert_true(ms < 5.0, "Sim-Tick unter 5 ms (%.2f)" % ms)
