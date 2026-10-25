class_name Minimap
extends Control
## Minimap unten rechts (GDD Kap. 24): Zonen in Stufenfarbe, Müll-Punkte, Gebäude, Rusty.
## Zeichnet sich alle 0,5 s neu. Ausblendbar (Select lang / M).

const STAGE_COLORS := [Color(0.55, 0.42, 0.28), Color(0.62, 0.6, 0.55), Color(0.72, 0.85, 0.5), Color(0.42, 0.78, 0.4)]
const REFRESH := 0.5

var _world: SimWorld
var _player: Node2D
var _timer := 0.0
var _summary: Array[Dictionary] = []


func bind(world: SimWorld, player: Node2D) -> void:
	_world = world
	_player = player
	_summary = world.zones.summary(world.nodes)
	queue_redraw()


func _process(delta: float) -> void:
	if _world == null or not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_summary = _world.zones.summary(_world.nodes)
	queue_redraw()


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
	# Müll-Objekte (nur in entdeckten Zonen)
	for n: ResourceNode in _world.nodes.values():
		if n.is_wreck() and not n.is_resource() and _world.zones.is_unlocked(_world.zones.zone_id_at(n.tile)):
			draw_circle(Vector2(n.tile) * s + Vector2(s, s) * 0.5, maxf(s * 0.6, 1.5), Color(0.3, 0.25, 0.2))
	# Gebäude
	for b: Building in _world.buildings.values():
		var r := b.rect_px()
		draw_rect(Rect2(Vector2(r.position) / 64.0 * s, Vector2(r.size) / 64.0 * s), Color(0.95, 0.55, 0.16))
	# Rusty
	if _player:
		var p := _player.global_position / 64.0 * s
		var dir: Vector2 = (_player as Player).facing if _player is Player else Vector2.RIGHT
		var tri := PackedVector2Array([p + dir * 7.0, p + dir.rotated(2.5) * 5.0, p + dir.rotated(-2.5) * 5.0])
		draw_colored_polygon(tri, Color(1, 1, 1))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.165, 0.165, 0.2), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.165, 0.165, 0.2), false, 4.0)
