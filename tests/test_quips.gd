extends TestCase
## Dezentere Sprechblasen (MS44): Ereignisse mit Mindestabstand, Plaudereien selten, eine Blase.


func _quips() -> Node:
	var q: Node = Engine.get_main_loop().root.get_node("Quips")
	var reg: Node = Engine.get_main_loop().root.get_node("DataRegistry")
	if reg.quips.is_empty():
		reg.load_all()
	if not EventBus.quip.is_connected(q._on_request):
		EventBus.quip.connect(q._on_request)
	q._since_any = 999.0
	q._since_chatter = 999.0
	return q


func test_events_keep_minimum_gap() -> void:
	var q := _quips()
	var shown := []
	var cb := func(key: String, _s: float) -> void: shown.append(key)
	EventBus.speak.connect(cb)
	EventBus.quip.emit("QUIP_RALLY")
	EventBus.quip.emit("LAUNCH_Q")
	assert_eq(shown, ["QUIP_RALLY"], "zweites Ereignis direkt danach fällt weg")
	q._since_any = 7.0
	EventBus.quip.emit("LAUNCH_Q")
	assert_eq(shown.size(), 2, "nach dem Mindestabstand wieder erlaubt")
	EventBus.speak.disconnect(cb)


func test_chatter_is_rare() -> void:
	var q := _quips()
	assert_true(q.say("idle"), "erste Plauderei erlaubt")
	q._since_any = 30.0
	assert_false(q.say("idle"), "gleich danach: keine Plauderei")
	q._since_chatter = 151.0
	assert_true(q.say("idle"), "nach 2,5 min wieder")
	q._since_any = 0.0
	assert_true(q.say("level_up", true), "Ereignis wird gewünscht (Filter entscheidet beim Zeigen)")
