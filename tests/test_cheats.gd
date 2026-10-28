extends TestCase
## Cheat-Menü nur im Debug-Build (MS55): main.gd hängt es ausschließlich hinter OS.is_debug_build() ein.


func test_cheat_menu_only_behind_debug_check() -> void:
	var src := FileAccess.get_file_as_string("res://src/world/main.gd")
	var i := src.find("CheatMenu.new()")
	assert_true(i > 0, "Cheat-Menü wird in main.gd erzeugt")
	var guard := src.rfind("if OS.is_debug_build():", i)
	assert_true(guard > 0 and i - guard < 200, "nur hinter OS.is_debug_build()")
	assert_eq(src.count("CheatMenu.new()"), 1, "nirgends sonst")


func test_time_x10_speeds_up_sim() -> void:
	var acc := TickAccumulator.new()
	assert_eq(acc.advance(0.1 * 10.0), 5, "Zeit ×10: 1 s Sim in 0,1 s (gedeckelt auf 5 Ticks je Bild)")
