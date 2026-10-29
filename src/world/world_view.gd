class_name WorldView
extends Node2D
## Spiegelt die SimWorld in Nodes: Ressourcenknoten, lose Items, Gebäude, Einsammel-Animation.

var _world: SimWorld
var _node_views: Dictionary = {}      # node id → ResourceNodeView
var _loose_views: Dictionary = {}     # loose id → LooseItemView
var _building_views: Dictionary = {}  # building id → BuildingView
var _helper_views: Dictionary = {}    # helper id → HelperView
var _drone_views: Dictionary = {}     # drone id → DroneView
var _collectible_views: Dictionary = {}  # collectible id → CollectibleView
var _zone_tints: Dictionary = {}      # zone id → Polygon2D
var dirt_view := DirtView.new()
var meadow_view := MeadowView.new()
## Der Schmutz selbst kommt aus DirtView; die Tönung macht saubere Zonen nur sanft grüner.
const ZONE_TINTS := [Color(0, 0, 0, 0), Color(0.5, 0.85, 0.3, 0.06), Color(0.5, 0.85, 0.3, 0.14), Color(0.3, 0.8, 0.35, 0.22)]
const LOCKED_TINT := Color(0.15, 0.15, 0.22, 0.5)
var _player: Node2D


func bind(world: SimWorld, player: Node2D) -> void:
	_world = world
	_player = player
	for n: ResourceNode in world.nodes.values():
		_on_node_added(n)
	for item: LooseItem in world.loose.values():
		_on_loose_added(item)
	for b: Building in world.buildings.values():
		_on_building_placed(b)
	world.node_added.connect(_on_node_added)
	world.node_changed.connect(_on_node_changed)
	world.node_removed.connect(_on_node_removed)
	world.loose_added.connect(_on_loose_added)
	world.loose_removed.connect(_on_loose_removed)
	world.loose_changed.connect(func(item: LooseItem) -> void:
		if _loose_views.has(item.id):
			_loose_views[item.id].set_count(item.count))
	world.item_collected.connect(_on_item_collected)
	world.wreck_hit.connect(_on_wreck_hit)
	world.building_placed.connect(_on_building_placed)
	world.building_changed.connect(_on_building_changed)
	world.building_removed.connect(_on_building_removed)
	world.ship_delivered.connect(_on_ship_delivered)
	world.courier_added.connect(_on_courier_added)
	world.courier_removed.connect(_on_courier_removed)
	world.courier_loaded.connect(_on_courier_loaded)
	world.point_stored.connect(func(p: Building, n: int) -> void:
		if _building_views.has(p.id):
			_building_views[p.id].show_sale(n, true)
		Sfx.play("courier", 0.08))
	world.too_hard.connect(_on_too_hard)
	world.hammer_impact.connect(func(n: ResourceNode, tier: int, one_hit: bool) -> void:
		if _node_views.has(n.id):
			_node_views[n.id].impact(tier, one_hit))
	world.boss_rally.connect(func(boss: ResourceNode, _c: int) -> void:
		for h: Helper in world.helpers.values():
			if h.rally_id == boss.id and _helper_views.has(h.id):
				_helper_views[h.id].emote("!"))
	world.boss_blocked.connect(func(boss: ResourceNode, have: int, need: int) -> void:
		Sfx.play("hammer", 0.05, -2.0, 1.35)
		if _node_views.has(boss.id):
			_node_views[boss.id].sparks()
		float_text(Vector2(boss.center_px()) + Vector2(0, -150), tr("BOSS_WAIT") % [have, need], Color(1.0, 0.85, 0.3)))
	world.node_respawned.connect(_on_node_respawned)
	for h: Helper in world.helpers.values():
		_on_helper_added(h)
	_build_zone_tints()
	for z in world.zones.zones:
		var site: Vector2i = z.get("site", Vector2i(-1, -1))
		if site.x >= 0:
			var sv := SiteView.new()
			sv.setup(world, str(z["id"]), site)
			add_child(sv)
	meadow_view.name = "Meadow"
	add_child(meadow_view)
	meadow_view.bind(world)
	dirt_view.name = "Dirt"
	add_child(dirt_view)
	dirt_view.bind(world)
	dirt_view.tiles_changed.connect(meadow_view.on_tiles_changed)
	world.zones.stage_changed.connect(func(_id: String, _st: int) -> void: _refresh_zone_tints())
	world.zone_unlocked.connect(func(_id: String) -> void: _refresh_zone_tints())
	world.helper_added.connect(_on_helper_added)
	world.helper_removed.connect(_on_helper_removed)
	for d: Drone in world.drones.values():
		_on_drone_added(d)
	for c: Collectible in world.collectibles.values():
		_on_collectible_added(c)
	world.collectible_added.connect(_on_collectible_added)
	world.collectible_found.connect(_on_collectible_found)
	world.drone_added.connect(_on_drone_added)
	world.drone_removed.connect(_on_drone_removed)
	world.helper_quip.connect(_on_helper_quip)


## Bodenfärbung je Zone: vermüllt braun, sauber grün, unentdeckt dunkel (Nebel).
func _build_zone_tints() -> void:
	for z in _world.zones.zones:
		var r: Rect2i = z["rect"]
		var poly := Polygon2D.new()
		var p := Vector2(r.position * 64)
		var sz := Vector2(r.size * 64)
		poly.polygon = PackedVector2Array([p, p + Vector2(sz.x, 0), p + sz, p + Vector2(0, sz.y)])
		poly.z_index = -9
		add_child(poly)
		_zone_tints[z["id"]] = poly
	_refresh_zone_tints(false)


## Bodenfarbe des Zonen-Themas (data/zone_themes.json), über dem Sand.
func _theme_ground(zone_id: String) -> Color:
	var theme := str(_world.zones.zone_by_id(zone_id).get("theme", ""))
	var g: Array = DataRegistry.zone_theme(theme).get("ground", [0, 0, 0, 0])
	return Color(float(g[0]), float(g[1]), float(g[2]), float(g[3]))


func _refresh_zone_tints(animate: bool = true) -> void:
	for z in _world.zones.summary(_world.nodes):
		var poly: Polygon2D = _zone_tints.get(z["id"])
		if poly == null:
			continue
		var target: Color = _theme_ground(str(z["id"])) if _world.zones.is_unlocked(str(z["id"])) else LOCKED_TINT
		if animate:
			create_tween().tween_property(poly, "color", target, 1.2)
		else:
			poly.color = target


func _on_helper_added(h: Helper) -> void:
	var view := HelperView.new()
	view.setup(h, _world.helper_cfg.get("names", []), _world.helper_cfg.get("colors", []))
	add_child(view)
	_helper_views[h.id] = view


func _on_collectible_added(c: Collectible) -> void:
	var view := CollectibleView.new()
	view.setup(c, str(_world.collectible_def(c.def_id).get("sprite", "")))
	add_child(view)
	_collectible_views[c.id] = view


func _on_collectible_found(c: Collectible, _def: Dictionary) -> void:
	var view: Node2D = _collectible_views.get(c.id)
	_collectible_views.erase(c.id)
	if view == null:
		return
	var tw := create_tween()
	tw.tween_property(view, "position", view.position + Vector2(0, -60), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "scale", Vector2(1.4, 1.4), 0.5)
	tw.parallel().tween_property(view, "modulate:a", 0.0, 0.5)
	tw.tween_callback(view.queue_free)


func _on_drone_added(d: Drone) -> void:
	var view := DroneView.new()
	view.setup(d)
	add_child(view)
	_drone_views[d.id] = view


func _on_drone_removed(id: int) -> void:
	if _drone_views.has(id):
		_drone_views[id].queue_free()
		_drone_views.erase(id)


func _on_helper_removed(id: int) -> void:
	if _helper_views.has(id):
		_helper_views[id].queue_free()
		_helper_views.erase(id)


## Bots sprechen nicht mehr, sie zeigen nur ein kleines Symbol (MS44).
func _on_helper_quip(h: Helper, key: String) -> void:
	if not _helper_views.has(h.id):
		return
	var sym := "♪"
	var col := Color(0.55, 0.85, 1.0)
	if key.begins_with("BOT_BORED_TOO_HARD"):
		sym = "?"
		col = Color(1.0, 0.85, 0.3)
	elif key.begins_with("BOT_BORED"):
		sym = "Zzz"
		col = Color(0.8, 0.85, 1.0)
	elif key.begins_with("HELPER_STUCK"):
		sym = "!?"
		col = Color(1.0, 0.6, 0.3)
	elif key.begins_with("HELPER_HIRED") or key == "HELPER_LOVE":
		sym = "♥"
		col = Color(1.0, 0.45, 0.55)
	_helper_views[h.id].emote(sym, col)


## Kurzer schwebender Text in der Welt (steigt auf, verblasst).
func float_text(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 40)
	l.position = at - Vector2(160, 20)
	l.z_index = 30
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 50, 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func _on_too_hard(node: ResourceNode, _tool: String) -> void:
	if _node_views.has(node.id):
		_node_views[node.id].sparks()


func _on_node_respawned(node: ResourceNode) -> void:
	# node_added hat die View schon erzeugt; kurzer Pop beim Erscheinen.
	if _node_views.has(node.id):
		var v: Node2D = _node_views[node.id]
		v.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(v, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_node_added(node: ResourceNode) -> void:
	var view := ResourceNodeView.new()
	view.setup(node)
	add_child(view)
	_node_views[node.id] = view


func _on_node_changed(node: ResourceNode) -> void:
	if _node_views.has(node.id):
		_node_views[node.id].refresh(node)


func _on_node_removed(id: int) -> void:
	if _node_views.has(id):
		# Zerbricht in Rustys Nähe: ein Bonk (Hammer klingt nur noch beim Zerbrechen, MS63)
		if (_node_views[id] as Node2D).position.distance_to(_player.global_position) < 900.0:
			Sfx.play_throttled("hammer", 0.12, 0.08)
		_node_views[id].queue_free()
		_node_views.erase(id)


func _on_wreck_hit(node: ResourceNode) -> void:
	# Hammerschlag hörbar, wenn er in Rustys Nähe passiert (Bots weit weg bleiben leise)
	# Bots: nur jeder dritte Schlag hörbar (gegen Dauerklopfen); Rustys Bonk kommt über hammer_impact
	if Vector2(node.center_px()).distance_to(_player.global_position) < 900.0:
		pass  # Schläge sind still; es klingt nur, wenn etwas zerbricht (MS63)
	if _node_views.has(node.id):
		_node_views[node.id].wobble()


func _on_loose_added(item: LooseItem) -> void:
	var view := LooseItemView.new()
	view.setup(item)
	add_child(view)
	_loose_views[item.id] = view


func _on_loose_removed(id: int) -> void:
	if _loose_views.has(id):
		_loose_views[id].queue_free()
		_loose_views.erase(id)


func _on_building_placed(b: Building) -> void:
	var view := BuildingView.new()
	view.setup(b)
	add_child(view)
	_building_views[b.id] = view


var _courier_views: Dictionary = {}


func _on_courier_added(c: Courier) -> void:
	var v := CourierView.new()
	v.setup(c)
	add_child(v)
	_courier_views[c.id] = v
	Sfx.play("courier", 0.1, -4.0)


func _on_courier_removed(id: int) -> void:
	if _courier_views.has(id):
		_courier_views[id].leave()
		_courier_views.erase(id)


## Die Teile fliegen im Bogen aus Rusty in den Kurier.
func _on_courier_loaded(c: Courier, items: Dictionary) -> void:
	var shown := 0
	for item: String in items:
		for k in mini(int(items[item]), 4):
			if shown >= 10:
				break
			_fly_to_ship(item, _player.global_position, Vector2(c.pos), shown * 0.03)
			shown += 1
	Sfx.play("courier", 0.08)


## Ansicht des Schiffs (für Feier und Abflug), null ohne Schiff.
func ship_view() -> BuildingView:
	var s := _world.ship()
	return _building_views.get(s.id) if s != null else null


func _on_building_changed(b: Building) -> void:
	if _building_views.has(b.id):
		_building_views[b.id].refresh(b)


func _on_building_removed(id: int) -> void:
	if _building_views.has(id):
		_building_views[id].queue_free()
		_building_views.erase(id)


## Abgabe: ein Betrag über dem Schiff (groß, wenn Rusty abliefert), bei Rusty fliegen die Teile
## im Bogen ins Schiff und das Schiff wippt.
func _on_ship_delivered(items: Dictionary, bolts: int, by_player: bool) -> void:
	var view := ship_view()
	if view == null:
		return
	view.show_sale(bolts, by_player)
	if not by_player:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.coin_stream(view.global_position, bolts)
		return
	var target := view.global_position
	var start := _player.global_position
	var shown := 0
	for item: String in items:
		for k in mini(int(items[item]), 4):
			if shown >= 12:
				break
			_fly_to_ship(item, start, target, shown * 0.035)
			shown += 1
	if view.ship_fx != null:
		get_tree().create_timer(0.3).timeout.connect(view.ship_fx.bump)


func _fly_to_ship(item: String, start: Vector2, target: Vector2, delay: float) -> void:
	var fly := Sprite2D.new()
	fly.texture = DataRegistry.item_icon(item)
	fly.global_position = start
	fly.z_index = 20
	fly.visible = delay <= 0.0
	add_child(fly)
	var mid := (start + target) * 0.5 + Vector2(randf_range(-60, 60), -160)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: fly.visible = true)
	tw.tween_method(func(t: float) -> void:
		fly.global_position = start.lerp(mid, t).lerp(mid.lerp(target, t), t)
		fly.scale = Vector2.ONE * lerpf(1.0, 0.5, t), 0.0, 1.0, 0.32).set_ease(Tween.EASE_IN)
	tw.tween_callback(fly.queue_free)


## Icon fliegt im kleinen Bogen vom Fundort zu Rusty, dreht sich, schrumpft und verschwindet mit
## einem Plopp-Wölkchen; Rusty bläht sich kurz auf.
func _on_item_collected(item_id: String, from_pos: Vector2i) -> void:
	var fly := Sprite2D.new()
	fly.texture = DataRegistry.item_icon(item_id)
	fly.position = Vector2(from_pos)
	fly.z_index = 20
	add_child(fly)
	var start := Vector2(from_pos)
	var bend := Vector2(randf_range(-30, 30), randf_range(-50, -20))
	var spin := randf_range(-1.0, 1.0) * PI
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var target := _player.global_position
		var mid := (start + target) * 0.5 + bend
		fly.global_position = start.lerp(mid, t).lerp(mid.lerp(target, t), t)
		fly.rotation = spin * t
		fly.scale = Vector2.ONE * lerpf(1.1, 0.35, t * t), 0.0, 1.0, 0.24).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_puff(_player.global_position)
		if _player.has_method("gulp"):
			_player.gulp()
		Sfx.play_throttled("plop", 0.12, 0.1)
		fly.queue_free())


## Kleines Plopp-Wölkchen (weicher Kreis, wächst und verblasst).
func _puff(at: Vector2) -> void:
	var p := Sprite2D.new()
	p.texture = ShipFx._soft_dot()
	p.global_position = at + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	p.z_index = 21
	p.modulate = Color(1, 1, 1, 0.8)
	p.scale = Vector2.ONE * 0.6
	add_child(p)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE * 1.6, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(p.queue_free)
