class_name MeadowView
extends Node2D
## Wiese über dem Sandboden: Wo die Schmutzkarte „grün“ meldet, wächst Kachel für Kachel saftiges Gras
## (weich überblendet in ca. 2,5 s, je Kachel leicht versetzt). Maske 1 Pixel je Kachel, Shader blendet
## ein kachelbares Wiesenmuster ein. Liegt unter dem Schmutz, über dem Sand. Rein kosmetisch.

const SHADER := """
shader_type canvas_item;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 map_size;
varying vec2 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 pat = texture(TEXTURE, UV);
	float m = texture(mask, world_pos / map_size).r;
	float edge = (pat.g - 0.55) * 0.5;
	float a = smoothstep(0.12, 0.42, m + edge);
	COLOR = vec4(pat.rgb, a);
}
"""
const GROW_SECONDS := 2.5
const UPDATE_SECONDS := 1.0 / 20.0

var _world: SimWorld
var _img: Image
var _tex: ImageTexture
var _sprite := Sprite2D.new()
var _level: Dictionary = {}   # Vector2i → aktueller Wert 0..1, solange die Kachel wächst oder welkt
var _delay: Dictionary = {}   # Vector2i → Restverzögerung (s)
var _timer := 0.0


func bind(world: SimWorld) -> void:
	_world = world
	var d := world.dirt
	if not d.is_active():
		visible = false
		return
	_img = Image.create(d.width, d.height, false, Image.FORMAT_R8)
	for y in d.height:
		for x in d.width:
			if d.is_green(Vector2i(x, y)):
				_img.set_pixel(x, y, Color(1, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	var size := Vector2(world.size_px())
	_sprite.texture = load("res://assets/sprites/tiles/meadow.svg")
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, size)
	_sprite.centered = false
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("mask", _tex)
	mat.set_shader_parameter("map_size", size)
	_sprite.material = mat
	add_child(_sprite)
	z_index = -9


## Von DirtView: Kacheln, deren Schmutz oder Wiese sich geändert hat.
func on_tiles_changed(tiles: Array) -> void:
	if _img == null:
		return
	for t: Vector2i in tiles:
		var want := 1.0 if _world.dirt.is_green(t) else 0.0
		var cur: float = _level.get(t, _img.get_pixel(t.x, t.y).r)
		if absf(cur - want) < 0.01:
			continue
		_level[t] = cur
		if want > 0.0 and not _delay.has(t):
			_delay[t] = float(absi(hash(t)) % 600) / 1000.0


func _process(delta: float) -> void:
	if _level.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var step := maxf(-_timer, 0.0) + UPDATE_SECONDS
	_timer = UPDATE_SECONDS
	var done: Array[Vector2i] = []
	for t: Vector2i in _level:
		if _delay.has(t):
			_delay[t] = float(_delay[t]) - step
			if float(_delay[t]) > 0.0:
				continue
			_delay.erase(t)
		var want := 1.0 if _world.dirt.is_green(t) else 0.0
		var cur: float = _level[t]
		cur = move_toward(cur, want, step / GROW_SECONDS if want > cur else step * 4.0)
		_img.set_pixel(t.x, t.y, Color(cur, 0, 0))
		if absf(cur - want) < 0.001:
			done.append(t)
		else:
			_level[t] = cur
	for t in done:
		_level.erase(t)
	_tex.update(_img)


func growing_count() -> int:
	return _level.size()
