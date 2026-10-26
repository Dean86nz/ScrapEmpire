class_name StageTrack
extends Control
## Kopf des Schiff-Tabs: Bild des Schiffs in der aktuellen Stufe und die fünf Reparaturstufen als
## Leiste (erledigt grün mit Haken, aktuell orange, offen grau), darunter Name und Geschenke je Stufe.
## Ein Balken zeigt, wie viele Bolts zur nächsten Reparatur fehlen.

const INK := Color(0.165, 0.165, 0.2)
const DONE := Color(0.45, 0.8, 0.4)
const NOW := Color(0.95, 0.55, 0.16)
const OPEN := Color(0.78, 0.76, 0.7)
const SHIP_SIZE := 170.0

var _world: SimWorld
var _ship_tex: Texture2D
var _ship_path := ""


func bind(world: SimWorld) -> void:
	_world = world
	custom_minimum_size = Vector2(0, 250)
	refresh()


func refresh() -> void:
	var s := _world.ship() if _world != null else null
	if s != null and s.sprite_path != _ship_path:
		_ship_path = s.sprite_path
		_ship_tex = load(_ship_path)
	queue_redraw()


func _draw() -> void:
	if _world == null or _world.ship() == null:
		return
	var s := _world.ship()
	var font := get_theme_default_font()
	var stages := ShipSystem.max_stage(_world)
	if _ship_tex != null:
		draw_texture_rect(_ship_tex, Rect2(Vector2(10, 4), Vector2(SHIP_SIZE, SHIP_SIZE)), false)
	var x0 := SHIP_SIZE + 70.0
	var x1 := size.x - 90.0
	var y := 56.0
	var step := (x1 - x0) / float(maxi(stages - 1, 1))
	draw_line(Vector2(x0, y), Vector2(x1, y), OPEN, 10.0)
	draw_line(Vector2(x0, y), Vector2(x0 + step * (s.stage - 1), y), DONE, 10.0)
	for i in stages:
		var st := i + 1
		var p := Vector2(x0 + step * i, y)
		var col := DONE if st < s.stage else (NOW if st == s.stage else OPEN)
		draw_circle(p, 30.0, col)
		draw_arc(p, 30.0, 0.0, TAU, 48, INK, 4.0)
		if st < s.stage:
			draw_polyline(PackedVector2Array([p + Vector2(-13, 0), p + Vector2(-3, 10), p + Vector2(14, -10)]), Color.WHITE, 6.0)
		else:
			var mark := str(st)
			var mw := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(font, p + Vector2(-mw * 0.5, 11), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
		var d := ShipSystem.stage_def(_world, st)
		var lines: Array[String] = [tr(str(d.get("name_key", "")))]
		for f in d.get("unlocks", []):
			lines.append("+ " + tr("GIFT_" + str(f).to_upper()))
		var ly := y + 66.0
		for j in lines.size():
			var size_px := 22
			var tw := font.get_string_size(lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			var c := INK if j == 0 else Color(0.2, 0.5, 0.2)
			if st > s.stage:
				c = c.lerp(Color(0.5, 0.5, 0.5), 0.45)
			draw_string(font, Vector2(p.x - tw * 0.5, ly), lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)
			ly += 28.0
	# Balken zur nächsten Reparatur
	var by := 214.0
	var bar := Rect2(Vector2(x0 - 30.0, by), Vector2(x1 - x0 + 60.0, 26.0))
	var text := ""
	var frac := 1.0
	var cost := ShipSystem.next_stage_cost(_world, s)
	if cost < 0:
		text = tr("STAGE_TRACK_DONE")
	else:
		frac = clampf(float(_world.bolts) / float(maxi(cost, 1)), 0.0, 1.0)
		text = tr("STAGE_TRACK_NEXT") % [Fmt.int_str(mini(_world.bolts, cost)), Fmt.int_str(cost)]
		if ShipSystem.can_upgrade(_world, s) == "planet":
			var need := float(ShipSystem.stage_def(_world, s.stage + 1).get("requires_planet", 0.0))
			text = tr("STAGE_TRACK_PLANET") % [int(round(_world.zones.planet_health(_world.nodes) * 100.0)), int(round(need * 100.0))]
	draw_rect(bar, Color(1, 1, 1, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), DONE if frac >= 1.0 else NOW)
	draw_rect(bar, INK, false, 3.0)
	var tw2 := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(bar.position.x + (bar.size.x - tw2) * 0.5, by + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
