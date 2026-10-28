extends SceneTree
## Prüft „Speichern, Beenden, Weiterspielen“ über echte Programmstarts (aufgerufen von tests/continue_check.sh).
## Phase "play":     neues Spiel, spielen, Start → D-Pad zu „Speichern und Beenden“ → A (Programm endet).
## Phase "continue": Titel, A auf „Weiterspielen“, Zustand mit der Erwartung vergleichen, weiterspielen,
##                   Ladeschutz muss nach dem Laden wieder weg sein.
## Phase "rescue":   simuliert einen abgestürzten Ladevorgang; der Titel muss die Rettung anbieten,
##                   A auf „Neu beginnen“ sichert den alten Stand und startet ein neues Spiel.
## Exit-Code 0 = alles bestanden.

const EXPECT := "user://continue_expect.json"

var _phase := "play"
var _frame := 0
var _steps: Array[Dictionary] = []
var _i := -1
var _wait := 0
var _wait_until := 0
var _fails: Array[String] = []
var _cost := 0
var _sm: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		_phase = args[0]


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_sm = root.get_node("/root/SaveManager")
		match _phase:
			"play":
				_sm.delete_all()
				change_scene_to_file("res://src/world/main.tscn")
			"rescue":
				# Ein Ladevorgang, der nie fertig wurde (Absturz), hinterlässt die Schutzdatei.
				_sm.begin_load(_sm.latest_file_name())
				change_scene_to_file("res://src/ui/title/title.tscn")
			_:
				change_scene_to_file("res://src/ui/title/title.tscn")
		return false
	if _frame < 10 or current_scene == null:
		return false
	if _steps.is_empty():
		_build()
	if _wait > 0 or Time.get_ticks_msec() < _wait_until:
		_wait = maxi(_wait - 1, 0)
		return false
	if _i >= 0:
		var ok: bool = _steps[_i]["check"].call()
		print(("PASS " if ok else "FAIL ") + "[%s] %s" % [_phase, _steps[_i]["name"]])
		if not ok:
			_fails.append(str(_steps[_i]["name"]))
	_i += 1
	if _i >= _steps.size():
		print("%s: %d Prüfungen, %d Fehler" % [_phase, _steps.size(), _fails.size()])
		quit(1 if not _fails.is_empty() else 0)
		return true
	_steps[_i]["run"].call()
	_wait = int(_steps[_i].get("wait", 4))
	_wait_until = Time.get_ticks_msec() + int(_steps[_i].get("ms", 60))
	return false


func _step(name: String, run: Callable, check: Callable, wait: int = 4, ms: int = 60) -> void:
	_steps.append({"name": name, "run": run, "check": check, "wait": wait, "ms": ms})


func _tap(b: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pressed
		Input.parse_input_event(e)


func _axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func _world() -> SimWorld:
	return root.get_node("/root/SimClock").world


func _snapshot() -> Dictionary:
	var w := _world()
	var s := w.ship()
	return {
		"bolts": w.bolts, "ship_stage": s.stage if s != null else -1, "cargo": int(w.ship_upgrades.get("yield", 0)),
		"slots": w.player.inventory.slot_count, "buildings": w.buildings.size(), "nodes": w.nodes.size(), "quest": w.quests.index,
		"inventory": w.player.inventory.total(), "level": w.progression.level, "xp": w.progression.xp,
		"tile": [w.player_tile().x, w.player_tile().y],
	}


## JSON liefert Zahlen als float: für den Vergleich auf int bringen.
func _ints(v: Variant) -> Variant:
	if v is Array:
		var out := []
		for x in v:
			out.append(int(x))
		return out
	return int(v) if (v is float or v is int) else v


func _focused_text() -> String:
	var f := root.gui_get_focus_owner()
	return (f as Button).text if f is Button else ""


func _build() -> void:
	match _phase:
		"play":
			_build_play()
		"continue":
			_build_continue()
		"rescue":
			_build_rescue()


func _build_play() -> void:
	_step("Neues Spiel läuft, Schiff steht", func() -> void: pass, func() -> bool: return _world() != null and _world().ship() != null)
	_step("Spielen: abliefern und Ertrag-Upgrade kaufen", func() -> void:
			var w := _world()
			w.bolts = 123
			w.player.inventory.add("copper", 15)
			w.queue_command({"type": "deliver_all"})
			_cost = ShipSystem.upgrade_cost(w, "yield")
			w.queue_command({"type": "buy_upgrade", "id": "yield"}),
		func() -> bool:
			_world().player.inventory.add("scrap", 7)  # etwas in der Tasche, das gespeichert werden muss
			var m: Dictionary = _world().mods  # Kauf zuerst, dann Abgabe mit Ertrag 1
			return _world().bolts == 123 - _cost + int(round(3 * 15 * float(m["sell_mult"]) * float(m["rare_mult"]))) and int(_world().ship_upgrades.get("yield", 0)) == 1, 6, 1200)
	_step("Fahren mit dem Stick", func() -> void: _axis(JOY_AXIS_LEFT_X, 1.0),
		func() -> bool: return true, 30, 600)
	_step("Stick loslassen", func() -> void: _axis(JOY_AXIS_LEFT_X, 0.0), func() -> bool: return true, 4, 100)
	_step("Start öffnet Pause, Zustand merken", func() -> void:
			_tap(JOY_BUTTON_START),
		func() -> bool:
			var ok: bool = current_scene.get_node("PauseMenu").visible
			var f := FileAccess.open(EXPECT, FileAccess.WRITE)
			f.store_string(JSON.stringify(_snapshot()))
			f.close()
			return ok)
	_step("D-Pad 1× hoch (im Kreis) zu „Speichern und Beenden“", func() -> void:
			_tap(JOY_BUTTON_DPAD_UP),
		func() -> bool: return _focused_text() == TranslationServer.translate("MENU_SAVE_QUIT"), 6)
	# A beendet das Programm; der Runner wertet den Exit-Code und die Spielstand-Datei aus.
	_step("A: Speichern und Beenden", func() -> void: _tap(JOY_BUTTON_A), func() -> bool: return false, 30, 2000)


func _build_continue() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	_step("Titel: „Weiterspielen“ sichtbar und fokussiert", func() -> void: pass,
		func() -> bool: return _focused_text() == TranslationServer.translate("TITLE_CONTINUE"))
	_step("A auf „Weiterspielen“ lädt das Spiel", func() -> void: _tap(JOY_BUTTON_A),
		func() -> bool: return current_scene != null and current_scene.name == "Main", 20, 500)
	_step("Ladeschutz ist während des Ladens gesetzt", func() -> void: pass,
		func() -> bool: return not _sm.failed_load().is_empty())
	_step("Zustand wie beim Speichern", func() -> void: pass, func() -> bool:
			var now := _snapshot()
			var ok := true
			for k in ["bolts", "ship_stage", "cargo", "slots", "buildings", "nodes", "quest", "inventory", "level", "xp", "tile"]:
				if JSON.stringify(now[k]) != JSON.stringify(JSON.parse_string(JSON.stringify(expect[k]))) and str(_ints(now[k])) != str(_ints(expect[k])):
					print("   %s: erwartet %s, ist %s" % [k, str(expect[k]), str(now[k])])
					ok = false
			return ok)
	_step("Weiterspielen: fahren, Zeit läuft", func() -> void: _axis(JOY_AXIS_LEFT_Y, 1.0),
		func() -> bool: return _world().tick_count > 0, 30, 600)
	_step("Stick los, Ladeschutz nach 3 s entfernt", func() -> void: _axis(JOY_AXIS_LEFT_Y, 0.0),
		func() -> bool: return _sm.failed_load().is_empty(), 10, 3500)


func _build_rescue() -> void:
	_step("Titel zeigt die Rettung nach abgestürztem Laden", func() -> void: pass,
		func() -> bool: return current_scene.get_node("Center/VBox/Warning").visible)
	_step("Fokus liegt auf einer Rettungs-Option", func() -> void: pass, func() -> bool:
			var t := _focused_text()
			return t == TranslationServer.translate("TITLE_LOAD_BACKUP") or t == TranslationServer.translate("TITLE_FRESH_SAFE"))
	_step("Fokus auf „Neu beginnen“, A", func() -> void:
			(current_scene.get_node("Center/VBox/NewButton") as Button).grab_focus()
			_tap(JOY_BUTTON_A),
		func() -> bool: return current_scene != null and current_scene.name == "Main", 20, 600)
	_step("Alter Stand gesichert, neues Spiel läuft", func() -> void: pass, func() -> bool:
			var backups := 0
			for f in DirAccess.get_files_at(_sm.save_dir):
				if f.contains(".bak"):
					backups += 1
			return backups >= 1 and _world().bolts == 0 and _sm.failed_load().is_empty(), 4, 3500)
