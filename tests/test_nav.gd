extends TestCase
## Bots fahren um Zäune herum statt hindurch (Ally-Fehler v2.7.0, MS48).


func test_bot_walks_around_a_wall() -> void:
	var w := TestWorlds.make(30, 20)
	MapLoader.apply(w, {"width": 30, "height": 20, "zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 30, "h": 20}], "nodes": []})
	for y in range(0, 15):
		w.blocked_tiles[Vector2i(10, y)] = true   # Wand mit Lücke unten
	w.blocked_version += 1
	var h := w.add_helper(Vector2i(5, 5), Vector2i(5, 5))
	h.pos = Vector2i(5, 5) * 64 + Vector2i(32, 32)
	h.move_target = Vector2i(15, 5) * 64 + Vector2i(32, 32)
	var crossed_wall := false
	for i in 400:
		h._move(w)
		if w.blocked_tiles.has(Vector2i(h.pos.x / 64, h.pos.y / 64)):
			crossed_wall = true
	assert_false(crossed_wall, "nie durch die Wand")
	assert_eq(h.pos, h.move_target, "Ziel hinter der Wand erreicht")
