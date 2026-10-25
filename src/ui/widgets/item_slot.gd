extends PanelContainer
## Ein Inventar-Slot (72×72): Icon und Anzahl. Leer = nur Rahmen.

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count


func set_item(item_id: String, count: int) -> void:
	if item_id == "" or count <= 0:
		_icon.texture = null
		_count.text = ""
		return
	_icon.texture = DataRegistry.item_icon(item_id)
	_count.text = str(count)
