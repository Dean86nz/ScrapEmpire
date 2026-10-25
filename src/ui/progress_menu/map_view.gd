class_name MapView
extends Control
## Große Karte (Tab „Karte“): Zonen mit Namen und Reinigungsgrad, Rusty, Gebäude, Müll.
## D-Pad wählt eine Zone (3×3), LT/RT zoomen, rechter Stick scrollt bei Zoom.

signal zone_selected(info: Dictionary)

const STAGE_COLORS := Minimap.STAGE_COLORS
const ZOOMS := [1.0, 2.0, 3.0]

var _world: SimWorld
var _player: Node2D
var _summary: Array[Dictionary] = []
var _selected := 0
var _initial_done := false
var _zoom_index := 0
var _offset := Vector2.ZERO
var _timer := 0.0


func bind(world: SimWorld, player: Node2D) -> void:
	_world = world
	_player = player
	refresh()


func refresh() -> void:
	if _world == null:
		return
	_summary = _world.zones.summary(_world.nodes)
	if _selected >= _summary.size():
		_selected = 0
	if not _initial_done:
		_initial_done = true
		var cur := _world.zones.current_chapter_zone()
		for i in _summary.size():
			if str(_summary[i]["id"]) == cur:
				_selected = i
	if not _summary.is_empty():
		zone_selected.emit(_summary[_selected])
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or _world == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		refresh()
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.3)
	if stick.length() > 0.0 and _zoom_index > 0:
		_offset -= stick * 600.0 * delta
		_clamp_offset()
		queue_redraw()


func _base_scale() -> float:
	return minf(size.x / float(_world.width_tiles), size.y / float(_world.height_tiles))


func _scale() -> float:
	return _base_scale() * float(ZOOMS[_zoom_index])


func _clamp_offset() -> void:
	var s := _scale()
	var map_px := Vector2(_world.width_tiles, _world.height_tiles) * s
	_offset.x = clampf(_offset.x, minf(size.x - map_px.x, 0.0), 0.0)
	_offset.y = clampf(_offset.y, minf(size.y - map_px.y, 0.0), 0.0)


func handle_input(event: InputEvent) -> bool:
	if _summary.is_empty():
		return false
	var cols := 3
	var moved := false
	if event.is_action_pressed("ui_right"):
		_selected = mini(_selected + 1, _summary.size() - 1)
		moved = true
	elif event.is_action_pressed("ui_left"):
		_selected = maxi(_selected - 1, 0)
		moved = true
	elif event.is_action_pressed("ui_down"):
		_selected = mini(_selected + cols, _summary.size() - 1)
		moved = true
	elif event.is_action_pressed("ui_up"):
		_selected = maxi(_selected - cols, 0)
		moved = true
	elif event.is_action_pressed("tool_primary"):
		_zoom_index = mini(_zoom_index + 1, ZOOMS.size() - 1)
		_center_on_selected()
		moved = true
	elif event.is_action_pressed("tool_secondary"):
		_zoom_index = maxi(_zoom_index - 1, 0)
		_center_on_selected()
		moved = true
	if moved:
		if _zoom_index > 0:
			_center_on_selected()
		zone_selected.emit(_summary[_selected])
		queue_redraw()
	return moved


func _center_on_selected() -> void:
	var r: Rect2i = _summary[_selected]["rect"]
	var s := _scale()
	var center := (Vector2(r.position) + Vector2(r.size) * 0.5) * s
	_offset = size * 0.5 - center
	_clamp_offset()


func _draw() -> void:
	if _world == null:
		return
	var s := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.165, 0.165, 0.2, 0.9))
	var font := ThemeDB.fallback_font
	for i in _summary.size():
		var z := _summary[i]
		var r: Rect2i = z["rect"]
		var rect := Rect2(_offset + Vector2(r.position) * s, Vector2(r.size) * s)
		var known := _world.zones.is_unlocked(str(z["id"]))
		draw_rect(rect, STAGE_COLORS[int(z["stage"])] if known else Color(0.25, 0.25, 0.3))
		draw_rect(rect, Color(0.95, 0.55, 0.16) if i == _selected else Color(0.165, 0.165, 0.2), false, 6.0 if i == _selected else 2.0)
		var label := ("%s  %d %%" % [z["name"], int(round(float(z["cleanliness"]) * 100.0))]) if known else ("%s %d" % [tr("CH_CHAPTER"), _world.zones.chapter_index(str(z["id"])) + 1])
		draw_string(font, rect.position + Vector2(10, 30), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 22, Color(0.165, 0.165, 0.2) if known else Color(0.75, 0.75, 0.8))
		if not known:
			draw_string(font, rect.position + rect.size * 0.5 + Vector2(-14, 16), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.7, 0.7, 0.75))
	for n: ResourceNode in _world.nodes.values():
		if n.is_wreck() and not n.is_resource() and _world.zones.is_unlocked(_world.zones.zone_id_at(n.tile)):
			draw_circle(_offset + (Vector2(n.tile) + Vector2(0.5, 0.5)) * s, maxf(s * 0.5, 2.0), Color(0.3, 0.25, 0.2))
	# Legende unten: vier Farbfelder
	var ly := size.y - 30.0
	var lx := 10.0
	draw_rect(Rect2(0, ly - 8, size.x, 42), Color(1.0, 0.96, 0.8, 0.95))
	draw_string(font, Vector2(lx, ly + 18), tr("MAP_LEGEND"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.165, 0.165, 0.2))
	lx += 110.0
	for i in 4:
		draw_rect(Rect2(lx, ly, 26, 26), STAGE_COLORS[i])
		draw_rect(Rect2(lx, ly, 26, 26), Color(0.165, 0.165, 0.2), false, 2.0)
		var label := tr("ZONE_STAGE_%d" % i).split(":")[-1].strip_edges().split(" ")[0]
		draw_string(font, Vector2(lx + 32, ly + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.165, 0.165, 0.2))
		lx += 32 + 150.0
	for b: Building in _world.buildings.values():
		var br := b.rect_px()
		draw_rect(Rect2(_offset + Vector2(br.position) / 64.0 * s, Vector2(br.size) / 64.0 * s), Color(0.95, 0.55, 0.16))
	if _player:
		var p := _offset + _player.global_position / 64.0 * s
		draw_circle(p, 9.0, Color(0.165, 0.165, 0.2))
		draw_circle(p, 6.0, Color(1, 1, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.165, 0.165, 0.2), false, 4.0)
