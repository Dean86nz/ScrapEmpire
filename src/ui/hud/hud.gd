extends CanvasLayer
## Spiel-HUD: Bolts oben links, Hotbar oben rechts (mit Auswahl), Hinweiszeile unten.

const ITEM_SLOT := preload("res://src/ui/widgets/item_slot.tscn")

@onready var _bolts_label: Label = $BoltsLabel
@onready var _hotbar: HBoxContainer = $Hotbar
@onready var _hint: Label = $HintLabel

var _inventory: Inventory
var _slots: Array = []
var _selected := 0


func _ready() -> void:
	set_hint(tr("HUD_HINT_GAME"))
	set_bolts(0)


func bind(world: SimWorld) -> void:
	_inventory = world.player.inventory
	for child in _hotbar.get_children():
		child.queue_free()
	_slots.clear()
	for i in _inventory.slot_count:
		var slot := ITEM_SLOT.instantiate()
		_hotbar.add_child(slot)
		_slots.append(slot)
	_inventory.changed.connect(_refresh)
	world.bolts_changed.connect(set_bolts)
	set_bolts(world.bolts)
	_refresh()
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
	for i in _slots.size():
		var s: Dictionary = _inventory.slots[i]
		_slots[i].set_item(s["item"], s["count"])
