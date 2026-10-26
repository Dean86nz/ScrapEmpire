extends SceneTree
## Gamepad-Prüfung aller Menüs mit simulierten Joypad-Ereignissen (A, B, Y, Start, Select, RB).
## Lädt die Hauptszene, spielt eine Schrittfolge ab und prüft nach jedem Schritt den Zustand.
## Aufruf nur über tests/gamepad_check.sh (schützt den echten Spielstand).
## Exit-Code 1, wenn eine Prüfung fehlschlägt.

var _frame := 0
var _steps: Array[Dictionary] = []
var _i := -1
var _wait_frames := 0
var _wait_until_ms := 0
var _fails: Array[String] = []
var _main: Node
var _world: SimWorld
var _quips: Array[String] = []
var _quip_mark := 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		var sm: Node = root.get_node("/root/SaveManager")
		sm.use_directory("user://saves_test/")
		sm.delete_all()
		root.get_node("/root/EventBus").quip.connect(func(key: String) -> void: _quips.append(key))
		change_scene_to_file("res://src/world/main.tscn")
		return false
	if _frame < 8 or current_scene == null:
		return false
	if _main == null:
		_main = current_scene
		_world = root.get_node("/root/SimClock").world
		_build_steps()
	if _wait_frames > 0 or Time.get_ticks_msec() < _wait_until_ms:
		_wait_frames = maxi(_wait_frames - 1, 0)
		return false
	if _i >= 0:
		var step := _steps[_i]
		var ok: bool = step["check"].call()
		if not ok and _world != null:
			print("   Zustand: bolts=%d inv=%d stage=%d cargo=%d bots=%d drohnen=%d tick=%d befehle=%d" % [_world.bolts, _world.player.inventory.total(), _world.ship().stage if _world.ship() else -1, int(_world.ship_upgrades.get("cargo", 0)), _world.helpers.size(), _world.drones.size(), _world.tick_count, _world.pending_commands()])
		print(("PASS " if ok else "FAIL ") + str(step["name"]))
		if not ok:
			_fails.append(str(step["name"]))
	_i += 1
	if _i >= _steps.size():
		print("%d Gamepad-Prüfungen, %d Fehler" % [_steps.size(), _fails.size()])
		for f in _fails:
			printerr("FAIL " + f)
		quit(1 if not _fails.is_empty() else 0)
		return true
	var next := _steps[_i]
	_quip_mark = _quips.size()
	next["run"].call()
	_wait_frames = int(next.get("wait", 4))
	_wait_until_ms = Time.get_ticks_msec() + int(next.get("wait_ms", 60))
	return false


# --- Eingabe-Helfer ----------------------------------------------------------

func _btn(index: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(index: JoyButton) -> void:
	_btn(index, true)
	_btn(index, false)


func _axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _node(name: String) -> Node:
	return _main.get_node(name)


func _step(name: String, run: Callable, check: Callable, wait: int = 4, wait_ms: int = 60) -> void:
	_steps.append({"name": name, "run": run, "check": check, "wait": wait, "wait_ms": wait_ms})


func _new_quips() -> bool:
	return _quips.size() > _quip_mark


# --- Schrittfolge -------------------------------------------------------------

func _build_steps() -> void:
	var cursor := _node("BuildCursor")
	var build_menu := _node("BuildMenu")
	var progress := _node("ProgressMenu")
	var editor := _node("TaskEditor")
	var pause := _node("PauseMenu")
	var router: Node = root.get_node("/root/InputRouter")

	var player: Node2D = _node("Player")

	_step("Vorbereitung: Material, Bolts, Features",
		func() -> void:
			_world.player.inventory.add("wood", 20)
			_world.bolts = 5000
			for f in ["autopilot", "decor"]:
				_world.unlocked_features[f] = true,
		func() -> bool: return _world.player.inventory.count_of("wood") >= 20 and _world.ship() != null)

	# Baumenü (Deko)
	_step("Y kurz öffnet das Baumenü", func() -> void: _tap(JOY_BUTTON_Y), func() -> bool: return build_menu.visible)
	_step("A wählt das fokussierte Deko-Objekt (Baumodus startet)", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return not build_menu.visible and cursor.mode == cursor.Mode.PLACE and cursor.def.category == "decor")
	_step("B bricht den Baumodus ab", func() -> void: _tap(JOY_BUTTON_B),
		func() -> bool: return cursor.mode == cursor.Mode.OFF and router.context == router.Context.GAME)

	# Am Schiff: A liefert ab, X öffnet das Schiff-Menü
	_step("Rusty fährt ans Schiff, Taschen voll Schrott", func() -> void:
			var s := _world.ship()
			player.global_position = Vector2(s.center_px()) + Vector2(0, 140)
			_world.player.inventory.add("scrap", 10),
		func() -> bool: return player.nearby_building() is Ship, 4, 100)
	_step("A liefert alles ab (Schrott und Holz), Bolts steigen", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.player.inventory.total() == 0 and _world.bolts == 5000 + 10 + 20 * 2, 6, 200)
	_step("X öffnet das Schiff-Menü", func() -> void: _tap(JOY_BUTTON_X),
		func() -> bool: return progress.visible and progress._tab == progress.Tab.SHIP)
	_step("A auf „Schiff reparieren“ (Fokus): Stufe 2", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.ship().stage == 2 and _world.unlocked_features.has("helpers"), 8, 200)
	_step("D-Pad rechts zum Laderaum, A kauft", func() -> void:
			_tap(JOY_BUTTON_DPAD_RIGHT)
			_tap(JOY_BUTTON_A),
		func() -> bool: return int(_world.ship_upgrades.get("cargo", 0)) == 1 and _world.player.inventory.slot_count == 5, 8, 200)
	_step("B schließt das Schiff-Menü", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not progress.visible and router.context == router.Context.GAME)

	# Bots-Tab
	_step("Select öffnet Schiff und Ziele", func() -> void: _tap(JOY_BUTTON_BACK),
		func() -> bool: return progress.visible and progress._tab == progress.Tab.SHIP)
	_step("RB x4 erreicht Tab Bots", func() -> void:
			for n in 4:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.HELPERS, 6)
	_step("A auf „Sammel-Bot bauen“ baut einen Bot", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.helpers.size() == 1, 8, 200)
	_step("B schließt", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not progress.visible)

	# Drohnen-Tab
	_step("Drohnen-Blaupause frei", func() -> void: _world.unlocked_features["drones"] = true, func() -> bool: return true)
	_step("Select öffnet Schiff und Ziele (2)", func() -> void: _tap(JOY_BUTTON_BACK), func() -> bool: return progress.visible)
	_step("RB x5 erreicht Tab Drohnen", func() -> void:
			for n in 5:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.DRONES, 6)
	_step("A auf „Drohne bauen“ baut eine Drohne", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.drones.size() == 1, 8, 200)
	_step("B schließt (2)", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not progress.visible and router.context == router.Context.GAME)

	# Aufgaben-Editor (Y lang)
	_step("Y lang (halten)", func() -> void: _btn(JOY_BUTTON_Y, true), func() -> bool: return true, 2, 700)
	_step("Y loslassen: Aufgaben-Editor offen", func() -> void: _btn(JOY_BUTTON_Y, false), func() -> bool: return editor.visible, 6)
	_step("A auf „Schritt hinzufügen“ zeigt Schritt-Typen", func() -> void: _tap(JOY_BUTTON_A), func() -> bool: return editor._choosing_type)
	_step("B geht zurück zur Liste", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return editor.visible and not editor._choosing_type)
	_step("B schließt den Editor", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not editor.visible and router.context == router.Context.GAME)

	# Pause
	_step("Start öffnet Pause", func() -> void: _tap(JOY_BUTTON_START), func() -> bool: return pause.visible)
	_step("A auf „Fortsetzen“ schließt Pause", func() -> void: _tap(JOY_BUTTON_A), func() -> bool: return not pause.visible and not paused)

	# Sauger: Trigger-Schwelle
	_step("RT 0,3 saugt nicht (Schwelle 0,5)", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.3),
		func() -> bool: return not _world.player.suck_held, 6)
	_step("RT 0,6 saugt", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6), func() -> bool: return _world.player.suck_held, 6)
	_step("RT 0,0 stoppt", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0), func() -> bool: return not _world.player.suck_held, 6)
