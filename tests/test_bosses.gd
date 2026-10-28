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


func test_rusty_needs_the_next_tier() -> void:
	var w := _world()
	var b := _boss(w)
	assert_eq(b.tier, 2)
	w.player.pos = b.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	var hard := []
	w.too_hard.connect(func(n: ResourceNode, _t: String) -> void: hard.append(n.kind))
	w.player.hammer_pressed = true
	TestWorlds.run(w, 12)
	assert_eq(hard, ["toaster_tower"], "Startwerkzeug reicht nicht")
	var before := b.amount
	w.player.hammer_tier = 2
	w.player.hammer_pressed = true
	TestWorlds.run(w, 12)
	assert_true(b.amount < before, "mit T2 geht es")


func test_three_bots_crack_the_boss_together() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	var b := _boss(w)
	var h1 := w.add_helper(Vector2i(14, 14), w.ship().tile)
	h1.zone_id = "a"
	assert_false(NetworkSystem.team_can_hit(w, b), "ein Bot reicht nicht")
	for i in 2:
		var h := w.add_helper(Vector2i(16, 16), w.ship().tile)
		h.zone_id = "a"
	assert_true(NetworkSystem.team_can_hit(w, b), "drei Bots schaffen es")
	var before := b.amount
	TestWorlds.run(w, 20 * 20)
	assert_true(not w.nodes.has(b.id) or b.amount < before, "Bots hämmern am Boss")


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
