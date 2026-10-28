class_name NavGrid
extends RefCounted
## Wegfindung für Bots (MS48): AStarGrid2D über die Zaun-Kacheln (`SimWorld.blocked_tiles`).
## Wird nur neu aufgebaut, wenn sich Zäune/Tore ändern (`blocked_version`). Freie Sichtlinie =
## direkter Weg ohne A* (häufigster Fall, kostet fast nichts).

const TILE := 64

var _astar := AStarGrid2D.new()
var _version := -1
var _size := Vector2i.ZERO


func _ensure(w: SimWorld) -> void:
	var size := Vector2i(w.width_tiles, w.height_tiles)
	if _version == w.blocked_version and _size == size:
		return
	_version = w.blocked_version
	_size = size
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for t: Vector2i in w.blocked_tiles.keys():
		if _astar.is_in_boundsv(t):
			_astar.set_point_solid(t, true)


## Kein Zaun zwischen a und b (Pixel)? Prüft alle halbe Kachel entlang der Linie.
func line_clear(w: SimWorld, a: Vector2i, b: Vector2i) -> bool:
	if w.blocked_tiles.is_empty():
		return true
	var d := Vector2(b - a)
	var steps := int(d.length() / (TILE * 0.5)) + 1
	for i in steps + 1:
		var p := Vector2(a) + d * (float(i) / steps)
		if w.blocked_tiles.has(Vector2i(floori(p.x / TILE), floori(p.y / TILE))):
			return false
	return true


## Wegpunkte (Pixel, Kachelmitten) von a nach b um Zäune herum; letzter Punkt ist b selbst.
## Leer, wenn kein Weg existiert.
func path(w: SimWorld, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	_ensure(w)
	var out: Array[Vector2i] = []
	var from := Vector2i(clampi(a.x / TILE, 0, _size.x - 1), clampi(a.y / TILE, 0, _size.y - 1))
	var to := Vector2i(clampi(b.x / TILE, 0, _size.x - 1), clampi(b.y / TILE, 0, _size.y - 1))
	if _astar.is_point_solid(from) or _astar.is_point_solid(to):
		return out
	var ids := _astar.get_id_path(from, to)
	for i in range(1, ids.size()):
		out.append(ids[i] * TILE + Vector2i(TILE / 2, TILE / 2))
	if not out.is_empty():
		out[out.size() - 1] = b
	return out
