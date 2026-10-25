extends Node2D
## Schrottsauger: zeigt den Saugkegel, solange RT/LMB gehalten wird, und meldet das der Sim.
## Nur im Spielkontext aktiv (nicht im Baumodus oder Menü).

const SEGMENTS := 12

var _cone := Polygon2D.new()
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


func _physics_process(delta: float) -> void:
	# Kegel an die aktuelle Reichweite (Skill/Tech) anpassen.
	var range_px := float(SimClock.world.player.suck_range_px)
	if _cone.polygon.size() > 1 and absf(_cone.polygon[1].length() - range_px) > 0.5:
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		var half := PlayerState.SUCK_HALF_ANGLE_RAD
		for i in SEGMENTS + 1:
			var a := -half + (2.0 * half) * float(i) / float(SEGMENTS)
			pts.append(Vector2.RIGHT.rotated(a) * range_px)
		_cone.polygon = pts
	var auto: bool = SimClock.world.tasks.active
	var held := (InputRouter.context == InputRouter.Context.GAME and Input.is_action_pressed("tool_primary")) 		or (auto and SimClock.world.player.suck_held)
	if not auto:
		SimClock.world.player.suck_held = held
	_cone.visible = held
	if held:
		_time += delta
		_cone.color.a = 0.22 + 0.08 * sin(_time * 18.0)
