class_name RustyLook
extends Node2D
## Rustys Ausbau sichtbar: Anbauteile je Skill, in drei Stufen (wenig, halb, voll ausgebaut).
## Hängt als Kind am Sprite und dreht sich mit. Zeichnet zwei Ebenen: unter dem Körper (breitere
## Ketten, Tank, Auspuff) und darüber (Düse, Hammer, Lampen, Lackierung).
## Koordinaten: Sprite-Mitte = (0,0), Rusty blickt nach +X, Körper ca. ±24.

const INK := Color(0.165, 0.165, 0.2)
const ORANGE := Color(0.95, 0.55, 0.16)
const GOLD := Color(0.97, 0.8, 0.3)
const STEEL := Color(0.72, 0.75, 0.78)
const DARK := Color(0.29, 0.29, 0.33)

var levels: Dictionary = {}     # Skill-ID → Stufe
var max_levels: Dictionary = {} # Skill-ID → Höchststufe
var boosting := false
var _under := Node2D.new()
var _over := Node2D.new()
var _t := 0.0


func _ready() -> void:
	_under.show_behind_parent = true
	_under.draw.connect(_draw_under)
	_over.draw.connect(_draw_over)
	add_child(_under)
	add_child(_over)


func set_levels(p_levels: Dictionary, p_max: Dictionary) -> void:
	levels = p_levels.duplicate()
	max_levels = p_max
	_under.queue_redraw()
	_over.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if tier("magnet") >= 3 or boosting:
		_over.queue_redraw()
		_under.queue_redraw()


## 0 = nicht gelernt, 1 = angefangen, 2 = ab der Hälfte, 3 = voll ausgebaut.
func tier(id: String) -> int:
	var l := int(levels.get(id, 0))
	var m := maxi(int(max_levels.get(id, 1)), 1)
	if l <= 0:
		return 0
	if l >= m:
		return 3
	return 2 if l * 2 >= m else 1


func total() -> int:
	var n := 0
	for k in levels:
		n += int(levels[k])
	return n


func _box(ci: Node2D, r: Rect2, fill: Color, radius: int = 6, border: int = 3, edge: Color = INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.draw(ci.get_canvas_item(), r)


# --- unter dem Körper --------------------------------------------------------------
# MS65: ruhig und stimmig statt überladen. Alles bleibt in Körpernähe (±30 px), nichts wird
# mit Reichweite oder Stufe länger; Ausbau zeigt sich über Farbe, Ringe und Glanz.

const STAGE_COLS := [Color(0.95, 0.55, 0.16), Color(0.31, 0.76, 0.69), Color(0.36, 0.55, 1.0), Color(0.85, 0.88, 0.92), Color(1.0, 0.78, 0.24)]


func stage() -> int:
	return clampi(total() / 30, 0, 4)


func _draw_under() -> void:
	var c := _under
	# Ketten (Fahrtempo): etwas breiter, ab voller Stufe mit Goldrand
	var td := tier("drive")
	if td >= 1:
		var w := 52.0 + td * 3.0
		for y in [-30.0, 17.0]:
			_box(c, Rect2(-w * 0.5, y, w, 13), DARK, 6, 3, GOLD if td == 3 else INK)
			for k in range(int(w / 10.0)):
				var x := -w * 0.5 + 5.0 + k * 10.0
				c.draw_line(Vector2(x, y + 3), Vector2(x, y + 10), INK, 2.0)
	# Rucksack (Taschen): kompakt hinten, nie breiter als der Körper
	var tb := tier("bags")
	if tb >= 1:
		var d := 10.0 + tb * 3.0
		_box(c, Rect2(-24 - d, -15, d + 4, 30), STAGE_COLS[stage()].darkened(0.15), 8, 3)
		c.draw_line(Vector2(-24 - d * 0.5, -15), Vector2(-24 - d * 0.5, 15), INK, 2.0)
	# Auspuff (Boost): kleine Rohre hinten
	var bo := int(levels.get("boost", 0))
	for i in mini(bo, 2):
		var y := -6.0 + i * 12.0 if bo > 1 else 0.0
		_box(c, Rect2(-40, y - 3, 8, 6), STEEL, 2, 2)
		if boosting:
			var f := 7.0 + 4.0 * sin(_t * 30.0 + i)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-40, y - 3), Vector2(-40 - f, y), Vector2(-40, y + 3)]), Color(1.0, 0.6, 0.2))


# --- über dem Körper ------------------------------------------------------------------

func _draw_over() -> void:
	var c := _over
	var st := stage()
	# Ausbaustufe: Farbplakette auf dem Rücken mit Stufenpunkten
	if st > 0:
		_box(c, Rect2(-20, -12, 10, 24), STAGE_COLS[st], 4, 2)
		for k in st:
			c.draw_circle(Vector2(-15, -7 + k * 4.7), 1.6, INK)
	# Saugtrichter vorne: kurz und fest, Ring in der Stufenfarbe
	var ts := tier("suck")
	if ts > 0:
		var x0 := 22.0
		var len := 9.0 + ts * 2.0
		var mouth := 9.0 + ts * 2.5
		var poly := PackedVector2Array([Vector2(x0, -6), Vector2(x0 + len, -mouth), Vector2(x0 + len, mouth), Vector2(x0, 6)])
		c.draw_colored_polygon(poly, STEEL)
		poly.append(poly[0])
		c.draw_polyline(poly, INK, 2.5)
		c.draw_line(Vector2(x0 + len, -mouth), Vector2(x0 + len, mouth), STAGE_COLS[st] if st > 0 else ORANGE, 4.0)
	# Scheinwerfer (Magnet): höchstens zwei kleine Lichter vorne
	var tm := tier("magnet")
	for i in mini(tm, 2):
		var at := Vector2(16, -14 if i == 0 else 14)
		if tm >= 3:
			c.draw_circle(at, 7.0, Color(1.0, 0.95, 0.5, 0.25 + 0.15 * sin(_t * 4.0 + i)))
		c.draw_circle(at, 3.5, Color(1.0, 0.92, 0.45))
		c.draw_arc(at, 3.5, 0.0, TAU, 14, INK, 1.5)


func _star(c: Node2D, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	c.draw_polyline(pts, INK, 1.5)
