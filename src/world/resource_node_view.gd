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

const JUNK_SHADER := """
shader_type canvas_item;
varying vec2 wpos;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;   // Objektmitte: jedes Objekt rostet anders
}
void fragment() {
	float seed = fract(sin(dot(wpos, vec2(12.9898, 78.233))) * 437.585) * 20.0;
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(c.rgb, vec3(g), 0.15);
	float rust = smoothstep(0.66, 0.82, n(UV * 13.0 + seed)) * 0.7 + smoothstep(0.7, 0.9, n(UV * 31.0 - seed)) * 0.3;
	col = mix(col, vec3(0.55, 0.33, 0.18), rust * 0.42);
	float grime = smoothstep(0.55, 1.0, UV.y) * 0.35;
	col *= 1.0 - grime;
	COLOR = vec4(col, c.a);
}
"""
static var _junk_mat: ShaderMaterial
var _sprite_base_scale := 1.0
var _boss_need: Label
var _boss_node: ResourceNode
var _boss_tick := 0
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
	# MS68: Müll-Look – Rostflecken, Schmutzrand unten, leicht entsättigt (nicht bei Bossen,
	# Haufen und Bonus-Müll), damit Objekte eindeutig nach Müll aussehen.
	if not node.boss and not node.is_pile() and not node.bonus:
		if _junk_mat == null:
			_junk_mat = ShaderMaterial.new()   # ein Material für alle Objekte (Leistung)
			var sh := Shader.new()
			sh.code = JUNK_SHADER
			_junk_mat.shader = sh
		_sprite.material = _junk_mat
	# Varianten (MS58): gleiches Bild, eigene Farbe und Größe
	var vd: Dictionary = ResourceNode.defs.get(node.kind, {})
	if vd.has("tint"):
		_sprite.self_modulate = Color.html(str(vd["tint"]))
	if vd.has("scale"):
		_sprite_base_scale = float(vd["scale"])
		_sprite.scale = Vector2.ONE * _sprite_base_scale
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
	_boss_need = need
	_boss_node = node
	need.text = tr("BOSS_NEEDS") % node.bots_needed
	need.add_theme_font_size_override("font_size", 22)
	need.add_theme_color_override("font_color", Color.WHITE)
	need.add_theme_color_override("font_outline_color", Color(0.165, 0.165, 0.2))
	need.add_theme_constant_override("outline_size", 7)
	need.position = Vector2(-220, 34)
	need.size = Vector2(440, 30)
	need.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(need)


## Boss: laufend „3/6 Bots da · 2 unterwegs“ bzw. „Es fehlen 2 Bots“ (MS48).
func _process(_delta: float) -> void:
	if _boss_need == null or _boss_node == null:
		return
	_boss_tick -= 1
	if _boss_tick > 0:
		return
	_boss_tick = 15
	var w := SimClock.world
	var at := BossSystem.helpers_at(w, _boss_node)
	var coming := BossSystem.helpers_coming(w, _boss_node)
	var missing := BossSystem.helpers_missing(w, _boss_node)
	if missing > 0 and w.unlocked_features.has("helpers"):
		_boss_need.text = tr("BOSS_MISSING") % missing
		_boss_need.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	elif at + coming == 0 or missing > 0:
		_boss_need.text = tr("BOSS_NEEDS") % _boss_node.bots_needed
		_boss_need.add_theme_color_override("font_color", Color.WHITE)
	else:
		var txt := tr("BOSS_COUNT") % [at, _boss_node.bots_needed]
		if coming > 0:
			txt += " · " + tr("BOSS_COMING") % coming
		_boss_need.text = txt
		_boss_need.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if at >= _boss_node.bots_needed else Color.WHITE)


func refresh(node: ResourceNode) -> void:
	if _boss_bar != null:
		_boss_bar.value = float(node.amount) / float(maxi(node.max_amount, 1))
	if not node.is_pile():
		_sprite.scale = Vector2.ONE * _sprite_base_scale
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


## Rustys Hammerschlag (MS43): je höher die Werkzeugstufe, desto mehr Funken, stärkeres
## Wackeln und ein Schockwellen-Ring; beim Ein-Schlag zusätzlich ein großer Stern.
func impact(power: int, one_hit: bool) -> void:
	sparks()
	_sparks.amount = 10 + 8 * power
	_sparks.initial_velocity_max = 220.0 + 50.0 * power
	_sparks.color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.45, 0.2), power / 5.0)
	_sparks.restart()
	_sparks.emitting = true
	var ring := ImpactRing.new()
	ring.radius_to = 50.0 + 26.0 * power + (60.0 if one_hit else 0.0)
	ring.width = 4.0 + 1.5 * power
	ring.z_index = 11
	add_child(ring)
	if one_hit and power >= 5:
		# MS67: Höchststufe – zweiter, großer Ring als Druckwelle
		var ring2 := ImpactRing.new()
		ring2.radius_to = ring.radius_to * 1.8
		ring2.width = ring.width * 1.3
		ring2.z_index = 11
		add_child(ring2)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var amp := 0.12 + 0.04 * power
	_tween.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.0 + amp, 1.0 - amp), 0.05)
	_tween.tween_property(_sprite, "scale", _sprite.scale, 0.12).set_trans(Tween.TRANS_BACK)


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
