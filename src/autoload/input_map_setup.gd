class_name InputMapSetup
extends RefCounted
## Registriert alle Spielaktionen zur Laufzeit in der InputMap.
## Vorteil gegenüber project.godot: lesbar, testbar, keine handgeschriebene Serialisierung.
## Godot-eigene ui_*-Aktionen (Menü-Navigation) bleiben unberührt; sie sind bereits
## auf D-Pad, linken Stick, A und B gemappt.

const DEADZONE := 0.2


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


static func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


static func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e


static var ACTIONS: Dictionary = {
	# Bewegung: linker Stick / WASD
	"move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
	"move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
	"move_up": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
	"move_down": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
	# Zielen: rechter Stick (Maus wird im Player direkt gelesen)
	"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
	"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
	"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
	"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
	# Werkzeuge
	"tool_primary": [_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _mouse(MOUSE_BUTTON_LEFT)],
	"tool_secondary": [_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _mouse(MOUSE_BUTTON_RIGHT)],
	"tool_swap": [_btn(JOY_BUTTON_X), _key(KEY_Q)],
	"boost": [_btn(JOY_BUTTON_LEFT_STICK), _key(KEY_SHIFT)],
	# Interaktion und Menüs
	"interact": [_btn(JOY_BUTTON_A), _key(KEY_E)],
	"cancel": [_btn(JOY_BUTTON_B), _key(KEY_ESCAPE)],
	"build_menu": [_btn(JOY_BUTTON_Y), _key(KEY_TAB)],
	"hotbar_prev": [_btn(JOY_BUTTON_LEFT_SHOULDER), _mouse(MOUSE_BUTTON_WHEEL_UP)],
	"hotbar_next": [_btn(JOY_BUTTON_RIGHT_SHOULDER), _mouse(MOUSE_BUTTON_WHEEL_DOWN)],
	"tech_tree": [_btn(JOY_BUTTON_BACK), _key(KEY_T)],
	"pause": [_btn(JOY_BUTTON_START), _key(KEY_ESCAPE)],
	# Rastercursor im Baumodus
	"cursor_up": [_btn(JOY_BUTTON_DPAD_UP), _key(KEY_UP)],
	"cursor_down": [_btn(JOY_BUTTON_DPAD_DOWN), _key(KEY_DOWN)],
	"cursor_left": [_btn(JOY_BUTTON_DPAD_LEFT), _key(KEY_LEFT)],
	"cursor_right": [_btn(JOY_BUTTON_DPAD_RIGHT), _key(KEY_RIGHT)],
	# Entwickler
	"debug_overlay": [_key(KEY_F3)],
	"debug_cheat": [_key(KEY_F4)],
	"debug_perf": [_key(KEY_F6)],
	"debug_chain": [_key(KEY_F7)],
	"toggle_fullscreen": [_key(KEY_F11)],
}


static func apply() -> void:
	for action: String in ACTIONS.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, DEADZONE)
		for ev: InputEvent in ACTIONS[action]:
			InputMap.action_add_event(action, ev)
