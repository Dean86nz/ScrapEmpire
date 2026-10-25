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


func test_deadzone_applied() -> void:
	InputMapSetup.apply()
	assert_true(absf(InputMap.action_get_deadzone("move_left") - InputMapSetup.DEADZONE) < 0.001)
