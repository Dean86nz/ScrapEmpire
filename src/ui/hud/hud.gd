extends CanvasLayer
## Spiel-HUD: Bolts oben links, Hotbar oben rechts (mit Auswahl), Hinweiszeile unten.

const ITEM_SLOT := preload("res://src/ui/widgets/item_slot.tscn")

@onready var _bolts_label: Label = $BoltsLabel
@onready var _hotbar: HBoxContainer = $Hotbar
@onready var _hint: Label = $HintLabel
@onready var _xp_bar: HBoxContainer = $XpBar
@onready var _research: HBoxContainer = $Research
@onready var _research_label: Label = $Research/Label
@onready var _research_bar: ProgressBar = $Research/Bar
@onready var _research_time: Label = $Research/Time

var _inventory: Inventory
var _world: SimWorld
var _slots: Array = []
var _selected := 0


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


func set_bolts(value: int) -> void:
	_bolts_label.text = "%d %s" % [value, tr("HUD_BOLTS")]


func set_hint(text: String) -> void:
	_hint.text = text


func set_selected_slot(index: int) -> void:
	_selected = index
	for i in _slots.size():
		_slots[i].set_selected(i == index)


func _refresh() -> void:
	for i in mini(_slots.size(), _inventory.slots.size()):
		var s: Dictionary = _inventory.slots[i]
		_slots[i].set_item(s["item"], s["count"])
