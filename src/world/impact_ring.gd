class_name ImpactRing
extends Node2D
## Schockwellen-Ring beim Hammerschlag: wächst schnell, verblasst, löscht sich selbst.

var radius_to := 80.0
var width := 6.0
var _t := 0.0
const DURATION := 0.28


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var r := lerpf(18.0, radius_to, 1.0 - pow(1.0 - k, 3.0))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.95, 0.75, 1.0 - k), width * (1.0 - k * 0.6), true)
