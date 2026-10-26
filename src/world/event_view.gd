class_name EventView
extends Node2D
## Darstellung der Nachschub-Ereignisse (MS30): Vorwarnung mit Schild, Touristen-Raumschiff fliegt
## vorbei und wirft Müllsäcke, Meteoriten stürzen mit Feuerschweif herab, Einschläge mit Staubwolke.
## Die Sim legt Ziele und Zeitpunkte fest; diese Ansicht lässt die Dinge passend dazu fallen.

const QUIPS_TOURIST := ["QUIP_TOURIST_1", "QUIP_TOURIST_2", "QUIP_TOURIST_3"]

var _world: SimWorld
var _hud: Node
var _sky: ColorRect
var _meteors_left := 0


func bind(world: SimWorld, hud: Node) -> void:
	_world = world
	_hud = hud
	world.event_warning.connect(_on_warning)
	world.event_started.connect(_on_started)
	world.event_landed.connect(_on_landed)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_sky = ColorRect.new()
	_sky.color = Color(1.0, 0.5, 0.15, 0.0)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_sky)


func _on_warning(type: String, seconds: float, _center: Vector2) -> void:
	var banner: StageBanner = _hud.stage_banner
	match type:
		"tourists":
			banner.show_card(tr("EVT_TOURIST_TITLE"), tr("EVT_TOURIST_SUB"), "", "res://assets/sprites/robot/tourist_ship.svg", 2.4)
			EventBus.quip.emit("QUIP_TOURIST_WARN")
			Sfx.play("honk", 0.05)
		"meteors":
			banner.show_card(tr("EVT_METEOR_TITLE"), tr("EVT_METEOR_SUB") % int(round(seconds)), "", "res://assets/sprites/nodes/meteor.svg", 3.0)
			EventBus.quip.emit("QUIP_METEOR_WARN")
			Sfx.play("honk", 0.0, -4.0)
			create_tween().tween_property(_sky, "color:a", 0.2, minf(seconds, 4.0))


func _on_started(type: String, targets: Array, delays: Array) -> void:
	match type:
		"tourists":
			_fly_tourists(targets, delays)
		"meteors":
			_meteors_left = targets.size()
			for i in targets.size():
				_drop_meteor(targets[i], float(delays[i]))


func _on_landed(type: String, node: ResourceNode) -> void:
	var at := Vector2(node.center_px())
	_dust(at, 1.0 if type == "tourists" else 1.8)
	Sfx.play_throttled("thud", 0.08, 0.15, -2.0 if type == "tourists" else 0.0)
	if type == "meteors":
		_flash(at)
		_meteors_left -= 1
		if _meteors_left <= 0:
			create_tween().tween_property(_sky, "color:a", 0.0, 2.0)
			get_tree().create_timer(1.0).timeout.connect(func() -> void: EventBus.quip.emit("QUIP_METEOR_DONE"))


## Raumschiff quer über die Abwurfstellen; jeder Sack fällt aus dem Schiff genau zur Landezeit.
func _fly_tourists(targets: Array, delays: Array) -> void:
	var minx := INF
	var maxx := -INF
	var y := 0.0
	for t: Vector2 in targets:
		minx = minf(minx, t.x)
		maxx = maxf(maxx, t.x)
		y += t.y
	y = y / maxf(targets.size(), 1) - 280.0
	var last := 0.0
	for d in delays:
		last = maxf(last, float(d))
	var total := last + 1.6
	var x0 := minx - 1300.0
	var x1 := maxx + 1300.0
	var ship := Sprite2D.new()
	ship.texture = load("res://assets/sprites/robot/tourist_ship.svg")
	ship.z_index = 30
	ship.position = Vector2(x0, y)
	add_child(ship)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		ship.position = Vector2(lerpf(x0, x1, k), y + sin(k * TAU * 3.0) * 12.0)
		ship.rotation = sin(k * TAU * 3.0) * 0.06, 0.0, 1.0, total + 1.2)
	tw.tween_callback(ship.queue_free)
	get_tree().create_timer(minf(1.0, total)).timeout.connect(func() -> void: EventBus.quip.emit(QUIPS_TOURIST[randi() % QUIPS_TOURIST.size()]))
	for i in targets.size():
		var land := float(delays[i])
		var fall := 0.6
		var target: Vector2 = targets[i]
		get_tree().create_timer(maxf(land - fall, 0.01)).timeout.connect(func() -> void:
			var bag := Sprite2D.new()
			bag.texture = load("res://assets/sprites/nodes/trash_bag.svg")
			bag.z_index = 29
			var from := ship.position if is_instance_valid(ship) else target + Vector2(0, -300)
			bag.position = from
			add_child(bag)
			var bt := create_tween()
			bt.set_parallel(true)
			bt.tween_property(bag, "position", target, fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			bt.tween_property(bag, "rotation", randf_range(-3.0, 3.0), fall)
			bt.chain().tween_callback(bag.queue_free))


## Meteor stürzt schräg von oben rechts mit Feuerschweif, landet genau zur Landezeit.
func _drop_meteor(target: Vector2, land: float) -> void:
	var fall := 0.8
	get_tree().create_timer(maxf(land - fall, 0.01)).timeout.connect(func() -> void:
		var m := Sprite2D.new()
		m.texture = load("res://assets/sprites/nodes/meteor.svg")
		m.z_index = 29
		m.scale = Vector2(0.5, 0.5)
		var from := target + Vector2(520, -900)
		m.position = from
		add_child(m)
		var trail := CPUParticles2D.new()
		trail.texture = ShipFx._soft_dot()
		trail.amount = 40
		trail.lifetime = 0.5
		trail.local_coords = false
		trail.direction = Vector2(0.5, -0.9)
		trail.spread = 12.0
		trail.initial_velocity_min = 40.0
		trail.initial_velocity_max = 90.0
		trail.scale_amount_min = 0.8
		trail.scale_amount_max = 1.6
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
		g.set_color(1, Color(0.9, 0.3, 0.1, 0.0))
		trail.color_ramp = g
		trail.z_index = -1
		m.add_child(trail)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "position", target, fall).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "scale", Vector2.ONE, fall)
		tw.chain().tween_callback(m.queue_free))


func _dust(at: Vector2, size: float) -> void:
	for i in 6:
		var p := Sprite2D.new()
		p.texture = ShipFx._soft_dot()
		p.modulate = Color(0.85, 0.8, 0.7, 0.85)
		p.position = at
		p.z_index = 22
		p.scale = Vector2.ONE * 0.8 * size
		add_child(p)
		var dir := Vector2.RIGHT.rotated(i * TAU / 6.0 + randf() * 0.5)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position", at + dir * 50.0 * size, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE * 2.0 * size, 0.45)
		tw.tween_property(p, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(p.queue_free)


func _flash(at: Vector2) -> void:
	var f := Sprite2D.new()
	f.texture = ShipFx._soft_dot()
	f.modulate = Color(1.0, 0.9, 0.5, 0.9)
	f.position = at
	f.z_index = 23
	f.scale = Vector2.ONE * 2.0
	add_child(f)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector2.ONE * 7.0, 0.35)
	tw.tween_property(f, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(f.queue_free)
