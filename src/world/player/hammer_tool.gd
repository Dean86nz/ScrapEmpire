extends Node2D
## Hammer: LT/RMB löst einen Schlag aus (die Sim prüft Reichweite und Cooldown)
## und spielt eine kurze Schwung-Animation am Hammerkopf.

var _head := Polygon2D.new()
var _tween: Tween


func _ready() -> void:
	# Hammerkopf vor Rusty, normalerweise unsichtbar; erscheint nur beim Schlag.
	_head.polygon = PackedVector2Array([Vector2(40, -12), Vector2(64, -12), Vector2(64, 12), Vector2(40, 12)])
	_head.color = Color(0.3, 0.3, 0.36, 1.0)
	_head.visible = false
	add_child(_head)


func _physics_process(_delta: float) -> void:
	if InputRouter.context == InputRouter.Context.GAME and Input.is_action_just_pressed("tool_secondary"):
		SimClock.world.player.hammer_pressed = true
		_swing()


func _swing() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_head.visible = true
	_head.rotation = -0.9
	_tween = create_tween()
	_tween.tween_property(_head, "rotation", 0.25, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_head, "rotation", 0.0, 0.12)
	_tween.tween_callback(func() -> void: _head.visible = false)
