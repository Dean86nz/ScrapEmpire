class_name Player
extends CharacterBody2D
## Rusty. Bewegung ist frame-basiert (flüssig bei 60 FPS); spielrelevante Wirkungen
## (Saugen, Hämmern ab MS1) werden als Befehle an die Simulation gegeben.

## Drehgeschwindigkeit des Körpers in rad/s (ca. eine halbe Umdrehung in 0,25 s).
const TURN_SPEED := 14.0

## Richtung des Werkzeugs (rechter Stick oder Maus). Nie Nullvektor.
var aim_dir := Vector2.RIGHT
## Letzte Bewegungsrichtung. Nie Nullvektor.
var facing := Vector2.RIGHT

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _aim_marker: Node2D = $AimMarker


func _physics_process(delta: float) -> void:
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

	# Körper dreht sich weich in Laufrichtung; das Sprite blickt nach +X.
	_sprite.rotation = rotate_toward(_sprite.rotation, facing.angle(), TURN_SPEED * delta)
	_aim_marker.rotation = aim_dir.angle()
