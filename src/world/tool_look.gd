class_name ToolLook
extends RefCounted
## Werkzeug-Leiter (MS74): ersetzt den Hammer. Stufe 1–5: Pömpel, Greifzange, Magnetkran,
## Schrottpresse, Laser. Liefert Bild, Ton, Benutz-Animation und Treffer-Effekt je Stufe für Rusty
## und die Bots. Nur Darstellung; die Sim kennt weiter nur `hammer_tier`.

const NAME_KEYS := ["TOOL_1", "TOOL_2", "TOOL_3", "TOOL_4", "TOOL_5"]
const COLORS := [Color(0.91, 0.27, 0.24), Color(0.3, 0.69, 0.24), Color(0.95, 0.55, 0.16), Color(0.36, 0.55, 1.0), Color(1.0, 0.35, 0.85)]

static var _tex: Array[Texture2D] = []


static func tier_of(tier: int) -> int:
	return clampi(tier, 1, 5)


static func texture(tier: int) -> Texture2D:
	if _tex.is_empty():
		for i in 5:
			_tex.append(load("res://assets/sprites/tools/tool_%d.svg" % (i + 1)))
	return _tex[tier_of(tier) - 1]


static func sound(tier: int) -> String:
	return "tool%d" % tier_of(tier)


static func name_key(tier: int) -> String:
	return NAME_KEYS[tier_of(tier) - 1]


## Benutz-Animation am Werkzeug-Bild (Ruhelage `rest`, Größe `size`) je Stufe:
## Pömpel stößt vor und quetscht, Zange kneift zu, Magnet senkt sich, Presse stampft, Laser ruckt zurück.
static func animate_use(spr: Node2D, tier: int, rest: Vector2, size: Vector2) -> Tween:
	var tw := spr.create_tween()
	spr.position = rest
	spr.scale = size
	spr.rotation = 0.0
	match tier_of(tier):
		1:
			tw.tween_property(spr, "position", rest + Vector2(22, 0), 0.07).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(spr, "scale", size * Vector2(0.8, 1.15), 0.07)
			tw.tween_property(spr, "position", rest, 0.14).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(spr, "scale", size, 0.14).set_trans(Tween.TRANS_BACK)
		2:
			tw.tween_property(spr, "position", rest + Vector2(14, 0), 0.06)
			tw.tween_property(spr, "scale", size * Vector2(1.05, 0.55), 0.05)
			tw.tween_property(spr, "scale", size, 0.12).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(spr, "position", rest, 0.12)
		3:
			tw.tween_property(spr, "position", rest + Vector2(6, 8), 0.08).set_ease(Tween.EASE_IN)
			tw.tween_property(spr, "rotation", 0.12, 0.05)
			tw.tween_property(spr, "rotation", -0.08, 0.06)
			tw.tween_property(spr, "position", rest, 0.14).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(spr, "rotation", 0.0, 0.14)
		4:
			tw.tween_property(spr, "scale", size * Vector2(1.12, 0.72), 0.06).set_ease(Tween.EASE_IN)
			tw.tween_property(spr, "scale", size, 0.18).set_trans(Tween.TRANS_ELASTIC)
		_:
			tw.tween_property(spr, "position", rest - Vector2(10, 0), 0.04)
			tw.parallel().tween_property(spr, "modulate", Color(1.6, 1.3, 1.6), 0.04)
			tw.tween_property(spr, "position", rest, 0.16).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(spr, "modulate", Color.WHITE, 0.16)
	return tw


## Treffer-Effekt im Welt-Knoten `parent` am Ziel `at`; `from` = wo das Werkzeug ist (Laserstrahl).
static func impact_fx(parent: Node2D, tier: int, at: Vector2, from: Vector2, k := 1.0) -> void:
	var fx := Node2D.new()
	fx.position = at
	fx.scale = Vector2(k, k)
	fx.z_index = 12
	parent.add_child(fx)
	var col: Color = COLORS[tier_of(tier) - 1]
	match tier_of(tier):
		1:  # „Plopp“: zwei flache gelbe Ringe
			for i in 2:
				fx.add_child(_arc_line(Vector2.ZERO, 40.0 + 30.0 * i, 0.0, TAU, Color(1.0, 0.78, 0.24, 0.9 - 0.4 * i), 7.0, Vector2(1.0, 0.4)))
		2:  # Zwicken: vier Striche von außen nach innen
			for s in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
				var l := Line2D.new()
				l.points = PackedVector2Array([s * 70.0, s * 44.0])
				l.width = 6.0
				l.default_color = Color(0.165, 0.165, 0.2)
				l.begin_cap_mode = Line2D.LINE_CAP_ROUND
				l.end_cap_mode = Line2D.LINE_CAP_ROUND
				fx.add_child(l)
		3:  # Magnetfeld: drei türkise Bögen, Teile hüpfen hoch
			for i in 3:
				fx.add_child(_arc_line(Vector2(0, -30), 40.0 + 28.0 * i, 0.2, PI - 0.2, Color(0.49, 0.99, 1.0, 0.9 - 0.25 * i), 5.0, Vector2.ONE))
		4:  # Pressen: gelbe Seitenstriche
			for sx in [-1.0, 1.0]:
				for dy in [-18.0, 18.0]:
					var l := Line2D.new()
					l.points = PackedVector2Array([Vector2(sx * 60.0, dy), Vector2(sx * 96.0, dy * 1.6)])
					l.width = 7.0
					l.default_color = Color(1.0, 0.78, 0.24)
					fx.add_child(l)
		_:  # Laserstrahl von Rusty bzw. Bot zum Ziel, Glutpunkt
			var glow := Line2D.new()
			glow.points = PackedVector2Array([(from - at) / k, Vector2.ZERO])
			glow.width = 22.0
			glow.default_color = Color(col, 0.55)
			glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
			glow.end_cap_mode = Line2D.LINE_CAP_ROUND
			fx.add_child(glow)
			var core := Line2D.new()
			core.points = glow.points
			core.width = 8.0
			core.default_color = Color.WHITE
			fx.add_child(core)
			fx.add_child(_arc_line(Vector2.ZERO, 20.0, 0.0, TAU, Color(1.0, 0.95, 0.66), 12.0, Vector2.ONE))
	var tw := fx.create_tween()
	if tier_of(tier) in [1, 3]:
		tw.tween_property(fx, "scale", Vector2(1.5, 1.5) * k, 0.3).from(Vector2(0.6, 0.6) * k).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.3)
	else:
		tw.tween_property(fx, "modulate:a", 0.0, 0.22).set_delay(0.06)
	tw.tween_callback(fx.queue_free)


static func _arc_line(center: Vector2, r: float, a0: float, a1: float, col: Color, w: float, squash: Vector2) -> Line2D:
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		var a := lerpf(a0, a1, i / 24.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r * squash)
	l.points = pts
	l.width = w
	l.default_color = col
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l
