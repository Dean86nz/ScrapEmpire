class_name SiteView
extends Node2D
## Fester Bauplatz für die Sammelstelle (MS41): Betonplatte mit gestricheltem Rand, Schild mit
## Recycling-Pfeil und Preis. Pulsiert, wenn Rusty davor steht; verschwindet, sobald gebaut ist.

const TILE := 64
const SIZE := Vector2(128, 128)
const PAD := Color(0.78, 0.76, 0.7, 0.85)
const EDGE := Color(1.0, 0.82, 0.25)
const INK := Color(0.165, 0.165, 0.2)

var _world: SimWorld
var _zone_id := ""
var _site := Vector2i.ZERO
var _time := 0.0
var _near := false


func setup(world: SimWorld, zone_id: String, site: Vector2i) -> void:
	_world = world
	_zone_id = zone_id
	_site = site
	position = Vector2(site * TILE)
	z_index = -6


func _process(delta: float) -> void:
	var show := _world.zones.is_unlocked(_zone_id) and _world.grid.at(_site) == null
	visible = show
	if not show:
		return
	_time += delta
	_near = NetworkSystem.site_near_player(_world) == _zone_id
	queue_redraw()


func _draw() -> void:
	var open := _world.is_building_unlocked(NetworkSystem.POINT_DEF)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0) if _near else 0.0
	draw_rect(Rect2(Vector2(4, 4), SIZE - Vector2(8, 8)), PAD if open else Color(0.6, 0.6, 0.62, 0.6))
	# gestrichelter Rand
	var edge := EDGE.lerp(Color.WHITE, pulse * 0.6) if open else Color(0.45, 0.45, 0.5)
	var w := 5.0 + pulse * 3.0
	var r := Rect2(Vector2(4, 4), SIZE - Vector2(8, 8))
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := 6
		for k in n:
			var t0 := float(k) / n
			draw_line(a.lerp(b, t0), a.lerp(b, t0 + 0.6 / n), edge, w, true)
	# Recycling-Kreis in der Mitte
	var c := SIZE * 0.5
	for k in 3:
		var a0 := TAU * k / 3.0 + _time * (0.8 if open else 0.0)
		draw_arc(c, 30, a0, a0 + TAU / 3.0 - 0.5, 12, edge, 6, true)
		var tip := c + Vector2.from_angle(a0 + TAU / 3.0 - 0.5) * 30
		draw_circle(tip, 6, edge)
	# Schild mit Preis bzw. Schloss
	var font := ThemeDB.fallback_font
	var txt: String
	if open:
		txt = "%s ⚙" % Fmt.int_str(int(_world.next_cost(_world.defs[NetworkSystem.POINT_DEF]).get("bolts", 0)))
	else:
		txt = "🔒"
	var fs := 24
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sign := Rect2(Vector2(c.x - tw * 0.5 - 12, -40), Vector2(tw + 24, 36))
	draw_rect(sign, Color(0.98, 0.93, 0.78))
	draw_rect(sign, INK, false, 3)
	draw_string(font, sign.position + Vector2(12, 27), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
