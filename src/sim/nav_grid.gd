class_name NavGrid
extends RefCounted
## Wegfindung für Bots: AStarGrid2D über alle Hindernisse (MS61): Zäune (`blocked_tiles`),
## Müllobjekte (`_node_tiles`), Gebäude, Schiff und Sammelstellen (`grid`). Voller Neuaufbau nur bei
## Zaun-/Tor-Änderungen oder neuer Kartengröße, sonst werden nur geänderte Kacheln nachgeführt.
## Freie Sichtlinie = direkter Weg ohne A* (häufigster Fall).

const TILE := 64
const BODY_HALF := 20.0   # halbe Bot-Breite für die Sichtlinie

var _astar := AStarGrid2D.new()
var _version := -1
var _size := Vector2i.ZERO


static func is_obstacle(w: SimWorld, t: Vector2i) -> bool:
	return w.blocked_tiles.has(t) or w._node_block.has(t) or w.grid.at(t) != null


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
	# Mit Körperbreite prüfen (MS70): Mittellinie und zwei Ränder, sonst schneiden Bots Ecken
	var side := d.orthogonal().normalized() * BODY_HALF if d.length() > 0.0 else Vector2.ZERO
	for off in [Vector2.ZERO, side, -side]:
		for i in steps + 1:
			var p: Vector2 = Vector2(a) + d * (float(i) / steps) + off
			var t := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
			if t != ta and t != tb and is_obstacle(w, t) and not _is_target_footprint(w, t, tb):
				return false
	return true


static func _is_target_footprint(w: SimWorld, t: Vector2i, target_tile: Vector2i) -> bool:
	var id: int = w._node_tiles.get(target_tile, -1)
	if id >= 0 and w.nodes.has(id) and (w.nodes[id] as ResourceNode).footprint().has(t):
		return true
	var b := w.grid.at(target_tile)   # Ziel ist ein Gebäude (Schiff, Sammelstelle): seine Fläche zählt mit
	return b != null and w.grid.at(t) == b


## Wegpunkte (Pixel, Kachelmitten) von a nach b um Hindernisse herum; letzter Punkt ist b selbst.
## Start und Ziel dürfen selbst belegt sein (Bot steht schief, Ziel ist ein Objekt). Leer = kein Weg.
func path(w: SimWorld, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	_ensure(w)
	var out: Array[Vector2i] = []
	var from := Vector2i(clampi(a.x / TILE, 0, _size.x - 1), clampi(a.y / TILE, 0, _size.y - 1))
	var to := Vector2i(clampi(b.x / TILE, 0, _size.x - 1), clampi(b.y / TILE, 0, _size.y - 1))
	# Start und Ziel (samt Grundfläche des Ziel-Objekts) kurz freigeben
	var opened: Array[Vector2i] = [from, to]
	var target_id: int = w._node_tiles.get(to, -1)
	if target_id >= 0 and w.nodes.has(target_id):
		opened.append_array((w.nodes[target_id] as ResourceNode).footprint())
	var tb := w.grid.at(to)
	if tb != null:
		opened.append_array(tb.cells())
	var was: Array[bool] = []
	for t in opened:
		var inside := _astar.is_in_boundsv(t)
		was.append(inside and _astar.is_point_solid(t))
		if inside:
			_astar.set_point_solid(t, false)
	var ids := _astar.get_id_path(from, to)
	for k in opened.size():
		if _astar.is_in_boundsv(opened[k]):
			_astar.set_point_solid(opened[k], was[k])
	for i in range(1, ids.size()):
		out.append(ids[i] * TILE + Vector2i(TILE / 2, TILE / 2))
	if not out.is_empty():
		out[out.size() - 1] = b
	return out
