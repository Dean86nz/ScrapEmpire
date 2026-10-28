extends TestCase


func test_all_actions_registered() -> void:
	InputMapSetup.apply()
	for action in InputMapSetup.ACTIONS.keys():
		assert_true(InputMap.has_action(action), "Aktion fehlt: " + action)


func test_apply_is_idempotent() -> void:
	InputMapSetup.apply()
	InputMapSetup.apply()
	var expected: int = InputMapSetup.ACTIONS["move_left"].size()
	assert_eq(InputMap.action_get_events("move_left").size(), expected)


func test_every_action_has_gamepad_or_keyboard_binding() -> void:
	InputMapSetup.apply()
	for action in InputMapSetup.ACTIONS.keys():
		assert_true(InputMap.action_get_events(action).size() > 0, "keine Bindung: " + action)


func test_trigger_deadzone_is_higher() -> void:
	InputMapSetup.apply()
	assert_true(absf(InputMap.action_get_deadzone("tool_primary") - 0.5) < 0.001, "RT-Schwelle 0,5")
	assert_true(absf(InputMap.action_get_deadzone("tool_secondary") - 0.5) < 0.001, "LT-Schwelle 0,5")


func test_trigger_below_threshold_is_not_pressed() -> void:
	InputMapSetup.apply()
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_TRIGGER_RIGHT
	e.axis_value = 0.3
	assert_false(e.is_action_pressed("tool_primary"), "0,3 gilt nicht als gedrückt")
	e.axis_value = 0.6
	assert_true(e.is_action_pressed("tool_primary"), "0,6 gilt als gedrückt")
	e.axis = JOY_AXIS_TRIGGER_LEFT
	e.axis_value = 0.3
	assert_false(e.is_action_pressed("tool_secondary"))
	e.axis_value = 0.6
	assert_true(e.is_action_pressed("tool_secondary"))
	# Stick-Aktionen behalten die normale Schwelle
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 0.3
	assert_true(m.is_action_pressed("move_right"), "Stick 0,3 bewegt")


func test_ui_accept_and_cancel_have_gamepad_buttons() -> void:
	InputMapSetup.apply()
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	assert_true(InputMap.action_has_event("ui_accept", a), "A ist ui_accept")
	assert_true(InputMap.action_has_event("ui_cancel", b), "B ist ui_cancel")
	assert_true(InputMap.action_has_event("interact", a), "A bleibt interact")


func test_dev_keys_only_in_debug_builds() -> void:
	InputMapSetup.apply(false)
	for a in InputMapSetup.DEV_ACTIONS:
		assert_true(InputMap.has_action(a), "Aktion existiert: " + a)
		assert_eq(InputMap.action_get_events(a).size(), 0, "Release: keine Taste für " + a)
	InputMapSetup.apply(true)
	assert_true(InputMap.action_get_events("debug_save").size() > 0, "Debug: F5 belegt")


func test_deadzone_applied() -> void:
	InputMapSetup.apply()
	assert_true(absf(InputMap.action_get_deadzone("move_left") - InputMapSetup.DEADZONE) < 0.001)


func test_pause_resets_stuck_suction() -> void:
	# Ally-Fehler v2.0.0: nach Pause saugte Rusty weiter, weil das Loslassen von RT verpasst wurde.
	InputMapSetup.apply()
	var router: Node = Engine.get_main_loop().root.get_node_or_null("InputRouter")
	assert_true(router != null, "InputRouter-Autoload da")
	Input.action_press("tool_primary", 1.0)
	SimClock.world.player.suck_held = true
	router.reset_tools()
	assert_false(Input.is_action_pressed("tool_primary"), "RT nach Pause nicht mehr gedrückt")
	assert_false(SimClock.world.player.suck_held, "Sim saugt nicht mehr")
