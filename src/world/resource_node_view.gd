class_name ResourceNodeView
extends Node2D
## Darstellung eines Ressourcenknotens. Haufen schrumpfen mit der Menge, Wracks wackeln bei Treffern.

const TEXTURES := {
	"scrap_pile": "res://assets/sprites/nodes/scrap_pile.svg",
	"copper_tangle": "res://assets/sprites/nodes/copper_tangle.svg",
	"plastic_crumbs": "res://assets/sprites/nodes/plastic_crumbs.svg",
	"wreck": "res://assets/sprites/nodes/wreck.svg",
}

var node_id: int = -1
var _sprite := Sprite2D.new()
var _kind := ""
var _tween: Tween


func setup(node: ResourceNode) -> void:
	node_id = node.id
	_kind = node.kind
	_sprite.texture = load(TEXTURES[node.kind])
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)
	position = Vector2(node.center_px())
	refresh(node)


func refresh(node: ResourceNode) -> void:
	if node.is_wreck():
		_sprite.scale = Vector2.ONE
		return
	var t := float(node.amount) / float(maxi(node.max_amount, 1))
	_sprite.scale = Vector2.ONE * (0.55 + 0.45 * t)
	_sprite.visible = node.amount > 0 or true  # leere Haufen bleiben als kleiner Rest sichtbar


func wobble() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_sprite, "rotation", 0.18, 0.05)
	_tween.tween_property(_sprite, "rotation", -0.14, 0.08)
	_tween.tween_property(_sprite, "rotation", 0.0, 0.08)
