class_name Minimap
extends Control
## Minimap unten rechts (GDD Kap. 24): Zonen in Stufenfarbe, Müll-Punkte, Gebäude, Rusty.
## Zeichnet sich alle 0,5 s neu. Ausblendbar (Select lang / M).

const STAGE_COLORS := [Color(0.55, 0.42, 0.28), Color(0.62, 0.6, 0.55), Color(0.72, 0.85, 0.5), Color(0.42, 0.78, 0.4)]
const REFRESH := 0.5

var _marker: Control
var _world: SimWorld
var _player: Node2D
var _timer := 0.0
var _summary: Array[Dictionary] = []
var dirt_texture: Texture2D           # Schmutz je Kachel (von DirtView)


func bind(world: SimWorld, player: Node2D) -> void:
	_world = world
	_player = player
	_summary = world.zones.summary(world.nodes)
	queue_redraw()


## Leistung (MS64): Die Karte (Zonen, Müll, Gebäude) wird nur alle REFRESH Sekunden neu
## gezeichnet; nur Rustys Pfeil bewegt sich jedes Bild auf einer eigenen kleinen Ebene.
func _process(delta: float) -> void:
	if _world == null or not visible:
		return
	if _marker == null:
		_marker = Control.new()
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_marker.draw.connect(_draw_marker)
		add_child(_marker)
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_summary = _world.zones.summary(_world.nodes)
		queue_redraw()
	_marker.queue_redraw()


func _scale() -> float:
	return minf(size.x / float(_world.width_tiles), size.y / float(_world.height_tiles))


func _draw() -> void:
	if _world == null:
		return
	var s := _scale()
	# Rahmen und Hintergrund
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.165, 0.165, 0.2, 0.85))
	var font := ThemeDB.fallback_font
	for z in _summary:
		var r: Rect2i = z["rect"]
		var rect := Rect2(Vector2(r.position) * s, Vector2(r.size) * s)
		if not _world.zones.is_unlocked(str(z["id"])):
			draw_rect(rect, Color(0.25, 0.25, 0.3))
			draw_string(font, rect.position + rect.size * 0.5 + Vector2(-7, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.7, 0.75))
			draw_rect(rect, Color(0.165, 0.165, 0.2), false, 1.0)
			continue
		var col: Color = STAGE_COLORS[int(z["stage"])]
		draw_rect(rect, col)
		draw_rect(rect, Color(0.165, 0.165, 0.2), false, 1.0)
	if dirt_texture != null:
		for z in _summary:
			if _world.zones.is_unlocked(str(z["id"])):
				var r: Rect2i = z["rect"]
				draw_texture_rect_region(dirt_texture, Rect2(Vector2(r.position) * s, Vector2(r.size) * s), Rect2(r.position, r.size))
	# Müll-Objekte (nur in entdeckten Zonen); Zonenprüfung über die Rechtecke, nicht je Objekt suchen
	var open_rects: Array[Rect2i] = []
	for z in _summary:
		if _world.zones.is_unlocked(str(z["id"])):
			open_rects.append(z["rect"])
	var dot := maxf(s * 1.1, 2.0)
	for n: ResourceNode in _world.nodes.values():
		if not n.is_wreck() or n.is_resource():
			continue
		for r in open_rects:
			if r.has_point(n.tile):
				draw_rect(Rect2(Vector2(n.tile) * s, Vector2(dot, dot)), Color(0.3, 0.25, 0.2))
				break
	# Gebäude
	for b: Building in _world.buildings.values():
		var r := b.rect_px()
		draw_rect(Rect2(Vector2(r.position) / 64.0 * s, Vector2(r.size) / 64.0 * s), Color(0.95, 0.55, 0.16))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.165, 0.165, 0.2), false, 4.0)


func _draw_marker() -> void:
	var s := _scale()
	# Rusty
	if _player:
		var p := _player.global_position / 64.0 * s
		var dir: Vector2 = (_player as Player).facing if _player is Player else Vector2.RIGHT
		var tri := PackedVector2Array([p + dir * 7.0, p + dir.rotated(2.5) * 5.0, p + dir.rotated(-2.5) * 5.0])
		_marker.draw_colored_polygon(tri, Color(1, 1, 1))
		_marker.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.165, 0.165, 0.2), 1.5)
