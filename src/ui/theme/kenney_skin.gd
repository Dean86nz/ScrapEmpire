class_name KenneySkin
extends RefCounted
## Einheitlicher Menü-Stil aus dem Kenney UI Pack (CC0, assets/ui/kenney/, MS53).
## Knöpfe: grau mit Tiefe, Fokus gelb glänzend, gedrückt gelb flach. Panel: helle Platte mit Tiefe.

const DIR := "res://assets/ui/kenney/"
const INK := Color(0.165, 0.165, 0.2)

static var _theme: Theme


static func _box(file: String, margin: int, pad := Vector4(28, 14, 28, 20)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR + file)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin + 8  # untere Kante = Tiefe
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## Theme für ein ganzes Menü (Panel, Knöpfe, Titel). Wird einmal gebaut und geteilt.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _box("btn_grey.png", 24))
	t.set_stylebox("hover", "Button", _box("btn_yellow.png", 24))
	t.set_stylebox("focus", "Button", _box("btn_yellow.png", 24))
	t.set_stylebox("pressed", "Button", _box("btn_yellow_pressed.png", 24, Vector4(28, 20, 28, 14)))
	t.set_stylebox("hover_pressed", "Button", _box("btn_yellow_pressed.png", 24, Vector4(28, 20, 28, 14)))
	t.set_stylebox("disabled", "Button", _box("btn_grey.png", 24))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	t.set_font_size("font_size", "Button", 28)
	t.set_stylebox("panel", "PanelContainer", _box("panel.png", 40, Vector4(56, 40, 56, 52)))
	t.set_color("font_color", "Label", INK)
	_theme = t
	return t


## Panel und alle Knöpfe darunter auf den Kenney-Stil stellen.
static func apply(panel: Control) -> void:
	panel.theme = theme()
	panel.remove_theme_stylebox_override("panel")
	for b in panel.find_children("*", "Button", true, false):
		var btn := b as Button
		for s in ["normal", "hover", "focus", "pressed", "disabled"]:
			btn.remove_theme_stylebox_override(s)
