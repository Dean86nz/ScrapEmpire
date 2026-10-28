extends CanvasLayer
## Spiel-HUD: Bolts oben links, Hotbar oben rechts (mit Auswahl), Hinweiszeile unten.

const ITEM_SLOT := preload("res://src/ui/widgets/item_slot.tscn")

@onready var _bolts_label: Label = $BoltsPanel/HBox/BoltsLabel
@onready var _hotbar: VBoxContainer = $Hotbar   # Zeilen zu je höchstens HOTBAR_ROW Plätzen
const HOTBAR_ROW := 6
@onready var _hint: Label = $HintLabel
@onready var _xp_bar: HBoxContainer = $XpBar
@onready var _research: HBoxContainer = $Research
@onready var _research_label: Label = $Research/Label
@onready var _research_bar: ProgressBar = $Research/Bar
@onready var _research_time: Label = $Research/Time
@onready var minimap: Minimap = $Minimap
@onready var _tutorial: PanelContainer = $Tutorial
@onready var _tutorial_label: Label = $Tutorial/Label
@onready var _planet_bar: ProgressBar = $PlanetPanel/HBox/Bar
@onready var _planet_label: Label = $PlanetPanel/HBox/Value

var _inventory: Inventory
var _world: SimWorld
var _slots: Array = []
var _selected := 0
var stage_banner := StageBanner.new()
var _goal_panel := PanelContainer.new()
var _goal_icon := TextureRect.new()
var _goal_label := Label.new()
var _goal_timer := 0.0
var _courier_panel := PanelContainer.new()
var _coin_gate := 0.0
var _courier_label := Label.new()
var _bolts_shown := 0
var _bolts_tween: Tween


func _process(delta: float) -> void:
	if _world == null:
		return
	_goal_timer -= delta
	if _goal_timer <= 0.0:
		_goal_timer = 0.4
		_refresh_goal()
	_refresh_courier()
	var t := _world.tech
	_research.visible = t.is_researching()
	if t.is_researching():
		_research_label.text = "%s: %s" % [tr("HUD_RESEARCH"), tr(str(t.by_id[t.current_id]["name_key"]))]
		_research_bar.value = t.progress_fraction()
		_research_time.text = "%d s" % int(ceil(t.remaining_ticks / 20.0))


## Hotbar neu aufbauen (z. B. nach Rucksack / Taschen).
func rebuild_hotbar() -> void:
	for child in _hotbar.get_children():
		_hotbar.remove_child(child)
		child.queue_free()
	_slots.clear()
	var row: HBoxContainer = null
	for i in _inventory.slot_count:
		if i % HOTBAR_ROW == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_END
			row.add_theme_constant_override("separation", 8)
			_hotbar.add_child(row)
		var slot := ITEM_SLOT.instantiate()
		row.add_child(slot)
		_slots.append(slot)
	_refresh()
	set_selected_slot(_selected)


func _ready() -> void:
	add_to_group("hud")
	add_child(stage_banner)
	_build_goal_panel()
	_build_courier_panel()
	set_hint(tr("HUD_HINT_GAME"))
	set_bolts(0)


func bind(world: SimWorld) -> void:
	_world = world
	_inventory = world.player.inventory
	_inventory.changed.connect(_refresh)
	world.bolts_changed.connect(set_bolts)
	world.inventory_resized.connect(rebuild_hotbar)
	set_bolts(world.bolts)
	_xp_bar.bind(world.progression)
	rebuild_hotbar()
	set_selected_slot(0)


func bind_minimap(player: Node2D) -> void:
	minimap.bind(_world, player)


func toggle_minimap() -> void:
	minimap.visible = not minimap.visible


func set_planet(fraction: float) -> void:
	_planet_bar.value = fraction
	_planet_label.text = "%d %%" % int(round(fraction * 100.0))


## Bolts zählen sichtbar hoch (bei Gewinn) und das Feld hüpft; Ausgaben springen sofort.
func set_bolts(value: int) -> void:
	if _bolts_tween != null:
		_bolts_tween.kill()
	if value <= _bolts_shown or not is_inside_tree():
		_show_bolts(value)
		return
	var panel: Control = $BoltsPanel
	panel.pivot_offset = panel.size * 0.5
	_bolts_tween = create_tween()
	_bolts_tween.set_parallel(true)
	_bolts_tween.tween_method(_show_bolts, _bolts_shown, value, clampf((value - _bolts_shown) / 200.0, 0.25, 0.8))
	panel.scale = Vector2(1.12, 1.12)
	_bolts_tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_bolts(value: int) -> void:
	_bolts_shown = value
	_bolts_label.text = "%s %s" % [Fmt.int_str(value), tr("HUD_BOLTS")]


## Ein paar Münzen fliegen von `world_px` (Schiff) zur Bolts-Anzeige (gedrosselt).
func coin_stream(world_px: Vector2, bolts: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _coin_gate:
		return
	_coin_gate = now + 0.25
	var start := get_viewport().get_canvas_transform() * world_px
	var target := ($BoltsPanel as Control).global_position + Vector2(40, 26)
	var n := clampi(int(ceil(bolts / 15.0)), 1, 5)
	for i in n:
		var c := TextureRect.new()
		c.texture = load("res://assets/sprites/ui/bolt.svg")
		c.custom_minimum_size = Vector2(26, 26)
		c.size = Vector2(26, 26)
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = start + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		add_child(c)
		var mid := (c.position + target) * 0.5 + Vector2(randf_range(-80, 80), -120)
		var from := c.position
		var tw := c.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_method(func(t: float) -> void: c.position = from.lerp(mid, t).lerp(mid.lerp(target, t), t), 0.0, 1.0, 0.7).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)


func _build_courier_panel() -> void:
	_courier_panel.add_theme_stylebox_override("panel", ($BoltsPanel as PanelContainer).get_theme_stylebox("panel"))
	_courier_panel.anchor_left = 1.0
	_courier_panel.anchor_right = 1.0
	_courier_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_courier_panel.offset_right = -32.0
	_courier_panel.offset_top = 196.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/sprites/robot/courier.svg")
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_courier_label.add_theme_font_size_override("font_size", 22)
	row.add_child(icon)
	row.add_child(_courier_label)
	_courier_panel.add_child(row)
	_courier_panel.visible = false
	add_child(_courier_panel)


## Kurier: grün „bereit“, sonst Wartezeit oder unterwegs. Nur sichtbar, wenn freigeschaltet.
func _refresh_courier() -> void:
	var st := NetworkSystem.courier_stats(_world)
	_courier_panel.visible = not st.is_empty()
	if st.is_empty():
		return
	var kb := "" if InputRouter.is_gamepad else "_KB"
	if _world.courier_cooldown > 0:
		_courier_label.text = "%d s" % int(ceil(_world.courier_cooldown / 20.0))
		_courier_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	elif _world.couriers.size() >= int(st.get("count", 1)):
		_courier_label.text = tr("HUD_COURIER_BUSY")
		_courier_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	else:
		_courier_label.text = tr("HUD_COURIER_READY" + kb)
		_courier_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5))


func _build_goal_panel() -> void:
	_goal_panel.add_theme_stylebox_override("panel", ($BoltsPanel as PanelContainer).get_theme_stylebox("panel"))
	_goal_panel.position = Vector2(24, 136)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_goal_icon.custom_minimum_size = Vector2(36, 36)
	_goal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_goal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_goal_label.add_theme_font_size_override("font_size", 24)
	row.add_child(_goal_icon)
	row.add_child(_goal_label)
	_goal_panel.add_child(row)
	_goal_panel.visible = false
	add_child(_goal_panel)


## Nächstes Ziel im HUD: Leistbares zuerst (grün), sonst ein freier Skillpunkt, sonst das
## günstigste Schiff-Ziel mit „noch N Bolts“.
func _refresh_goal() -> void:
	var g := GoalHint.next_goal(_world)
	_goal_panel.visible = not g.is_empty()
	if g.is_empty():
		return
	_goal_label.text = str(g["text"])
	_goal_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5) if g["ready"] else Color(1, 1, 1))
	var path := str(g["icon"])
	if _goal_icon.texture == null or _goal_icon.texture.resource_path != path:
		_goal_icon.texture = load(path)
	_goal_panel.reset_size()


func set_hint(text: String) -> void:
	_hint.text = text


func set_tutorial(text: String) -> void:
	_tutorial.visible = text != ""
	_tutorial_label.text = text


func set_selected_slot(index: int) -> void:
	_selected = index
	for i in _slots.size():
		_slots[i].set_selected(i == index)


func _refresh() -> void:
	for i in mini(_slots.size(), _inventory.slots.size()):
		var s: Dictionary = _inventory.slots[i]
		_slots[i].set_item(s["item"], s["count"])
