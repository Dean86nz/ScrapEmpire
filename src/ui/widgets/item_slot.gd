extends PanelContainer
## Ein Inventar-Slot (72×72): Icon und Anzahl. Leer = nur Rahmen. Ausgewählt = oranger Rahmen.

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	_style_normal = get_theme_stylebox("panel")
	_style_selected = _style_normal.duplicate()
	_style_selected.border_color = Color(0.95, 0.55, 0.16)
	_style_selected.border_width_left = 6
	_style_selected.border_width_top = 6
	_style_selected.border_width_right = 6
	_style_selected.border_width_bottom = 6
	_style_selected.bg_color = Color(1, 1, 1, 0.85)


func set_item(item_id: String, count: int) -> void:
	if item_id == "" or count <= 0:
		_icon.texture = null
		_count.text = ""
		return
	_icon.texture = DataRegistry.item_icon(item_id)
	_count.text = str(count)


func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _style_selected if selected else _style_normal)
