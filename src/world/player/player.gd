class_name Player
extends CharacterBody2D
## Rusty. Bewegung ist frame-basiert (flüssig bei 60 FPS). Spielrelevante Wirkungen
## laufen über PlayerState in der Sim: der Node schreibt pro Frame Position, Zielrichtung
## und Werkzeug-Eingaben; die Sim entscheidet im Tick.

signal hotbar_selected(index: int)

## Drehgeschwindigkeit des Körpers in rad/s (ca. eine halbe Umdrehung in 0,25 s).
const TURN_SPEED := 14.0
const IDLE_QUIP_SECONDS := 60.0
const INTERACT_RANGE_PX := 48

## Richtung des Werkzeugs (rechter Stick oder Maus). Nie Nullvektor.
var aim_dir := Vector2.RIGHT
## Letzte Bewegungsrichtung. Nie Nullvektor.
var facing := Vector2.RIGHT
## Ausgewählter Hotbar-Slot (LB/RB).
var selected_slot := 0

var _idle_time := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _aim_marker: Node2D = $AimMarker


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	var in_menu := InputRouter.context == InputRouter.Context.MENU
	var move := Vector2.ZERO
	if not in_menu:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down", InputMapSetup.DEADZONE)
	velocity = move * GameConfig.PLAYER_SPEED_PX
	move_and_slide()

	var aim := Vector2.ZERO
	if InputRouter.context == InputRouter.Context.GAME:
		aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", GameConfig.AIM_DEADZONE)
		if not InputRouter.is_gamepad:
			aim = get_global_mouse_position() - global_position
	if aim.length_squared() > 0.0:
		aim_dir = aim.normalized()
	elif move.length_squared() > 0.0:
		aim_dir = move.normalized()
	if move.length_squared() > 0.0:
		facing = move.normalized()
		_idle_time = 0.0
	else:
		_idle_time += delta
		if _idle_time >= IDLE_QUIP_SECONDS:
			_idle_time = 0.0
			Quips.say("idle")

	# Körper dreht sich weich in Laufrichtung; das Sprite blickt nach +X.
	_sprite.rotation = rotate_toward(_sprite.rotation, facing.angle(), TURN_SPEED * delta)
	_aim_marker.rotation = aim_dir.angle()

	var state: PlayerState = SimClock.world.player
	state.pos = Vector2i(global_position.round())
	state.aim = aim_dir


## Gebäude in Reichweite für A (einlegen/entnehmen), sonst null.
func nearby_building() -> Building:
	return SimClock.world.building_near(Vector2i(global_position.round()), INTERACT_RANGE_PX)


func _unhandled_input(event: InputEvent) -> void:
	if InputRouter.context != InputRouter.Context.GAME:
		return
	if event.is_action_pressed("hotbar_next"):
		_select(selected_slot + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_prev"):
		_select(selected_slot - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var b := nearby_building()
		if b == null:
			return
		var w := SimClock.world
		var slot: Dictionary = w.player.inventory.slots[selected_slot]
		if slot["item"] != "":
			w.queue_command({"type": "deposit", "tile": b.tile, "slot": selected_slot})
		else:
			w.queue_command({"type": "withdraw", "tile": b.tile})
		get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	var n := SimClock.world.player.inventory.slot_count
	selected_slot = posmod(index, n)
	hotbar_selected.emit(selected_slot)
