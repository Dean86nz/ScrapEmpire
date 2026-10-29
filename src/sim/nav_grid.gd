class_name NavGrid
extends RefCounted
## Wegfindung für Bots: AStarGrid2D über alle Hindernisse (MS61): Zäune (`blocked_tiles`),
## Müllobjekte (`_node_tiles`), Gebäude, Schiff und Sammelstellen (`grid`). Voller Neuaufbau nur bei
## Zaun-/Tor-Änderungen oder neuer Kartengröße, sonst werden nur geänderte Kacheln nachgeführt.
## Freie Sichtlinie = direkter Weg ohne A* (häufigster Fall).

const TILE := 64

var _astar := AStarGrid2D.new()
var _version := -1
var _size := Vector2i.ZERO


static func is_obstacle(w: SimWorld, t: Vector2i) -> bool:
	return w.blocked_tiles.has(t) or w._node_tiles.has(t) or w.grid.at(t) != null


func _ensure(w: SimWorld) -> void:
	var size := Vector2i(w.width_tiles, w.height_tiles)
	if _version != w.blocked_version or _size != size:
		_version = w.blocked_version
		_size = size
		_astar.region = Rect2i(Vector2i.ZERO, size)
		_astar.cell_size = Vector2.ONE
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.update()
		for y in size.y:
			for x in size.x:
				var t := Vector2i(x, y)
				if is_obstacle(w, t):
					_astar.set_point_solid(t, true)
		w.nav_changes.clear()
		w.grid.changed.clear()
		return
	for t in w.nav_changes:
		if _astar.is_in_boundsv(t):
			_astar.set_point_solid(t, is_obstacle(w, t))
	for t in w.grid.changed:
		if _astar.is_in_boundsv(t):
			_astar.set_point_solid(t, is_obstacle(w, t))
	w.nav_changes.clear()
	w.grid.changed.clear()


## Kein Hindernis zwischen a und b (Pixel)? Start- und Zielkachel zählen nicht (dort steht der Bot
## bzw. liegt das Objekt, an dem er arbeiten will).
func line_clear(w: SimWorld, a: Vector2i, b: Vector2i) -> bool:
	var ta := Vector2i(floori(a.x / float(TILE)), floori(a.y / float(TILE)))
	var tb := Vector2i(floori(b.x / float(TILE)), floori(b.y / float(TILE)))
	var d := Vector2(b - a)
	var steps := int(d.length() / (TILE * 0.5)) + 1
	for i in steps + 1:
		var p := Vector2(a) + d * (float(i) / steps)
		var t := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
		if t != ta and t != tb and is_obstacle(w, t):
			return false
	return true


## Wegpunkte (Pixel, Kachelmitten) von a nach b um Hindernisse herum; letzter Punkt ist b selbst.
## Start und Ziel dürfen selbst belegt sein (Bot steht schief, Ziel ist ein Objekt). Leer = kein Weg.
func path(w: SimWorld, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	_ensure(w)
	var out: Array[Vector2i] = []
	var from := Vector2i(clampi(a.x / TILE, 0, _size.x - 1), clampi(a.y / TILE, 0, _size.y - 1))
	var to := Vector2i(clampi(b.x / TILE, 0, _size.x - 1), clampi(b.y / TILE, 0, _size.y - 1))
	var from_solid := _astar.is_point_solid(from)
	var to_solid := _astar.is_point_solid(to)
	_astar.set_point_solid(from, false)
	_astar.set_point_solid(to, false)
	var ids := _astar.get_id_path(from, to)
	_astar.set_point_solid(from, from_solid)
	_astar.set_point_solid(to, to_solid)
	for i in range(1, ids.size()):
		out.append(ids[i] * TILE + Vector2i(TILE / 2, TILE / 2))
	if not out.is_empty():
		out[out.size() - 1] = b
	return out
