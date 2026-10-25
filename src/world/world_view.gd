class_name WorldView
extends Node2D
## Spiegelt die SimWorld in Nodes: Ressourcenknoten, lose Items, Gebäude, Einsammel-Animation.

var _world: SimWorld
var _node_views: Dictionary = {}      # node id → ResourceNodeView
var _loose_views: Dictionary = {}     # loose id → LooseItemView
var _building_views: Dictionary = {}  # building id → BuildingView
var _player: Node2D


func bind(world: SimWorld, player: Node2D) -> void:
	_world = world
	_player = player
	for n: ResourceNode in world.nodes.values():
		_on_node_added(n)
	for item: LooseItem in world.loose.values():
		_on_loose_added(item)
	for b: Building in world.buildings.values():
		_on_building_placed(b)
	world.node_added.connect(_on_node_added)
	world.node_changed.connect(_on_node_changed)
	world.node_removed.connect(_on_node_removed)
	world.loose_added.connect(_on_loose_added)
	world.loose_removed.connect(_on_loose_removed)
	world.item_collected.connect(_on_item_collected)
	world.wreck_hit.connect(_on_wreck_hit)
	world.building_placed.connect(_on_building_placed)
	world.building_changed.connect(_on_building_changed)
	world.building_removed.connect(_on_building_removed)
	world.item_sold.connect(_on_item_sold)
	world.too_hard.connect(_on_too_hard)
	world.node_respawned.connect(_on_node_respawned)


func _on_too_hard(node: ResourceNode, _tool: String) -> void:
	if _node_views.has(node.id):
		_node_views[node.id].sparks()


func _on_node_respawned(node: ResourceNode) -> void:
	# node_added hat die View schon erzeugt; kurzer Pop beim Erscheinen.
	if _node_views.has(node.id):
		var v: Node2D = _node_views[node.id]
		v.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(v, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


func _on_building_placed(b: Building) -> void:
	var view := BuildingView.new()
	view.setup(b)
	add_child(view)
	_building_views[b.id] = view


func _on_building_changed(b: Building) -> void:
	if _building_views.has(b.id):
		_building_views[b.id].refresh(b)


func _on_building_removed(id: int) -> void:
	if _building_views.has(id):
		_building_views[id].queue_free()
		_building_views.erase(id)


func _on_item_sold(_item_id: String, value: int, pos: Vector2i) -> void:
	for view: BuildingView in _building_views.values():
		if view.position == Vector2(pos):
			view.show_sale(value)
			return


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
