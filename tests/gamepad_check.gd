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

	_step("Vorbereitung: Material, Bolts, Features",
		func() -> void:
			# 6 Slots × 20: nicht überfüllen, sonst kommen Chrom und Schaltkreise nicht an
			_world.player.inventory.add("scrap", 40)
			_world.player.inventory.add("wood", 20)
			_world.player.inventory.add("chrome", 10)
			_world.player.inventory.add("circuit", 10)
			_world.bolts = 5000
			for f in ["autopilot", "helpers", "drones", "decor"]:
				_world.unlocked_features[f] = true
			var chest := _world.place_free("chest", _world.player_tile() + Vector2i(3, 3), 0)
			_world.place_free("furnace", _world.player_tile() + Vector2i(6, 3), 0)
			assert(chest != null),
		func() -> bool: return _world.player.inventory.count_of("scrap") >= 40 and _world.player.inventory.count_of("chrome") >= 10 and _world.player.inventory.count_of("circuit") >= 10)

	# Baumenü
	_step("Y kurz öffnet das Baumenü", func() -> void: _tap(JOY_BUTTON_Y), func() -> bool: return build_menu.visible)
	_step("A wählt das fokussierte Gebäude (Baumodus startet)", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return not build_menu.visible and cursor.mode == cursor.Mode.PLACE)
	_step("B bricht den Baumodus ab", func() -> void: _tap(JOY_BUTTON_B),
		func() -> bool: return cursor.mode == cursor.Mode.OFF and router.context == router.Context.GAME)
	_step("Y öffnet Baumenü erneut", func() -> void: _tap(JOY_BUTTON_Y), func() -> bool: return build_menu.visible)
	_step("RB wechselt auf die Deko-Seite", func() -> void: _tap(JOY_BUTTON_RIGHT_SHOULDER), func() -> bool: return build_menu._page == 1)
	_step("A wählt Deko-Objekt", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return cursor.mode == cursor.Mode.PLACE and cursor.def != null and cursor.def.category == "decor")
	_step("B verlässt Deko-Baumodus", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return cursor.mode == cursor.Mode.OFF)

	# Fortschritts-Menü
	_step("Select kurz öffnet Fortschritt (Tab Kapitel)", func() -> void: _tap(JOY_BUTTON_BACK),
		func() -> bool: return progress.visible and progress._tab == progress.Tab.GOALS)
	_step("RB wechselt auf Forschung", func() -> void: _tap(JOY_BUTTON_RIGHT_SHOULDER), func() -> bool: return progress._tab == progress.Tab.TECH)
	_step("Fokus auf erste erforschbare Karte (wie per D-Pad)", func() -> void:
			var avail: Array = _world.tech.available()
			if not avail.is_empty():
				(progress._tech_cards[str(avail[0])] as Button).grab_focus(),
		func() -> bool:
			var f := root.gui_get_focus_owner()
			return f is Button and progress._tech_cards.values().has(f))
	_step("A auf Forschungskarte startet Forschung", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.tech.is_researching() or _new_quips(), 8, 200)
	_step("B schließt Fortschritt", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not progress.visible and router.context == router.Context.GAME)

	# Helfer-Tab
	_step("Select öffnet Fortschritt", func() -> void: _tap(JOY_BUTTON_BACK), func() -> bool: return progress.visible)
	_step("RB x4 erreicht Tab Helfer", func() -> void:
			for n in 4:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.HELPERS, 6)
	_step("A auf „Helfer kaufen“ startet Zonenwahl", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return not progress.visible and cursor.mode == cursor.Mode.TARGET)
	_step("B bricht Zonenwahl ab", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return cursor.mode == cursor.Mode.OFF)

	# Drohnen-Tab
	_step("Select öffnet Fortschritt (2)", func() -> void: _tap(JOY_BUTTON_BACK), func() -> bool: return progress.visible)
	_step("RB x5 erreicht Tab Drohnen", func() -> void:
			for n in 5:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.DRONES, 6)
	_step("A auf „Drohne kaufen“ startet Quellenwahl", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return not progress.visible and cursor.mode == cursor.Mode.TARGET)
	_step("B bricht Quellenwahl ab", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return cursor.mode == cursor.Mode.OFF)

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
