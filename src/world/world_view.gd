class_name WorldView
extends Node2D
## Spiegelt die SimWorld in Nodes: Ressourcenknoten, lose Items, Einsammel-Animation.

var _world: SimWorld
var _node_views: Dictionary = {}   # node id → ResourceNodeView
var _loose_views: Dictionary = {}  # loose id → LooseItemView
var _player: Node2D


func bind(world: SimWorld, player: Node2D) -> void:
	_world = world
	_player = player
	for n: ResourceNode in world.nodes.values():
		_on_node_added(n)
	for item: LooseItem in world.loose.values():
		_on_loose_added(item)
	world.node_added.connect(_on_node_added)
	world.node_changed.connect(_on_node_changed)
	world.node_removed.connect(_on_node_removed)
	world.loose_added.connect(_on_loose_added)
	world.loose_removed.connect(_on_loose_removed)
	world.item_collected.connect(_on_item_collected)
	world.wreck_hit.connect(_on_wreck_hit)


func _on_node_added(node: ResourceNode) -> void:
	var view := ResourceNodeView.new()
	view.setup(node)
	add_child(view)
	_node_views[node.id] = view


func _on_node_changed(node: ResourceNode) -> void:
	if _node_views.has(node.id):
		_node_views[node.id].refresh(node)


func _on_node_removed(id: int) -> void:
	if _node_views.has(id):
		_node_views[id].queue_free()
		_node_views.erase(id)


func _on_wreck_hit(node: ResourceNode) -> void:
	if _node_views.has(node.id):
		_node_views[node.id].wobble()


func _on_loose_added(item: LooseItem) -> void:
	var view := LooseItemView.new()
	view.setup(item)
	add_child(view)
	_loose_views[item.id] = view


func _on_loose_removed(id: int) -> void:
	if _loose_views.has(id):
		_loose_views[id].queue_free()
		_loose_views.erase(id)


## Icon fliegt vom Fundort zu Rusty und verschwindet.
func _on_item_collected(item_id: String, from_pos: Vector2i) -> void:
	var fly := Sprite2D.new()
	fly.texture = DataRegistry.item_icon(item_id)
	fly.position = Vector2(from_pos)
	fly.z_index = 20
	add_child(fly)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly, "global_position", _player.global_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fly, "scale", Vector2.ONE * 0.4, 0.2)
	tween.chain().tween_callback(fly.queue_free)
