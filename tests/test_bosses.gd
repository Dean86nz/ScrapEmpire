extends TestCase
## Müllberg-Bosse (MS36): Tor bleibt zu, Rusty braucht die Stufe oder ein Bot-Team, Belohnung, Endboss.


func _world() -> SimWorld:
	var w := TestWorlds.make(60, 30)
	MapLoader.apply(w, {"width": 60, "height": 30, "zone_order": ["a", "b"], "unlock_cleanliness": 0.0,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 2},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 30, "h": 30}, {"id": "b", "name": "B", "x": 30, "y": 0, "w": 30, "h": 30}],
		"nodes": [{"kind": "toaster_tower", "x": 15, "y": 15}]})
	return w


func _boss(w: SimWorld) -> ResourceNode:
	for n: ResourceNode in w.nodes.values():
		if n.boss:
			return n
	return null


func test_boss_keeps_the_gate_closed() -> void:
	var w := _world()
	TestWorlds.run(w, 25)
	assert_false(w.zones.is_unlocked("b"), "Boss steht noch: Tor zu")
	w._remove_node(_boss(w))
	TestWorlds.run(w, 25)
	assert_true(w.zones.is_unlocked("b"), "Boss weg: Tor auf")


func test_rusty_alone_does_no_damage() -> void:
	var w := _world()
	var b := _boss(w)
	b.bots_needed = 3
	w.player.pos = b.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	var blocked := []
	w.boss_blocked.connect(func(_n: ResourceNode, have: int, need: int) -> void: blocked.append([have, need]))
	var before := b.amount
	w.player.hammer_pressed = true
	TestWorlds.run(w, 4)
	assert_eq(blocked, [[0, 3]], "allein: kein Schaden, Hinweis 0/3")
	assert_eq(b.amount, before)


func test_rally_calls_bots_in_radius() -> void:
	var w := _world()
	var b := _boss(w)
	var near := w.add_helper(Vector2i(12, 12), w.ship().tile)
	near.pos = b.center_px() + Vector2i(600, 0)
	var far := w.add_helper(Vector2i(12, 12), w.ship().tile)
	far.pos = b.center_px() + Vector2i(64 * 40, 0)
	var calls := []
	w.boss_rally.connect(func(_n: ResourceNode, c: int) -> void: calls.append(c))
	assert_eq(BossSystem.rally(w, b), 1)
	assert_eq(near.rally_id, b.id)
	assert_eq(far.rally_id, -1, "zu weit weg")
	assert_eq(calls, [1])


func test_bots_come_and_boss_falls_together() -> void:
	var w := _world()
	var b := _boss(w)
	for i in 2:
		var h := w.add_helper(Vector2i(12, 12), w.ship().tile)
		h.pos = b.center_px() + Vector2i(500, 100 * i)
	b.bots_needed = 2
	w.player.pos = b.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	var before := b.amount
	for k in 60:
		w.player.hammer_pressed = true
		TestWorlds.run(w, 10)
	assert_true(BossSystem.helpers_at(w, b) >= 2 or not w.nodes.has(b.id), "Bots stehen beim Boss")
	assert_true(not w.nodes.has(b.id) or b.amount < before, "gemeinsam nimmt der Boss Schaden")


func test_bots_never_pick_bosses_on_their_own() -> void:
	var w := _world()
	var b := _boss(w)
	var h := w.add_helper(Vector2i(15, 15), w.ship().tile)
	h.pos = b.center_px() + Vector2i(100, 0)
	h.hammer_tier = 5
	TestWorlds.run(w, 200)
	assert_eq(h.rally_id, -1)
	assert_true(b.amount > 0 and w.nodes.has(b.id), "ohne Ruf lassen Bots den Boss in Ruhe")


func test_defeat_releases_bots() -> void:
	var w := _world()
	var b := _boss(w)
	var h := w.add_helper(Vector2i(12, 12), w.ship().tile)
	h.pos = b.center_px()
	BossSystem.rally(w, b)
	w._remove_node(b)
	assert_eq(h.rally_id, -1)


func test_defeat_pays_reward_and_sets_flags() -> void:
	var w := _world()
	var got := []
	w.boss_defeated.connect(func(kind: String, zid: String, reward: int) -> void: got.append([kind, zid, reward]))
	w._remove_node(_boss(w))
	assert_eq(got, [["toaster_tower", "a", 150]])
	assert_eq(w.bolts, 150)
	assert_true(w.flags.has("boss_a"))
	assert_false(w.flags.has("final_boss"))


func test_final_boss_unlocks_the_launch_flag() -> void:
	var w := _world()
	var ur := w.add_object("ur_heap", Vector2i(40, 10))
	assert_true(ur.final)
	w._remove_node(ur)
	assert_true(w.flags.has("final_boss"))


func test_gate_quest_waits_for_the_boss() -> void:
	var w := _world()
	var q := QuestState.new()
	q.defs = [{"id": "g", "type": "zone_gate"}, {"id": "b", "type": "bosses", "amount": 1}]
	assert_false(q.is_satisfied(w), "Boss steht: Tor-Aufgabe offen")
	w._remove_node(_boss(w))
	assert_true(q.is_satisfied(w))
	q.index = 1
	assert_true(q.is_satisfied(w), "ein Boss geknackt")
