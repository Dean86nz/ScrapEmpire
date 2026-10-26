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

func _draw_under() -> void:
	var c := _under
	# Ketten (Fahrtempo): breiter, gestreift, golden gerandet
	var td := tier("drive")
	if td >= 2:
		var w := 58.0 if td == 2 else 64.0
		var h := 16.0 if td == 2 else 19.0
		for y in [-28.0, 28.0 - h + 2.0]:
			var r := Rect2(-w * 0.5, y, w, h)
			_box(c, r, DARK, 8, 3, GOLD if td == 3 else INK)
			for k in range(int(w / 9.0)):
				var x := -w * 0.5 + 5.0 + k * 9.0
				c.draw_line(Vector2(x, y + 3), Vector2(x, y + h - 3), INK, 2.0)
	# Tank / Rucksack (Taschen) hinten
	var tb := tier("bags")
	if tb == 1:
		_box(c, Rect2(-40, -11, 16, 22), Color(0.6, 0.42, 0.25), 4)
	elif tb == 2:
		_box(c, Rect2(-46, -16, 24, 32), Color(0.35, 0.7, 0.4), 10)
		c.draw_line(Vector2(-40, -16), Vector2(-40, 16), INK, 3.0)
		c.draw_line(Vector2(-30, -16), Vector2(-30, 16), INK, 3.0)
	elif tb == 3:
		_box(c, Rect2(-54, -21, 32, 42), Color(0.3, 0.68, 0.38), 14)
		for x in [-48.0, -36.0]:
			c.draw_line(Vector2(x, -21), Vector2(x, 21), GOLD, 4.0)
		c.draw_circle(Vector2(-42, 0), 6.0, Color.WHITE)
		c.draw_arc(Vector2(-42, 0), 6.0, 0.0, TAU, 20, INK, 2.0)
		c.draw_line(Vector2(-42, 0), Vector2(-39, -3), Color(0.85, 0.2, 0.2), 2.0)
	# Auspuff (Boost)
	var bo := int(levels.get("boost", 0))
	for i in bo:
		var y := -8.0 + i * 8.0 if bo > 1 else 0.0
		var x0 := -26.0 - (8.0 if tb >= 2 else 0.0)
		_box(c, Rect2(x0 - 12, y - 3, 14, 6), STEEL, 3, 2)
		if boosting:
			var f := 8.0 + 5.0 * sin(_t * 30.0 + i)
			c.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 12, y - 3), Vector2(x0 - 12 - f, y), Vector2(x0 - 12, y + 3)]), Color(1.0, 0.6, 0.2))


# --- über dem Körper ------------------------------------------------------------------

func _draw_over() -> void:
	var c := _over
	# Lackierung: Rennstreifen ab 12 Skill-Stufen, Stern ab 28
	var n := total()
	if n >= 12:
		c.draw_line(Vector2(-22, -3), Vector2(0, -3), Color(1, 1, 1, 0.9), 4.0)
		c.draw_line(Vector2(-22, 3), Vector2(0, 3), Color(0.3, 0.6, 0.95, 0.95), 4.0)
	if n >= 28:
		_star(c, Vector2(-10, -13), 6.0, GOLD)
	# Saugdüse vorne (Saugtempo), länger mit Reichweite
	var ts := tier("suck")
	var reach := int(levels.get("reach", 0))
	if ts > 0:
		var len := 8.0 + ts * 4.0 + reach * 2.5
		var mouth := 7.0 + ts * 3.0
		var x0 := 22.0
		var poly := PackedVector2Array([Vector2(x0, -5), Vector2(x0 + len, -mouth), Vector2(x0 + len, mouth), Vector2(x0, 5)])
		var col := STEEL if ts < 3 else Color(0.85, 0.9, 0.95)
		c.draw_colored_polygon(poly, col)
		poly.append(poly[0])
		c.draw_polyline(poly, INK, 2.5)
		c.draw_line(Vector2(x0 + len, -mouth), Vector2(x0 + len, mouth), ORANGE if ts == 2 else (Color(0.3, 0.75, 1.0) if ts == 3 else INK), 4.0)
	# Hammer (Werkzeug) oben auf der Schulter
	var tt := int(levels.get("tool", 0))
	if tt > 0:
		var head := Color(0.6, 0.62, 0.66) if tt == 1 else (STEEL if tt == 2 else GOLD)
		var size := 10.0 + tt * 3.0
		var top := Vector2(-6, -40)
		c.draw_line(Vector2(-16, -12), top, INK, 7.0)
		c.draw_line(Vector2(-16, -12), top, Color(0.75, 0.5, 0.25), 4.0)
		_box(c, Rect2(top.x - size * 0.75, top.y - size * 0.5, size * 1.5, size), head, 3, 2)
	# Lampen (Magnet): 1 bis 3 Lichter, voll ausgebaut leuchten sie pulsierend
	var tm := int(levels.get("magnet", 0))
	var spots := [Vector2(14, -16), Vector2(14, 16), Vector2(2, -20)]
	for i in mini(tm, 3):
		var glow := 0.5 + 0.5 * sin(_t * 4.0 + i) if tier("magnet") >= 3 else 0.0
		if glow > 0.0:
			c.draw_circle(spots[i], 9.0, Color(1.0, 0.95, 0.5, 0.25 * glow))
		c.draw_circle(spots[i], 4.5, Color(1.0, 0.92, 0.45))
		c.draw_arc(spots[i], 4.5, 0.0, TAU, 16, INK, 2.0)


func _star(c: Node2D, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	c.draw_polyline(pts, INK, 1.5)
