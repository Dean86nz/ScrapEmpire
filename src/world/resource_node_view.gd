class_name ResourceNodeView
extends Node2D
## Darstellung eines Schrott-Objekts. Haufen schrumpfen mit der Menge, Objekte wackeln bei
## Treffern. Ab Tier 2 zeigt ein Abzeichen die Härte-Stufe; „Zu hart“ erzeugt Funken.

const FALLBACK_TEXTURES := {
	"scrap_pile": "res://assets/sprites/nodes/scrap_pile.svg",
	"copper_tangle": "res://assets/sprites/nodes/copper_tangle.svg",
	"plastic_crumbs": "res://assets/sprites/nodes/plastic_crumbs.svg",
	"wreck": "res://assets/sprites/nodes/fridge.svg",
}
const TIER_COLORS := {
	1: Color(0.6, 0.65, 0.7), 2: Color(0.3, 0.75, 0.4), 3: Color(0.25, 0.6, 0.95),
	4: Color(0.7, 0.4, 0.9), 5: Color(1.0, 0.7, 0.2),
}

var node_id: int = -1
var _sprite := Sprite2D.new()
var _badge: Label
var _tween: Tween
var _sparks: CPUParticles2D
var _boss_bar: ProgressBar


func setup(node: ResourceNode) -> void:
	node_id = node.id
	var path := str(ResourceNode.defs.get(node.kind, {}).get("sprite", FALLBACK_TEXTURES.get(node.kind, "")))
	if path != "" and ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)
	position = Vector2(node.center_px())
	if node.boss:
		_setup_boss(node)
	elif node.tier >= 2:
		_badge = Label.new()
		_badge.text = "T%d" % node.tier
		_badge.add_theme_font_size_override("font_size", 22)
		_badge.add_theme_color_override("font_color", Color.WHITE)
		_badge.add_theme_color_override("font_outline_color", TIER_COLORS.get(node.tier, Color.BLACK))
		_badge.add_theme_constant_override("outline_size", 8)
		_badge.position = Vector2(14, -50)
		add_child(_badge)
	refresh(node)


func _setup_boss(node: ResourceNode) -> void:
	_sprite.position = Vector2(0, -40)
	var head := Label.new()
	head.text = "%s · %s" % [tr("BOSS_LABEL"), tr(str(ResourceNode.defs.get(node.kind, {}).get("name_key", node.kind)))]
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color.WHITE)
	head.add_theme_color_override("font_outline_color", Color(0.75, 0.2, 0.15))
	head.add_theme_constant_override("outline_size", 9)
	head.position = Vector2(-220, -150)
	head.size = Vector2(440, 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	_boss_bar.position = Vector2(-90, -116)
	_boss_bar.size = Vector2(180, 16)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.165, 0.165, 0.2, 0.8)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.3, 0.25)
	fill.set_corner_radius_all(8)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	add_child(_boss_bar)
	var need := Label.new()
	need.text = tr("BOSS_NEEDS") % node.bots_needed
	need.add_theme_font_size_override("font_size", 22)
	need.add_theme_color_override("font_color", Color.WHITE)
	need.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	need.add_theme_constant_override("outline_size", 7)
	need.position = Vector2(-220, 34)
	need.size = Vector2(440, 30)
	need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(need)


func refresh(node: ResourceNode) -> void:
	if _boss_bar != null:
		_boss_bar.value = float(node.amount) / float(maxi(node.max_amount, 1))
	if not node.is_pile():
		_sprite.scale = Vector2.ONE
		return
	var t := float(node.amount) / float(maxi(node.max_amount, 1))
	_sprite.scale = Vector2.ONE * (0.55 + 0.45 * t)


func wobble() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_sprite, "rotation", 0.18, 0.05)
	_tween.tween_property(_sprite, "rotation", -0.14, 0.08)
	_tween.tween_property(_sprite, "rotation", 0.0, 0.08)


## Funken bei zu niedrigem Werkzeug: kurzer Partikelstoß plus Wackeln.
func sparks() -> void:
	wobble()
	if _sparks == null:
		_sparks = CPUParticles2D.new()
		_sparks.one_shot = true
		_sparks.explosiveness = 1.0
		_sparks.amount = 18
		_sparks.lifetime = 0.45
		_sparks.direction = Vector2(0, -1)
		_sparks.spread = 70.0
		_sparks.initial_velocity_min = 160.0
		_sparks.initial_velocity_max = 260.0
		_sparks.gravity = Vector2(0, 600)
		_sparks.scale_amount_min = 3.0
		_sparks.scale_amount_max = 5.0
		_sparks.color = Color(1.0, 0.85, 0.3)
		_sparks.position = Vector2(0, -10)
		_sparks.z_index = 10
		add_child(_sparks)
	_sparks.restart()
	_sparks.emitting = true
