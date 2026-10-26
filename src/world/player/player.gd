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
var _boost_time := 0.0
var _boost_cooldown := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _aim_marker: Node2D = $AimMarker


var _confetti: CPUParticles2D


func _ready() -> void:
	add_to_group("player")


## Konfetti beim Levelaufstieg.
func celebrate() -> void:
	if _confetti == null:
		_confetti = CPUParticles2D.new()
		_confetti.one_shot = true
		_confetti.explosiveness = 0.9
		_confetti.amount = 48
		_confetti.lifetime = 1.2
		_confetti.direction = Vector2(0, -1)
		_confetti.spread = 80.0
		_confetti.initial_velocity_min = 220.0
		_confetti.initial_velocity_max = 380.0
		_confetti.gravity = Vector2(0, 500)
		_confetti.scale_amount_min = 4.0
		_confetti.scale_amount_max = 7.0
		_confetti.angular_velocity_min = -360.0
		_confetti.angular_velocity_max = 360.0
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.4, 0.4))
		grad.set_color(1, Color(0.4, 0.8, 1.0))
		grad.add_point(0.33, Color(1.0, 0.9, 0.3))
		grad.add_point(0.66, Color(0.5, 0.95, 0.5))
		_confetti.color_initial_ramp = grad
		_confetti.z_index = 40
		add_child(_confetti)
	_confetti.restart()
	_confetti.emitting = true


func _physics_process(delta: float) -> void:
	var in_menu := InputRouter.context == InputRouter.Context.MENU
	var move := Vector2.ZERO
	if not in_menu:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down", InputMapSetup.DEADZONE)
	var mods: Dictionary = SimClock.world.mods
	var world := SimClock.world
	var auto := world.tasks.active
	if auto and move.length_squared() > 0.0:
		# Jede Stick-Eingabe gibt die Kontrolle zurück.
		world.tasks.interrupt(world.player)
		Quips.say("autopilot_interrupt", true)
		auto = false
	if auto and world.player.has_move_target():
		var to_target := Vector2(world.player.move_target) - global_position
		move = to_target.normalized() if to_target.length() > 4.0 else Vector2.ZERO
	# Turbo-Boost (Skill): L3 / Shift, 2 s schnell, dann Abklingzeit.
	_boost_cooldown = maxf(_boost_cooldown - delta, 0.0)
	if _boost_time > 0.0:
		_boost_time -= delta
	elif not in_menu and float(mods["boost_cooldown"]) > 0.0 and _boost_cooldown <= 0.0 and Input.is_action_just_pressed("boost"):
		_boost_time = float(mods["boost_seconds"])
		_boost_cooldown = float(mods["boost_cooldown"]) + _boost_time
	var speed := GameConfig.PLAYER_SPEED_PX * float(mods["speed_mult"])
	if _boost_time > 0.0:
		speed *= float(mods["boost_mult"])
	if auto:
		speed *= float(mods["autopilot_speed_mult"])
	_sprite.modulate = Color(1.0, 1.0, 0.75) if _boost_time > 0.0 else Color.WHITE
	velocity = move * speed
	move_and_slide()

	var aim := Vector2.ZERO
	if auto:
		aim = world.player.aim  # das Gehirn zielt
	elif InputRouter.context == InputRouter.Context.GAME:
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
	_sprite.rotation = rotate_toward(_sprite.rotation, facing.angle(), TURN_SPEED * float(mods["turn_mult"]) * delta)
	_aim_marker.rotation = aim_dir.angle()

	var state: PlayerState = SimClock.world.player
	state.pos = Vector2i(global_position.round())
	if not auto:
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
		if b is Ship:
			w.queue_command({"type": "deliver_all"})
			get_viewport().set_input_as_handled()
			return
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
