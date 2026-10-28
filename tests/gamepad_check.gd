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
var _vol_before := 0.0
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
			print("   Zustand: bolts=%d inv=%d stage=%d ertrag=%d bots=%d drohnen=%d tick=%d befehle=%d" % [_world.bolts, _world.player.inventory.total(), _world.ship().stage if _world.ship() else -1, int(_world.ship_upgrades.get("yield", 0)), _world.helpers.size(), _world.drones.size(), _world.tick_count, _world.pending_commands()])
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
	var progress := _node("ProgressMenu")
	var pause := _node("PauseMenu")
	var router: Node = root.get_node("/root/InputRouter")

	var player: Node2D = _node("Player")

	_step("Select am Anfang: nur drei Tabs (Schiff, Ziele, Karte)", func() -> void: _tap(JOY_BUTTON_BACK),
		func() -> bool:
			var n := 0
			for t in progress.TAB_COUNT:
				if progress._tab_enabled(t):
					n += 1
			return progress.visible and n == 3)
	_step("RB x3 läuft einmal rundherum zurück zu Schiff", func() -> void:
			for n in 3:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.SHIP, 6)
	_step("B schließt (Start)", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not progress.visible)
	_step("Vorbereitung: Material, Bolts, Features",
		func() -> void:
			_world.player.inventory.add("wood", 20)
			_world.bolts = 5000
			for f in ["collection"]:
				_world.unlocked_features[f] = true,
		func() -> bool: return _world.player.inventory.count_of("wood") >= 20 and _world.ship() != null)

	# Fester Bauplatz (MS41): hinfahren, A, Sammelstelle steht
	_step("Rusty fährt zum Bauplatz der Startzone", func() -> void:
			var site := NetworkSystem.site_of(_world, _world.zones.zone_id_at(_world.player_tile()))
			player.global_position = Vector2(site * 64 + Vector2i(64, 64 + 110)),
		func() -> bool: return NetworkSystem.site_near_player(_world) != "", 4, 100)
	_step("A baut die Sammelstelle", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return NetworkSystem.points(_world).size() == 1 and _world.bolts < 5000, 6, 200)
	_step("Nach dem Bau-Jubel: Steuerung zurück", func() -> void: pass,
		func() -> bool: return router.context == router.Context.GAME, 4, 1000)
	_step("Bolts zurücksetzen", func() -> void: _world.bolts = 5000, func() -> bool: return _world.bolts == 5000)

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
	_step("Nach der Reparatur: Menü zu, Rusty jubelt (Eingabe ruht)", func() -> void: pass,
		func() -> bool: return not progress.visible and player.is_cheering(), 2)
	_step("Nach höchstens 1 s fährt Rusty wieder", func() -> void: pass,
		func() -> bool: return not player.is_cheering() and router.context == router.Context.GAME, 4, 1000)
	_step("X öffnet das Schiff-Menü wieder", func() -> void: _tap(JOY_BUTTON_X),
		func() -> bool: return progress.visible and progress._tab == progress.Tab.SHIP)
	_step("D-Pad rechts zum Ertrag, A kauft", func() -> void:
			_tap(JOY_BUTTON_DPAD_RIGHT)
			_tap(JOY_BUTTON_A),
		func() -> bool: return int(_world.ship_upgrades.get("yield", 0)) == 1, 8, 200)
	_step("Kauf schließt das Menü, Rusty jubelt, danach Steuerung zurück", func() -> void: pass,
		func() -> bool: return not progress.visible and router.context == router.Context.GAME, 4, 1000)

	# Bots-Tab
	_step("Select öffnet Schiff und Ziele", func() -> void: _tap(JOY_BUTTON_BACK),
		func() -> bool: return progress.visible and progress._tab == progress.Tab.SHIP)
	_step("RB x4 erreicht Tab Bots", func() -> void:
			for n in 4:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.HELPERS, 6)
	_step("A auf „Sammel-Bot bauen“ baut einen Bot", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.helpers.size() == 1, 8, 200)
	_step("Bot gebaut: Menü zu, Jubel, Steuerung zurück", func() -> void: pass,
		func() -> bool: return not progress.visible and router.context == router.Context.GAME, 4, 1000)
	_step("Select öffnet das Menü wieder", func() -> void: _tap(JOY_BUTTON_BACK), func() -> bool: return progress.visible)
	_step("RB x4: wieder im Bots-Tab", func() -> void:
			for n in 4:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.HELPERS, 6)
	_step("Bot-Karte erscheint in der Liste", func() -> void: pass,
		func() -> bool: return progress._helper_cards.size() == 1, 8, 700)
	_step("D-Pad runter auf den Bot", func() -> void: _tap(JOY_BUTTON_DPAD_DOWN),
		func() -> bool: return progress._helper_cards.has(progress.get_viewport().gui_get_focus_owner()))
	_step("A auf dem Bot öffnet die Zuweisung auf der Karte", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return progress._tab == progress.Tab.MAP and progress._assign_bot >= 0, 6)
	_step("A weist die gewählte Zone zu, zurück im Bots-Tab", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return progress._tab == progress.Tab.HELPERS and progress._assign_bot < 0 and int(_world.quests.counters.get("assigns", 0)) == 1, 8, 300)
	_step("Bot-Karte wieder da, D-Pad runter auf den Bot", func() -> void: _tap(JOY_BUTTON_DPAD_DOWN),
		func() -> bool: return progress._helper_cards.has(progress.get_viewport().gui_get_focus_owner()), 8, 700)
	_step("LT auf dem Bot baut ihn ab", func() -> void:
			_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
			_axis(JOY_AXIS_TRIGGER_LEFT, 0.0),
		func() -> bool: return _world.helpers.is_empty(), 8, 200)
	_step("B schließt", func() -> void: _tap(JOY_BUTTON_B), func() -> bool: return not progress.visible)

	# Drohnen-Tab
	_step("Drohnen-Blaupause frei", func() -> void: _world.unlocked_features["drones"] = true, func() -> bool: return true)
	_step("Select öffnet Schiff und Ziele (2)", func() -> void: _tap(JOY_BUTTON_BACK), func() -> bool: return progress.visible)
	_step("RB x5 erreicht Tab Drohnen", func() -> void:
			for n in 5:
				_tap(JOY_BUTTON_RIGHT_SHOULDER),
		func() -> bool: return progress._tab == progress.Tab.DRONES, 6)
	_step("A auf „Drohne bauen“ baut eine Drohne", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return _world.drones.size() == 2, 8, 200)  # 1 kam mit der Sammelstelle
	_step("Drohne gebaut: Menü zu, nach dem Jubel Steuerung zurück", func() -> void: pass,
		func() -> bool: return not progress.visible and router.context == router.Context.GAME, 4, 1000)

	# Y im Spiel: kein Baumenü mehr, nichts öffnet sich
	_step("Y im Spiel öffnet nichts", func() -> void: _tap(JOY_BUTTON_Y), func() -> bool: return router.context == router.Context.GAME, 4)

	# Pause
	_step("Start öffnet Pause", func() -> void: _tap(JOY_BUTTON_START), func() -> bool: return pause.visible)
	_step("D-Pad runter: Musik-Regler hat den Fokus", func() -> void: _tap(JOY_BUTTON_DPAD_DOWN),
		func() -> bool: return pause.get_viewport().gui_get_focus_owner() == pause._music_btn)
	_step("D-Pad links: Musik 10 % leiser, rechts wieder lauter", func() -> void:
			_vol_before = float(root.get_node("/root/Sfx").volume["music"])
			_tap(JOY_BUTTON_DPAD_LEFT),
		func() -> bool: return absf(float(root.get_node("/root/Sfx").volume["music"]) - (_vol_before - 0.1)) < 0.01 and pause.get_viewport().gui_get_focus_owner() == pause._music_btn)
	_step("D-Pad rechts: zurück", func() -> void: _tap(JOY_BUTTON_DPAD_RIGHT),
		func() -> bool: return absf(float(root.get_node("/root/Sfx").volume["music"]) - _vol_before) < 0.01)
	_step("D-Pad hoch, A auf „Fortsetzen“ schließt Pause", func() -> void:
			_tap(JOY_BUTTON_DPAD_UP)
			_tap(JOY_BUTTON_A),
		func() -> bool: return not pause.visible and not paused)

	# Sauger: Trigger-Schwelle
	_step("RT 0,3 saugt nicht (Schwelle 0,5)", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.3),
		func() -> bool: return not _world.player.suck_held, 6)
	_step("RT 0,6 saugt", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.6), func() -> bool: return _world.player.suck_held, 6)
	_step("RT 0,0 stoppt", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.0), func() -> bool: return not _world.player.suck_held, 6)
	# Ally-Fehler v2.0.0: RT gehalten, Pause, Loslassen verpasst → Rusty saugte danach weiter
	_step("RT 0,8 saugt (vor Pause)", func() -> void: _axis(JOY_AXIS_TRIGGER_RIGHT, 0.8), func() -> bool: return _world.player.suck_held, 6)
	_step("Start pausiert mit gehaltenem RT", func() -> void: _tap(JOY_BUTTON_START), func() -> bool: return pause.visible and not _world.player.suck_held)
	_step("Start setzt fort: RT neu gelesen, kein Dauersaugen", func() -> void: _tap(JOY_BUTTON_START),
		func() -> bool: return not pause.visible and not _world.player.suck_held and not Input.is_action_pressed("tool_primary"), 6)

	# Karte: Zoom rein/raus, Y = ganze Karte, Schließen aus dem Zoom (Ally-Fehler v2.0.0)
	_step("Select öffnet das Menü, Karten-Tab", func() -> void:
			_tap(JOY_BUTTON_BACK),
		func() -> bool: return progress.visible)
	_step("Karten-Tab aktiv", func() -> void:
			progress._tab = progress.Tab.MAP
			progress._show_tab(),
		func() -> bool: return progress._tab == progress.Tab.MAP)
	_step("RT zoomt rein (2×)", func() -> void:
			for n in 2:
				_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
				_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0),
		func() -> bool: return progress._map_view.zoom_level() == 2, 6)
	_step("LT zoomt raus", func() -> void:
			_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
			_axis(JOY_AXIS_TRIGGER_LEFT, 0.0),
		func() -> bool: return progress._map_view.zoom_level() == 1, 6)
	_step("Y zeigt die ganze Karte", func() -> void: _tap(JOY_BUTTON_Y),
		func() -> bool: return progress._map_view.zoom_level() == 0 and progress.visible, 6)
	_step("RT zoomt wieder rein", func() -> void:
			_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
			_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0),
		func() -> bool: return progress._map_view.zoom_level() == 1, 6)
	_step("B schließt auch gezoomt", func() -> void: _tap(JOY_BUTTON_B),
		func() -> bool: return not progress.visible and progress._map_view.zoom_level() == 0 and router.context == router.Context.GAME, 6)
	_step("Select öffnet wieder (Karte)", func() -> void: _tap(JOY_BUTTON_BACK), func() -> bool: return progress.visible)
	_step("Select schließt die Karte", func() -> void:
			progress._tab = progress.Tab.MAP
			progress._show_tab()
			_tap(JOY_BUTTON_BACK),
		func() -> bool: return not progress.visible, 6)
