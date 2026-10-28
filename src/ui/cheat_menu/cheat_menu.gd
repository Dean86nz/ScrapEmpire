class_name CheatMenu
extends CanvasLayer
## Admin-Cheat-Menü NUR zum Testen (MS55). main.gd hängt es ausschließlich in Debug-Builds ein
## (OS.is_debug_build()); in der Release-EXE für Steam existiert es nicht.
## Aufruf: Ally L3 + R3 (beide Sticks drücken) 1 s halten, PC F12. B oder F12 schließt.

signal new_game_requested

const HOLD_SECONDS := 1.0

var _main: Node
var _panel := PanelContainer.new()
var _box := VBoxContainer.new()
var _info := Label.new()
var _hold := 0.0
var _zone_index := 0
var _boss_index := 0
var _was_context := 0


func setup(main: Node) -> void:
	_main = main
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(_panel)
	_panel.add_child(_box)
	_box.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "CHEATS (nur Debug-Build)"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_add("+100K Bolts", func() -> void: _w().bolts += 100000; _w().bolts_changed.emit(_w().bolts))
	_add("+10K XP", func() -> void: _w().progression.add_xp(10000))
	_add("Alles freischalten", _unlock_all)
	_add("Zur nächsten Zone springen", _next_zone)
	_add("Boss neben Rusty erzeugen", _spawn_boss)
	_add("Zeit ×10 an/aus", func() -> void: SimClock.speed = 1.0 if SimClock.speed > 1.0 else 10.0)
	_add("Touristen jetzt", func() -> void: _event("tourists"))
	_add("Meteoriten jetzt", func() -> void: _event("meteors"))
	_add("Spielstand zurücksetzen (neues Spiel)", func() -> void:
		close()
		new_game_requested.emit())
	_add("Schließen", close)
	_info.add_theme_font_size_override("font_size", 22)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_info)
	KenneySkin.apply(_panel)


func _w() -> SimWorld:
	return SimClock.world


func _add(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(620, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func() -> void:
		cb.call()
		_refresh_info())
	_box.add_child(b)


func _refresh_info() -> void:
	_info.text = "Bolts %s · Zeit ×%d" % [Fmt.int_str(_w().bolts), int(SimClock.speed)]


func open() -> void:
	visible = true
	_was_context = InputRouter.context
	InputRouter.context = InputRouter.Context.MENU
	_refresh_info()
	(_box.get_child(1) as Button).grab_focus()


func close() -> void:
	visible = false
	InputRouter.context = InputRouter.Context.GAME


func _process(delta: float) -> void:
	if visible:
		return
	var held := false
	for dev in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_STICK) and Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_STICK):
			held = true
	_hold = _hold + delta if held else 0.0
	if _hold >= HOLD_SECONDS and InputRouter.context == InputRouter.Context.GAME:
		_hold = 0.0
		open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_F12:
		if visible:
			close()
		elif InputRouter.context == InputRouter.Context.GAME:
			open()
		get_viewport().set_input_as_handled()
	elif visible and MenuInput.back_pressed(event):
		close()
		get_viewport().set_input_as_handled()
	elif visible and MenuInput.accept_pressed(event):
		MenuInput.press_focused(get_viewport())


func _unlock_all() -> void:
	var w := _w()
	for f in ["helpers", "collection", "helper_tools", "drones", "courier", "launch"]:
		w.unlocked_features[f] = true
	for z in w.zones.zones:
		var zid := str(z["id"])
		if not w.zones.is_unlocked(zid):
			w.zones.unlocked[zid] = true
			w.zone_unlocked.emit(zid)


func _next_zone() -> void:
	var zones := _w().zones.zones
	if zones.is_empty():
		return
	_zone_index = (_zone_index + 1) % zones.size()
	var z: Dictionary = zones[_zone_index]
	var zid := str(z["id"])
	if not _w().zones.is_unlocked(zid):
		_w().zones.unlocked[zid] = true
		_w().zone_unlocked.emit(zid)
	var r: Rect2i = z["rect"]
	var player: Node2D = _main.get_node("Player")
	player.global_position = Vector2(r.get_center() * ResourceNode.TILE) + Vector2(0, 200)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	_info.text = "Zone: %s" % str(z["name"])


func _spawn_boss() -> void:
	var bosses: Array[String] = []
	for k: String in ResourceNode.defs:
		if bool(ResourceNode.defs[k].get("boss", false)):
			bosses.append(k)
	if bosses.is_empty():
		return
	bosses.sort()
	var kind := bosses[_boss_index % bosses.size()]
	_boss_index += 1
	var t := _w().player_tile() + Vector2i(4, 0)
	_w().add_object(kind, t)
	_info.text = "Boss: %s" % kind


func _event(type: String) -> void:
	EventSystem.ensure_state(_w())
	_w().events_state["next"][type] = _w().tick_count
