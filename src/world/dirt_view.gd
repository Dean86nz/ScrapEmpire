class_name DirtView
extends Node2D
## Schmutzschicht über dem Boden: eine Maske (1 Pixel je Kachel, weich gefiltert) blendet ein
## kachelbares Schmutzmuster ein. Wird beim Putzen höchstens 15× pro Sekunde aktualisiert.
## Liefert außerdem eine kleine Farb-Textur für Minimap und Karte.

signal tiles_changed(tiles: Array)

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
	float edge = (pat.r - 0.45) * 0.35;
	float a = smoothstep(0.04, 0.30, m + edge);
	COLOR = vec4(pat.rgb, a * 0.93);
}
"""
const UPDATE_SECONDS := 1.0 / 15.0
const MAP_COLOR := Color(0.36, 0.29, 0.21)
const MAP_GREEN := Color(0.42, 0.74, 0.32)

var map_texture: ImageTexture
var _world: SimWorld
var _mask_img: Image
var _mask_tex: ImageTexture
var _map_img: Image
var _sprite := Sprite2D.new()
var _timer := 0.0


func bind(world: SimWorld) -> void:
	_world = world
	var d := world.dirt
	if not d.is_active():
		visible = false
		return
	_mask_img = Image.create(d.width, d.height, false, Image.FORMAT_R8)
	_map_img = Image.create(d.width, d.height, false, Image.FORMAT_RGBA8)
	for y in d.height:
		for x in d.width:
			_set_pixel(Vector2i(x, y), d.value(Vector2i(x, y)))
	_mask_tex = ImageTexture.create_from_image(_mask_img)
	map_texture = ImageTexture.create_from_image(_map_img)
	var size := Vector2(world.size_px())
	_sprite.texture = load("res://assets/sprites/tiles/dirt.svg")
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, size)
	_sprite.centered = false
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("mask", _mask_tex)
	mat.set_shader_parameter("map_size", size)
	_sprite.material = mat
	add_child(_sprite)
	z_index = -9
	d.take_changed()


func _set_pixel(t: Vector2i, v: int) -> void:
	var f := float(v) / 255.0
	_mask_img.set_pixel(t.x, t.y, Color(f, 0, 0))
	if v == 0 and _world.dirt.is_green(t):
		_map_img.set_pixel(t.x, t.y, Color(MAP_GREEN, 0.85))
	else:
		_map_img.set_pixel(t.x, t.y, Color(MAP_COLOR, minf(f * 1.6, 0.9)))


func _process(delta: float) -> void:
	if _world == null or not visible:
		return
	_timer -= delta
	if _timer > 0.0 or _world.dirt.changed.is_empty():
		return
	_timer = UPDATE_SECONDS
	var tiles := _world.dirt.take_changed()
	for t in tiles:
		_set_pixel(t, _world.dirt.value(t))
	_mask_tex.update(_mask_img)
	map_texture.update(_map_img)
	tiles_changed.emit(tiles)
