class_name Player
extends CharacterBody2D
## Rusty. Bewegung ist frame-basiert (flüssig bei 60 FPS); spielrelevante Wirkungen
## (Saugen, Hämmern ab MS1) werden als Befehle an die Simulation gegeben.

## Richtung des Werkzeugs (rechter Stick oder Maus). Nie Nullvektor.
var aim_dir := Vector2.RIGHT
## Letzte Bewegungsrichtung. Nie Nullvektor.
var facing := Vector2.RIGHT

@onready var _aim_marker: Node2D = $AimMarker


func _physics_process(_delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down", InputMapSetup.DEADZONE)
	velocity = move * GameConfig.PLAYER_SPEED_PX
	move_and_slide()

	var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", GameConfig.AIM_DEADZONE)
	if not InputRouter.is_gamepad:
		aim = get_global_mouse_position() - global_position
	if aim.length_squared() > 0.0:
		aim_dir = aim.normalized()
	elif move.length_squared() > 0.0:
		aim_dir = move.normalized()
	if move.length_squared() > 0.0:
		facing = move.normalized()
	_aim_marker.rotation = aim_dir.angle()
