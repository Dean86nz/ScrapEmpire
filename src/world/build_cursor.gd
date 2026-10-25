class_name BuildCursor
extends Node2D
## Rastercursor im Baumodus: Vorschau, Footprint grün/rot, Platzieren, Drehen, Abreißen.
## Eingabe: D-Pad / Pfeiltasten (mit Wiederholung), rechter Stick, Maus. A platziert,
## X dreht, B bricht ab, Y zurück ins Baumenü.

signal menu_requested
signal stopped

enum Mode { OFF, PLACE, DEMOLISH }

const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.08
const STICK_RATE := 0.12
const TILE := 64

var mode: Mode = Mode.OFF
var def: BuildingDef
var rot := 0
var tile := Vector2i.ZERO

var _preview := Sprite2D.new()
var _frame := Polygon2D.new()
var _outline := Line2D.new()
var _repeat_timer := 0.0
var _stick_timer := 0.0
var _last_dir := Vector2i.ZERO


func _ready() -> void:
	z_index = 30
	_preview.modulate.a = 0.6
	_frame.color = Color(0.3, 0.9, 0.4, 0.35)
	_outline.width = 5.0
	_outline.closed = true
	_outline.default_color = Color(0.2, 0.7, 0.3, 1.0)
	add_child(_frame)
	add_child(_outline)
	add_child(_preview)
	visible = false


func start_place(p_def: BuildingDef) -> void:
	def = p_def
	rot = 0
	mode = Mode.PLACE
	_preview.texture = load(def.sprite)
	_preview.visible = true
	_place_in_front()
	visible = true
	InputRouter.context = InputRouter.Context.BUILD


func start_demolish() -> void:
	def = null
	mode = Mode.DEMOLISH
	_preview.visible = false
	_place_in_front()
	visible = true
	InputRouter.context = InputRouter.Context.BUILD


func stop() -> void:
	mode = Mode.OFF
	visible = false
	InputRouter.context = InputRouter.Context.GAME
	stopped.emit()


func _size() -> Vector2i:
	return def.rotated_size(rot) if def != null else Vector2i.ONE


func _place_in_front() -> void:
	var w := SimClock.world
	var player: Player = get_tree().get_first_node_in_group("player")
	var facing := player.facing if player else Vector2.RIGHT
	var dir := Vector2i(roundi(facing.x), roundi(facing.y))
	var s := _size()
	tile = w.player_tile() + dir * 2 - (s - Vector2i.ONE) / 2
	_clamp_tile()


func _clamp_tile() -> void:
	var w := SimClock.world
	var pt := w.player_tile()
	var s := _size()
	var r := SimWorld.BUILD_RANGE_TILES
	tile.x = clampi(tile.x, pt.x - r, pt.x + r - s.x + 1)
	tile.y = clampi(tile.y, pt.y - r, pt.y + r - s.y + 1)
	tile.x = clampi(tile.x, 0, w.width_tiles - s.x)
	tile.y = clampi(tile.y, 0, w.height_tiles - s.y)


func _process(delta: float) -> void:
	if mode == Mode.OFF:
		return
	_handle_movement(delta)
	_clamp_tile()
	_update_visuals()


func _handle_movement(delta: float) -> void:
	# Maus: Cursor folgt der Mauskachel.
	if not InputRouter.is_gamepad:
		var mouse_tile := Vector2i((get_global_mouse_position() / TILE).floor())
		tile = mouse_tile - (_size() - Vector2i.ONE) / 2
	# D-Pad / Pfeiltasten mit Wiederholung.
	var dir := Vector2i(
		int(Input.is_action_pressed("cursor_right")) - int(Input.is_action_pressed("cursor_left")),
		int(Input.is_action_pressed("cursor_down")) - int(Input.is_action_pressed("cursor_up")))
	if dir != Vector2i.ZERO:
		if dir != _last_dir:
			tile += dir
			_repeat_timer = REPEAT_DELAY
		else:
			_repeat_timer -= delta
			if _repeat_timer <= 0.0:
				tile += dir
				_repeat_timer = REPEAT_RATE
	_last_dir = dir
	# Rechter Stick: gleichmäßige Schritte in Stickrichtung.
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.5)
	if stick.length() > 0.5:
		_stick_timer -= delta
		if _stick_timer <= 0.0:
			tile += Vector2i(roundi(stick.x), roundi(stick.y))
			_stick_timer = STICK_RATE
	else:
		_stick_timer = 0.0


func _is_valid() -> bool:
	var w := SimClock.world
	if mode == Mode.DEMOLISH:
		return w.grid.at(tile) != null
	return w.in_build_range(tile, _size()) and w.can_place_def(def, tile, rot) \
		and Economy.can_afford(w.player.inventory, w.next_cost(def))


func _update_visuals() -> void:
	var s := _size()
	var px := Vector2(s * TILE)
	position = Vector2(tile * TILE)
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(px.x, 0), px, Vector2(0, px.y)])
	_frame.polygon = pts
	_outline.points = pts
	var ok := _is_valid()
	_frame.color = Color(0.3, 0.9, 0.4, 0.35) if ok else Color(0.95, 0.3, 0.25, 0.35)
	_outline.default_color = Color(0.2, 0.7, 0.3) if ok else Color(0.85, 0.2, 0.15)
	if mode == Mode.PLACE:
		_preview.position = px / 2.0
		_preview.rotation = rot * PI / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.OFF:
		return
	var w := SimClock.world
	if event.is_action_pressed("interact"):
		if mode == Mode.PLACE:
			w.queue_command({"type": "place", "def_id": def.id, "tile": tile, "rot": rot})
		else:
			w.queue_command({"type": "remove", "tile": tile})
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tool_swap") and mode == Mode.PLACE:
		rot = (rot + 1) % 4
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		stop()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_menu"):
		stop()
		menu_requested.emit()
		get_viewport().set_input_as_handled()
