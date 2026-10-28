extends Node2D
## Schrottsauger: zeigt den Saugkegel, solange RT/LMB gehalten wird, und meldet das der Sim.
## Nur im Spielkontext aktiv (nicht im Baumodus oder Menü).

const SEGMENTS := 12

var _cone := Polygon2D.new()
var _swirl := Node2D.new()
var _shape_key := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var half := PlayerState.SUCK_HALF_ANGLE_RAD
	for i in SEGMENTS + 1:
		var a := -half + (2.0 * half) * float(i) / float(SEGMENTS)
		pts.append(Vector2.RIGHT.rotated(a) * PlayerState.BASE_SUCK_RANGE_PX)
	_cone.polygon = pts
	_cone.color = Color(0.3, 0.75, 1.0, 0.28)
	_cone.visible = false
	_cone.z_index = -1
	add_child(_cone)
	_swirl.z_index = -1
	_swirl.visible = false
	_swirl.draw.connect(_draw_swirl)
	add_child(_swirl)


func _physics_process(delta: float) -> void:
	# Kegel an die aktuelle Reichweite (Skill/Tech) anpassen.
	var range_px := float(SimClock.world.player.suck_range_px)
	var half := minf(SimClock.world.player.suck_half_angle, PI)
	if _shape_key != Vector2(range_px, half):
		_shape_key = Vector2(range_px, half)
		var pts := PackedVector2Array()
		var segs := SEGMENTS * 3 if half >= PI - 0.01 else SEGMENTS + int(half * 8.0)
		if half < PI - 0.01:
			pts.append(Vector2.ZERO)
		for i in segs + 1:
			var a := -half + (2.0 * half) * float(i) / float(segs)
			pts.append(Vector2.RIGHT.rotated(a) * range_px)
		_cone.polygon = pts
	var held := InputRouter.context == InputRouter.Context.GAME and Input.is_action_pressed("tool_primary")
	SimClock.world.player.suck_held = held
	_cone.visible = held
	_swirl.visible = held
	if held:
		_time += delta
		_cone.color.a = 0.22 + 0.08 * sin(_time * 18.0)
		_swirl.queue_redraw()


## Spiralarme, die sich zur Mitte drehen: je größer der Kegel, desto mehr Arme (Wirbel).
func _draw_swirl() -> void:
	var p := SimClock.world.player
	var range_px := float(p.suck_range_px)
	var half := minf(p.suck_half_angle, PI)
	var arms := 2 + int(half / PI * 4.0)
	for k in arms:
		var base := -half + (2.0 * half) * (float(k) + 0.5) / float(arms)
		var pts := PackedVector2Array()
		for i in 12:
			var t := float(i) / 11.0
			var r := range_px * (1.0 - t) * (1.0 - fmod(_time * 1.6, 1.0) * 0.25)
			var a := base + t * 1.2 * (1.0 if half < PI else 1.6) + _time * (2.0 if half >= PI else 0.0)
			pts.append(Vector2.RIGHT.rotated(a) * r)
		_swirl.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.35), 3.0, true)
