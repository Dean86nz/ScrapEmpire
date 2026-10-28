class_name Gags
extends Node2D
## Kleine, unerwartete Humor-Momente (MS59), reine Darstellung: Sim und Balance bleiben unverändert.
## Jeder Gag hat seine Chance bzw. seinen Auslöser; zusammen sollen sie selten genug bleiben,
## dass sie überraschen.

var _world: SimWorld
var _view: Node2D        # WorldView (Objekt-, Bot- und Drohnen-Ansichten)
var _player: Node2D
var _hit_once: Dictionary = {}   # Objekt-ID → schon einmal getroffen
var _vortex_time := 0.0
var _sneeze_timer := 40.0
var _stumble_timer := 60.0
var _drone_timer := 25.0
var _jam_timer := 30.0


func bind(world: SimWorld, view: Node2D, player: Node2D) -> void:
	_world = world
	_view = view
	_player = player
	z_index = 40
	world.wreck_hit.connect(_on_hit)
	world.boss_defeated.connect(_on_boss_defeated)
	world.helper_fused.connect(_on_fused)
	world.event_started.connect(func(type: String, _t: Array, _d: Array) -> void:
		if type == "tourists":
			_ufo_sputter())


# --- Treffer an bestimmten Objekten ----------------------------------------------------

func _on_hit(n: ResourceNode) -> void:
	var at := Vector2(n.center_px())
	if Vector2(at).distance_to(_player.global_position) > 1100.0:
		return
	var first := not _hit_once.has(n.id)
	_hit_once[n.id] = true
	var kind := n.kind
	if kind.begins_with("toaster") and randf() < 0.5:
		_toast(at)                                      # 1 Toaster spuckt Toast
	elif kind == "fridge_double" and first:
		_hop(n)                                         # 2 hüpft davon (statt Waschmaschine)
	elif kind.begins_with("fridge") and first:
		_penguin(at)                                    # 5 Pinguin watschelt heraus
	elif kind.begins_with("tv") and randf() < 0.5:
		_pop_text(at + Vector2(0, -40), "🤖", 40, 0.6)   # 8 Fernseher zeigt kurz Rusty
	elif kind == "tire_stack" and randf() < 0.6:
		_bounce_tire(at)                                # 9 Reifen hüpft davon
	elif kind.begins_with("satellite") and randf() < 0.5:
		_pop_text(at + Vector2(0, -60), "· · ·  — — —  · · ·", 26, 1.2)   # 13 SOS
		Sfx.play("plop", 0.0, -6.0, 2.2)


func _toast(at: Vector2) -> void:
	var l := _emoji("🍞", 36)
	l.position = at + Vector2(-18, -60)
	var dir := 1.0 if randf() < 0.5 else -1.0
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(40 * dir, -90), 0.25).set_ease(Tween.EASE_OUT)
	for i in 3:
		tw.tween_property(l, "position", l.position + Vector2((90 + 50 * i) * dir, 0), 0.18).set_ease(Tween.EASE_IN)
		tw.tween_property(l, "position", l.position + Vector2((110 + 50 * i) * dir, -30), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func _hop(n: ResourceNode) -> void:
	var v: Node2D = _view._node_views.get(n.id)
	if v == null:
		return
	var base := v.position
	var tw := create_tween()
	for i in 3:
		tw.tween_property(v, "position", base + Vector2(14 * (i + 1), -40), 0.14).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "position", base + Vector2(14 * (i + 1), 0), 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(v, "position", base, 0.4)   # Sim-Position bleibt, Bild kehrt zurück


func _penguin(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/nature/critter_penguin.svg")
	s.position = at + Vector2(10, 20)
	s.scale = Vector2(0.8, 0.8)
	add_child(s)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		s.position = at + Vector2(10 + 260 * k, 20 + sin(k * 40.0) * 3.0)
		s.rotation = sin(k * 40.0) * 0.15, 0.0, 1.0, 2.6)
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.tween_callback(s.queue_free)


func _bounce_tire(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/nodes/tire_stack.svg")
	s.scale = Vector2(0.45, 0.45)
	s.position = at
	add_child(s)
	var dir := Vector2.from_angle(randf_range(-PI, PI))
	var tw := create_tween()
	var p := at
	for i in 4:
		var h := 70.0 / (i + 1)
		var step := dir * (110.0 / (i + 1))
		tw.tween_property(s, "position", p + step * 0.5 + Vector2(0, -h), 0.16).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "rotation", s.rotation + 3.0, 0.32)
		p += step
		tw.tween_property(s, "position", p, 0.16).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: Sfx.play_throttled("boing", 0.1, 0.1, -10.0))
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.tween_callback(s.queue_free)


# --- Bosse, Fusion, Ereignisse -----------------------------------------------------------

func _on_boss_defeated(kind: String, _zone: String, _reward: int) -> void:
	if kind != "cable_monster":
		return
	for hv in _view._helper_views.values():                  # 10 Kabelmonster verheddert die Bots
		hv.emote("🌀", Color(1.0, 0.6, 0.3))
		var tw: Tween = hv.create_tween()
		for i in 4:
			tw.tween_property(hv, "rotation", 0.4 if i % 2 == 0 else -0.4, 0.12)
		tw.tween_property(hv, "rotation", 0.0, 0.12)


func _on_fused(h: Helper) -> void:
	var hv: Node2D = _view._helper_views.get(h.id)
	if hv == null:
		return
	_confetti(hv.position)                                   # 14 Mega-Bot mit zu kleinem Hut
	if h.power >= 25:
		var hat := _emoji("🎩", 22)
		hat.position = Vector2(-11, -78)
		hv.add_child(hat)


func _ufo_sputter() -> void:
	# 4 Touristen-Ufo hustet und verliert den Auspuff (Rauchwölkchen hoch oben, Teil fällt herunter)
	var at := _player.global_position + Vector2(randf_range(-300, 300), -420)
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		_pop_text(at, "💨", 40, 0.8)
		var pipe := _emoji("🔩", 30)
		pipe.position = at
		var tw := create_tween()
		tw.tween_property(pipe, "position", at + Vector2(60, 380), 0.9).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(pipe, "rotation", 6.0, 0.9)
		tw.tween_callback(func() -> void:
			Sfx.play("thud", 0.1, -6.0)
			_pop_text(pipe.position, "💥", 34, 0.4)
			pipe.queue_free()))


# --- Zufällige kleine Momente ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _world == null or InputRouter.context != InputRouter.Context.GAME:
		return
	# 6 Riesen-Wirbel: nach 6 s Dauersaugen dreht es Rusty mit, Sternchen
	if _world.player.suck_held and _world.player.suck_half_angle >= PI - 0.01:
		_vortex_time += delta
		if _vortex_time > 6.0:
			_vortex_time = -20.0
			_dizzy()
	elif _vortex_time > 0.0:
		_vortex_time = 0.0
	else:
		_vortex_time = minf(_vortex_time + delta, 0.0)
	# 12 Rusty niest beim Saugen ab und zu
	if _world.player.suck_held:
		_sneeze_timer -= delta
		if _sneeze_timer <= 0.0:
			_sneeze_timer = randf_range(45.0, 90.0)
			_pop_text(_player.global_position + Vector2(30, -70), "Hatschi!", 26, 0.8)
			var sp: Node2D = _player.get_node("Sprite2D")
			var tw := create_tween()
			tw.tween_property(sp, "position", sp.position + Vector2(-14, 0), 0.06)
			tw.tween_property(sp, "position", sp.position, 0.18)
	# 3 Ein Bot stolpert (Purzelbaum)
	_stumble_timer -= delta
	if _stumble_timer <= 0.0:
		_stumble_timer = randf_range(50.0, 110.0)
		var hv := _random_view(_view._helper_views)
		if hv != null:
			var tw: Tween = hv.create_tween()
			tw.tween_property(hv, "rotation", TAU, 0.45)
			tw.tween_callback(func() -> void:
				hv.rotation = 0.0
				hv.emote("💫", Color(1, 0.9, 0.4)))
	# 11 Drohne lässt ein Teil fallen und fängt es wieder
	_drone_timer -= delta
	if _drone_timer <= 0.0:
		_drone_timer = randf_range(30.0, 70.0)
		var dv := _random_view(_view._drone_views)
		if dv != null:
			var bit := ColorRect.new()
			bit.color = Color(0.7, 0.7, 0.75)
			bit.size = Vector2(10, 10)
			bit.position = Vector2(-5, 10)
			dv.add_child(bit)
			var tw: Tween = dv.create_tween()
			tw.tween_property(bit, "position", Vector2(-5, 70), 0.35).set_ease(Tween.EASE_IN)
			tw.tween_property(bit, "position", Vector2(-5, 10), 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_callback(bit.queue_free)
	# 7 Bot-Stau: zwei Bots dicht beieinander zögern kurz
	_jam_timer -= delta
	if _jam_timer <= 0.0:
		_jam_timer = randf_range(40.0, 80.0)
		var views: Array = _view._helper_views.values()
		for i in views.size():
			for j in range(i + 1, views.size()):
				if (views[i] as Node2D).position.distance_to((views[j] as Node2D).position) < 50.0:
					views[i].emote("❓", Color(1, 0.85, 0.3))
					views[j].emote("❗", Color(1, 0.5, 0.3))
					return


func _dizzy() -> void:
	var sp: Node2D = _player.get_node("Sprite2D")
	var tw := create_tween()
	tw.tween_property(sp, "rotation", sp.rotation + TAU * 2.0, 0.8)
	_pop_text(_player.global_position + Vector2(0, -80), "💫", 40, 1.4)


# --- Helfer ---------------------------------------------------------------------------------

func _random_view(d: Dictionary) -> Node2D:
	if d.is_empty():
		return null
	var v: Node2D = d.values()[randi() % d.size()]
	return v if v.position.distance_to(_player.global_position) < 900.0 else null


func _emoji(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _pop_text(at: Vector2, text: String, size: int, seconds: float) -> void:
	var l := _emoji(text, size)
	l.position = at - Vector2(size, size * 0.6)
	l.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func _confetti(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 60
	p.lifetime = 1.2
	p.spread = 180.0
	p.initial_velocity_min = 200.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.8, 1), Color(0.5, 1, 0.4)])
	p.color_initial_ramp = g
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
