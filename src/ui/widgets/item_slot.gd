extends PanelContainer
## Ein Inventar-Slot (72×72): Icon und Anzahl. Leer = nur Rahmen. Ausgewählt = oranger Rahmen.

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _last_item := ""
var _last_count := 0
var _bump: Tween


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
		_last_item = ""
		_last_count = 0
		return
	_icon.texture = DataRegistry.item_icon(item_id)
	_count.text = str(count)
	if item_id == _last_item and count > _last_count and is_inside_tree():
		_bounce()
	_last_item = item_id
	_last_count = count


## Mehr im Slot: Zahl und Icon hüpfen kurz.
func _bounce() -> void:
	if _bump != null:
		_bump.kill()
	_count.pivot_offset = _count.size * 0.5
	_icon.pivot_offset = _icon.size * 0.5
	_count.scale = Vector2(1.5, 1.5)
	_icon.scale = Vector2(1.15, 1.15)
	_bump = create_tween().set_parallel(true)
	_bump.tween_property(_count, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bump.tween_property(_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _style_selected if selected else _style_normal)
