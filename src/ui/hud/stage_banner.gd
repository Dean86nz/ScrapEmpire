class_name StageBanner
extends PanelContainer
## Großes Jubel-Schild nach einer Schiffsreparatur: Schiffsbild, „Schiff repariert!“, Stufe und was
## neu ist. Springt auf, bleibt ein paar Sekunden und blendet sich aus; blockiert keine Eingabe.

const SHOW_SECONDS := 3.6

var _icon := TextureRect.new()
var _title := Label.new()
var _sub := Label.new()
var _gifts := Label.new()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.96, 0.8, 0.97)
	box.border_color = Color(0.165, 0.165, 0.2)
	box.set_border_width_all(6)
	box.set_corner_radius_all(22)
	box.content_margin_left = 36
	box.content_margin_right = 44
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	_icon.custom_minimum_size = Vector2(150, 150)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_style(_title, 52, Color(0.95, 0.5, 0.12))
	_style(_sub, 32, Color(0.165, 0.165, 0.2))
	_style(_gifts, 28, Color(0.2, 0.55, 0.2))
	col.add_child(_title)
	col.add_child(_sub)
	col.add_child(_gifts)


func _style(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)


func show_stage(stage: int, stage_name: String, sprite_path: String, gifts: Array[String]) -> void:
	show_card(tr("STAGE_BANNER_TITLE"), tr("STAGE_BANNER_SUB") % [stage, stage_name],
		tr("STAGE_BANNER_NEW") % " · ".join(gifts) if not gifts.is_empty() else "", sprite_path)


func show_card(title: String, sub: String, extra: String, icon_path: String, seconds: float = SHOW_SECONDS) -> void:
	_title.text = title
	_sub.text = sub
	_gifts.text = extra
	_gifts.visible = extra != ""
	_icon.texture = load(icon_path) if icon_path != "" else null
	visible = true
	reset_size()
	await get_tree().process_frame
	pivot_offset = size * 0.5
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, 170)
	if _tween != null:
		_tween.kill()
	scale = Vector2(0.3, 0.3)
	modulate = Color.WHITE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func() -> void: visible = false)
