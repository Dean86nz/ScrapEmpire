extends Node2D
## Werkzeug (seit MS74 statt Hammer): LT/RMB löst einen Schlag aus (die Sim prüft Reichweite und
## Cooldown). Zeigt das Werkzeug der aktuellen Stufe (Pömpel … Laser) mit eigener Animation;
## sonst trägt Rusty es seitlich (RustyLook).

const REST := Vector2(52, 0)
const SIZE := 0.3

var _tool := Sprite2D.new()
var _tween: Tween
var _tier := 0
var _hide_at := 0.0


func _ready() -> void:
	# Werkzeug vor Rusty, nur beim Benutzen sichtbar; sonst trägt Rusty es seitlich (MS75)
	_tool.visible = false
	_tool.z_index = 1
	add_child(_tool)


func _physics_process(_delta: float) -> void:
	if InputRouter.context == InputRouter.Context.GAME and Input.is_action_just_pressed("tool_secondary"):
		SimClock.world.player.hammer_pressed = true
		_swing()


func _process(_delta: float) -> void:
	var tier := SimClock.world.player.hammer_tier if SimClock.world != null else 1
	if tier != _tier:
		_tier = tier
		_tool.texture = ToolLook.texture(tier)
	# Aufrechte Werkzeuge (Kran, Presse, Laser) nicht kopfüber zeigen, wenn Rusty nach links zielt
	var left := absf(wrapf(global_rotation, -PI, PI)) > PI * 0.5
	_tool.flip_v = left and _tier >= 3
	if _tool.visible and Time.get_ticks_msec() * 0.001 > _hide_at:
		_tool.visible = false
	# MS75: Rusty trägt das Werkzeug sonst seitlich; während der Benutzung nur vorne zeigen
	var look := get_node_or_null("../../Sprite2D/RustyLook") as RustyLook
	if look != null:
		look.tool_in_use = _tool.visible
		look.set_tool(_tier)


func _swing() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tool.visible = true
	_hide_at = Time.get_ticks_msec() * 0.001 + 0.6
	_tween = ToolLook.animate_use(_tool, _tier, REST, Vector2(SIZE, SIZE))
