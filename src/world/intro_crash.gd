class_name IntroCrash
extends Node
## Absturz-Intro bei neuem Spiel (MS47): Das Schiff trudelt mit Rauchfahne herunter, schlägt auf
## (Staub, Wackeln, Bonk), Rusty plumpst heraus, schüttelt sich, erster Spruch. Etwa 7 s,
## B überspringt. Nur Darstellung: die Sim läuft nicht anders.

signal finished

var _main: Node
var _ship: Node2D
var _player: Node2D
var _body: Node2D                 # nur das Bild bewegt sich (Sim-Position bleibt, keine Aufgabe zählt)
var _aim: Node2D
var _body_scale := Vector2.ONE
var _ship_base := Vector2.ZERO
var _tween: Tween
var _smoke: CPUParticles2D
var _done := false


func start(main: Node, ship: Node2D, player: Node2D) -> void:
	_main = main
	_ship = ship
	_player = player
	_ship_base = ship.position
	_body = player.get_node("Sprite2D")
	_body_scale = _body.scale
	_aim = player.get_node("AimMarker")
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputRouter.context = InputRouter.Context.MENU
	_body.visible = false
	_aim.visible = false
	_smoke = _make_particles(Color(0.35, 0.35, 0.4, 0.7), 40, 1.4)
	_ship.add_child(_smoke)
	_smoke.emitting = true
	_ship.position = _ship_base + Vector2(-1300, -1500)
	_ship.rotation = -4.0
	_ship.scale = Vector2(0.55, 0.55)
	_tween = create_tween()
	_tween.tween_property(_ship, "position", _ship_base, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_ship, "rotation", 0.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_ship, "scale", Vector2.ONE, 2.4)
	_tween.tween_callback(_impact)
	_tween.tween_interval(0.7)
	_tween.tween_callback(_pop_rusty)
	_tween.tween_interval(1.1)
	_tween.tween_callback(_shake_off)
	_tween.tween_interval(1.0)
	_tween.tween_callback(_finish)


func _make_particles(color: Color, amount: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 10.0
	p.scale_amount_max = 22.0
	p.color = color
	p.z_index = 5
	return p


func _impact() -> void:
	_smoke.emitting = false
	var dust := _make_particles(Color(0.75, 0.65, 0.5, 0.8), 50, 0.9)
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.spread = 180.0
	dust.initial_velocity_min = 220.0
	dust.initial_velocity_max = 420.0
	dust.position = Vector2(0, 40)
	_ship.add_child(dust)
	dust.emitting = true
	Sfx.play("hammer", 0.0, 6.0, 0.45)
	Sfx.play("thud", 0.0, 4.0)
	_main.call("_shake", 12.0, 0.45)
	var squash := create_tween()
	squash.tween_property(_ship, "scale", Vector2(1.18, 0.82), 0.08)
	squash.tween_property(_ship, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _pop_rusty() -> void:
	_body.visible = true
	_body.position = _ship.global_position - _player.global_position
	_body.scale = Vector2(0.3, 0.3)
	Sfx.play("boing", 0.0)
	var t := create_tween()
	t.tween_property(_body, "position", Vector2.ZERO, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_body, "scale", _body_scale, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "scale", _body_scale * Vector2(1.25, 0.75), 0.07)
	t.tween_property(_body, "scale", _body_scale, 0.18).set_trans(Tween.TRANS_BACK)
	Sfx.play("plop", 0.0)


func _shake_off() -> void:
	var t := create_tween()
	for i in 4:
		t.tween_property(_body, "rotation", 0.3 if i % 2 == 0 else -0.3, 0.07)
	t.tween_property(_body, "rotation", 0.0, 0.08)
	EventBus.quip.emit("INTRO_Q")


## B: sofort ans Ende springen.
func skip() -> void:
	if _done:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_smoke):
		_smoke.emitting = false
	_ship.position = _ship_base
	_ship.rotation = 0.0
	_ship.scale = Vector2.ONE
	_body.visible = true
	_aim.visible = true
	_body.position = Vector2.ZERO
	_body.scale = _body_scale
	_body.rotation = 0.0
	InputRouter.context = InputRouter.Context.GAME
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not _done and (MenuInput.back_pressed(event) or event.is_action_pressed("pause")):
		skip()
		get_viewport().set_input_as_handled()
