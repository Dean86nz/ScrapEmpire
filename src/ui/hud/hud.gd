extends CanvasLayer
## Spiel-HUD: Bolts oben links, Hotbar oben rechts (mit Auswahl), Hinweiszeile unten.

const ITEM_SLOT := preload("res://src/ui/widgets/item_slot.tscn")

@onready var _bolts_label: Label = $BoltsPanel/HBox/BoltsLabel
@onready var _hotbar: HBoxContainer = $Hotbar
@onready var _hint: Label = $HintLabel
@onready var _xp_bar: HBoxContainer = $XpBar
@onready var _research: HBoxContainer = $Research
@onready var _research_label: Label = $Research/Label
@onready var _research_bar: ProgressBar = $Research/Bar
@onready var _research_time: Label = $Research/Time
@onready var _task_row: Label = $TaskRow
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
var _bolts_shown := 0
var _bolts_tween: Tween


func _process(_delta: float) -> void:
	if _world == null:
		return
	var t := _world.tech
	_research.visible = t.is_researching()
	if t.is_researching():
		_research_label.text = "%s: %s" % [tr("HUD_RESEARCH"), tr(str(t.by_id[t.current_id]["name_key"]))]
		_research_bar.value = t.progress_fraction()
		_research_time.text = "%d s" % int(ceil(t.remaining_ticks / 20.0))


## Hotbar neu aufbauen (z. B. nach Rucksack / Taschen).
func rebuild_hotbar() -> void:
	for child in _hotbar.get_children():
		child.queue_free()
	_slots.clear()
	for i in _inventory.slot_count:
		var slot := ITEM_SLOT.instantiate()
		_hotbar.add_child(slot)
		_slots.append(slot)
	_refresh()
	set_selected_slot(_selected)


func _ready() -> void:
	add_child(stage_banner)
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


func set_hint(text: String) -> void:
	_hint.text = text


func set_tutorial(text: String) -> void:
	_tutorial.visible = text != ""
	_tutorial_label.text = text


## Aufgaben-Kette: Icons, aktueller Schritt in Klammern, Status.
func refresh_tasks(tasks: TaskList, status: String = "") -> void:
	if tasks.steps.is_empty():
		_task_row.text = ""
		return
	var parts: Array[String] = []
	for i in tasks.steps.size():
		var icon := TaskList.type_icon(int(tasks.steps[i]["type"]))
		parts.append("[%s]" % icon if (tasks.active and i == tasks.index) else icon)
	var state := tr("TASK_HUD_ON") if tasks.active else tr("TASK_HUD_OFF")
	_task_row.text = "%s  %s %s" % [tr("TASK_HUD"), " ".join(parts), state + (("  ·  " + status) if status != "" else "")]


func set_selected_slot(index: int) -> void:
	_selected = index
	for i in _slots.size():
		_slots[i].set_selected(i == index)


func _refresh() -> void:
	for i in mini(_slots.size(), _inventory.slots.size()):
		var s: Dictionary = _inventory.slots[i]
		_slots[i].set_item(s["item"], s["count"])
