class_name SecretsView
extends Node2D
## Darstellung der Secrets (MS60): Meldung beim Finden, Fortschritt (Ente 5/12), Weisheiten der
## Toilette, Disco-Code ↑↑↓↓←→←→, Glühwürmchen (20 s stillstehen in der Monolith-Ebene) und die
## Kosmetik: Enten-Hut, Katzen-Bot, goldene Statue, Turbo-Abzeichen am Schiff.

const DISCO_CODE := ["ui_up", "ui_up", "ui_down", "ui_down", "ui_left", "ui_right", "ui_left", "ui_right"]

var _main: Node
var _world: SimWorld
var _player: Node2D
var _hud: Node
var _code_pos := 0
var _still := 0.0
var _last_pos := Vector2.ZERO
var _disco := false
var _disco_mod: CanvasModulate
var _t := 0.0
var _duck_hat: Label
var _cat: Label
var _statue: Sprite2D
var _badge: Label


func bind(main: Node, world: SimWorld, player: Node2D, hud: Node) -> void:
	_main = main
	_world = world
	_player = player
	_hud = hud
	z_index = 35
	world.secret_found.connect(_on_found)
	world.secret_progress.connect(func(id: String, n: int, total: int) -> void:
		var d := SecretSystem.def_of(id)
		_float(_player.global_position + Vector2(0, -110), tr("SECRET_PROGRESS") % [tr(str(d.get("name_key", id))), n, total], Color(1, 0.9, 0.4)))
	world.wreck_hit.connect(func(n: ResourceNode) -> void:
		if n.kind == "toilet":
			_float(Vector2(n.center_px()) + Vector2(0, -90), tr("TOILET_%d" % (1 + randi() % 5)), Color.WHITE))


func _on_found(id: String) -> void:
	var d := SecretSystem.def_of(id)
	_hud.stage_banner.show_card(tr("SECRET_FOUND"), tr(str(d.get("name_key", id))), tr(str(d.get("desc_key", ""))) + "  ·  " + tr("SECRET_BONUS"), "res://assets/sprites/ui/trophy.svg", 4.0)
	Sfx.play("milestone")
	_sparkle(_player.global_position)
	match id:
		"kaltholz":
			_float(_player.global_position + Vector2(0, -140), tr("KALTHOLZ_RECIPE"), Color(1, 0.85, 0.6), 4.0)
		"dev_room":
			_float(_player.global_position + Vector2(0, -140), tr("DEV_ROOM"), Color(0.85, 0.75, 1.0), 5.0)


## Funkeln beim Fund (MS66): goldene Sterne sprühen um Rusty.
func _sparkle(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 40
	p.lifetime = 1.4
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 120)
	p.texture = load("res://assets/sprites/ui/star.svg")
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	p.color = Color(1.0, 0.86, 0.3)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if InputRouter.context != InputRouter.Context.GAME or not event.is_pressed() or event.is_echo():
		return
	for a: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(a):
			_code_pos = _code_pos + 1 if a == DISCO_CODE[_code_pos] else (1 if a == DISCO_CODE[0] else 0)
			if _code_pos >= DISCO_CODE.size():
				_code_pos = 0
				_toggle_disco()
			return


func _toggle_disco() -> void:
	_disco = not _disco
	if _disco_mod == null:
		_disco_mod = CanvasModulate.new()
		_main.add_child(_disco_mod)
	_disco_mod.visible = _disco
	if not _disco:
		_disco_mod.color = Color.WHITE
	_world.queue_command({"type": "secret", "id": "disco"})


func _process(delta: float) -> void:
	if _world == null:
		return
	_t += delta
	if _disco and _disco_mod != null:
		_disco_mod.color = Color.from_hsv(fmod(_t * 0.5, 1.0), 0.35, 1.0)
	# Glühwürmchen: 20 s stillstehen in der Monolith-Ebene
	var p := _player.global_position
	if p.distance_to(_last_pos) < 2.0 and _world.zones.zone_id_at(_world.player_tile()) == "z00" and InputRouter.context == InputRouter.Context.GAME:
		_still += delta
		if _still > 20.0 and not SecretSystem.is_found(_world, "fireflies"):
			_still = -999.0
			_fireflies()
			_world.queue_command({"type": "secret", "id": "fireflies"})
	else:
		_still = 0.0
	_last_pos = p
	_cosmetics()


func _fireflies() -> void:
	for i in 24:
		var f := ColorRect.new()
		f.color = Color(1.0, 1.0, 0.55)
		f.size = Vector2(6, 6)
		add_child(f)
		var phase := TAU * i / 24.0
		var tw := create_tween()
		tw.tween_method(func(k: float) -> void:
			var r := 60.0 + 80.0 * sin(k * PI)
			f.position = _player.global_position + Vector2.from_angle(phase + k * TAU * 2.0) * r
			f.modulate.a = 0.4 + 0.6 * absf(sin(k * 20.0 + phase)), 0.0, 1.0, 6.0)
		tw.tween_callback(f.queue_free)


func _cosmetics() -> void:
	if SecretSystem.is_found(_world, "ducks") and _duck_hat == null:
		_duck_hat = _label("🦆", 30)
		_player.add_child(_duck_hat)
		_duck_hat.position = Vector2(-15, -78)
	if SecretSystem.is_found(_world, "golden_heap"):
		if _cat == null:
			_cat = _label("🐱", 34)
			add_child(_cat)
			_cat.position = _player.global_position
		_cat.position = _cat.position.lerp(_player.global_position + Vector2(-70, 30), 0.04)
	var ship := _world.ship()
	if ship != null and SecretSystem.is_found(_world, "statue") and _statue == null:
		_statue = Sprite2D.new()
		_statue.texture = load("res://assets/sprites/robot/rusty.svg")
		_statue.modulate = Color(1.0, 0.82, 0.3)
		_statue.scale = Vector2(1.8, 1.8)
		_statue.position = Vector2(ship.center_px()) + Vector2(230, 40)
		add_child(_statue)
	if ship != null and SecretSystem.is_found(_world, "speedrun") and _badge == null:
		_badge = _label("🏅", 48)
		_badge.position = Vector2(ship.center_px()) + Vector2(-30, -200)
		add_child(_badge)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _float(at: Vector2, text: String, color: Color, seconds: float = 2.2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(800, 40)
	l.position = at - Vector2(400, 20)
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
