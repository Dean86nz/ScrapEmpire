class_name LooseItemView
extends Node2D
## Ein loses Item am Boden: Icon mit leichtem Auf-und-ab.

var item_id_num: int = -1
var _sprite := Sprite2D.new()
var _phase := 0.0
var _count: Label


func setup(item: LooseItem) -> void:
	item_id_num = item.id
	_sprite.texture = DataRegistry.item_icon(item.item_id)
	_sprite.scale = Vector2.ONE * 1.1
	add_child(_sprite)
	position = Vector2(item.pos)
	_phase = float(item.id % 7)
	z_index = 1
	set_count(item.count)


## Bündel (MS64): ab 2 Stück größeres Icon mit „×N“.
func set_count(n: int) -> void:
	if n <= 1:
		if _count != null:
			_count.visible = false
		_sprite.scale = Vector2.ONE * 1.1
		return
	_sprite.scale = Vector2.ONE * (1.3 + minf(n, 40) * 0.01)
	if _count == null:
		_count = Label.new()
		_count.add_theme_font_size_override("font_size", 22)
		_count.add_theme_color_override("font_color", Color.WHITE)
		_count.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
		_count.add_theme_constant_override("outline_size", 6)
		_count.position = Vector2(8, -6)
		add_child(_count)
	_count.visible = true
	_count.text = "×%d" % n


func _process(delta: float) -> void:
	_phase += delta * 4.0
	_sprite.position.y = -4.0 + sin(_phase) * 3.0
