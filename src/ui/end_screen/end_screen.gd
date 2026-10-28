extends CanvasLayer
## Abspann nach dem Abflug (MS37): Sternenhimmel, das Schiff fliegt davon, Geschichte, Bilanz und
## Mitwirkende rollen nach oben. A halten = schneller, B = ans Ende springen. Am Ende „Weiterspielen“;
## danach geht das Spiel normal weiter.

signal closed

const SCROLL_PX_S := 70.0
const FAST_FACTOR := 6.0
const INK := Color(1.0, 0.97, 0.88)
const GOLD := Color(1.0, 0.8, 0.3)
const SOFT := Color(0.75, 0.8, 0.95)

var _bg: ColorRect
var _stars: Control
var _ship: Sprite2D
var _roll: VBoxContainer
var _end_center: CenterContainer
var _end_box: VBoxContainer
var _close_btn: Button
var _hint: Label
var _time := 0.0
var _star_pts: Array[Vector3] = []   # x, y, Phase


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.07, 0.08, 0.18)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_stars = Control.new()
	_stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.draw.connect(_draw_stars)
	add_child(_stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	for i in 160:
		_star_pts.append(Vector3(rng.randf() * 1920.0, rng.randf() * 1080.0, rng.randf() * TAU))
	_ship = Sprite2D.new()
	_ship.texture = load("res://assets/sprites/buildings/ship_5.svg")
	_ship.scale = Vector2(0.9, 0.9)
	add_child(_ship)
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 18)
	_roll.custom_minimum_size = Vector2(1100, 0)
	add_child(_roll)
	_end_center = CenterContainer.new()
	_end_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_center.visible = false
	add_child(_end_center)
	_end_box = VBoxContainer.new()
	_end_box.add_theme_constant_override("separation", 28)
	_end_center.add_child(_end_box)
	var thanks := _label(tr("CREDITS_THANKS"), 56, GOLD)
	thanks.autowrap_mode = TextServer.AUTOWRAP_OFF
	_end_box.add_child(thanks)
	_close_btn = Button.new()
	_close_btn.text = tr("END_CLOSE")
	_close_btn.custom_minimum_size = Vector2(420, 80)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.add_theme_font_size_override("font_size", 30)
	_close_btn.pressed.connect(close)
	_end_box.add_child(_close_btn)
	_hint = _label(tr("CREDITS_HINT"), 22, SOFT)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(0, 1080 - 56)
	_hint.size = Vector2(1920, 40)
	add_child(_hint)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _fill(world: SimWorld) -> void:
	for c in _roll.get_children():
		c.queue_free()
	_roll.add_child(_label(tr("END_TITLE"), 64, GOLD))
	_roll.add_child(_label(tr("END_STORY"), 30, INK))
	_roll.add_child(_gap(60))
	_roll.add_child(_label(tr("CREDITS_STATS"), 40, GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 8)
	for row: Array in FinaleStats.rows(world):
		var k := _label(tr(str(row[0])), 28, SOFT)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		var v := _label(str(row[1]), 28, INK)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(k)
		grid.add_child(v)
	_roll.add_child(grid)
	_roll.add_child(_gap(60))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/credits.json"))
	for sec: Dictionary in (data as Dictionary).get("sections", []):
		_roll.add_child(_label(tr(str(sec["title_key"])), 26, GOLD))
		for line: String in sec.get("lines", []):
			_roll.add_child(_label(tr(line.substr(1)) if line.begins_with("@") else line, 32, INK))
		_roll.add_child(_gap(28))
	_roll.add_child(_gap(40))
	_roll.add_child(_label(tr("END_RUSTY"), 30, INK))
	_roll.add_child(_gap(240))


func show_stats(world: SimWorld) -> void:
	_fill(world)
	_time = 0.0
	_end_center.visible = false
	_hint.visible = true
	_roll.position = Vector2((1920 - _roll.custom_minimum_size.x) / 2.0, 1080.0)
	visible = true
	get_tree().paused = true
	SimClock.paused = true
	InputRouter.context = InputRouter.Context.MENU


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_stars.queue_redraw()
	# Das Schiff steigt schräg durchs Bild und wird kleiner
	var t := clampf(_time / 18.0, 0.0, 1.0)
	_ship.position = Vector2(1560 - 300 * t, 980 - 1160 * t)
	_ship.scale = Vector2.ONE * lerpf(0.9, 0.25, t)
	_ship.rotation = -0.15
	if _end_center.visible:
		return
	var speed := SCROLL_PX_S * (FAST_FACTOR if Input.is_action_pressed("interact") else 1.0)
	_roll.position.y -= speed * delta
	if _roll.position.y + _roll.size.y < 1080.0 * 0.5:
		_show_end()


func _show_end() -> void:
	_roll.position.y = -_roll.size.y
	_end_center.visible = true
	_hint.visible = false
	_close_btn.grab_focus()


func _draw_stars() -> void:
	for p in _star_pts:
		var a := 0.45 + 0.4 * sin(_time * 1.7 + p.z)
		var y := fposmod(p.y + _time * 12.0, 1080.0)
		_stars.draw_circle(Vector2(p.x, y), 1.5 + (p.z / TAU) * 1.5, Color(1, 1, 0.9, a))


func close() -> void:
	visible = false
	get_tree().paused = false
	SimClock.paused = false
	InputRouter.context = InputRouter.Context.GAME
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not _end_center.visible:
		if MenuInput.back_pressed(event) or event.is_action_pressed("pause"):
			_show_end()
			get_viewport().set_input_as_handled()
		return
	if MenuInput.back_pressed(event) or MenuInput.accept_pressed(event):
		close()
		get_viewport().set_input_as_handled()
