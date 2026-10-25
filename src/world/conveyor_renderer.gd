class_name ConveyorRenderer
extends Node2D
## Zeichnet alle Items auf allen Bändern per MultiMesh (eine Instanz je Itemtyp).
## Position = Bandpfad (gerade oder Viertelkreis) an der Stelle offset/256, mit Tick-Interpolation.

const ICON_PX := 28.0

var _world: SimWorld
var _meshes: Dictionary = {}  # item_id → MultiMeshInstance2D
var _buffers: Dictionary = {}  # item_id → PackedVector2Array (wiederverwendet)

## Zuletzt gezeichnete Item-Anzahl (für das Debug-Overlay).
var item_count: int = 0


func bind(world: SimWorld) -> void:
	_world = world
	z_index = 2


func _process(_delta: float) -> void:
	if _world == null:
		return
	for key in _buffers:
		_buffers[key].clear()
	var alpha_shift := SimClock.alpha * Conveyor.SPEED
	var count := 0
	for b: Building in _world.buildings.values():
		if not (b is Conveyor):
			continue
		var c := b as Conveyor
		var limit := float(Conveyor.LEN - 1)
		for it in c.items:
			var off := minf(float(it["offset"]) + alpha_shift, limit)
			limit = off - Conveyor.SPACING
			var item: String = it["item"]
			if not _buffers.has(item):
				_buffers[item] = PackedVector2Array()
			_buffers[item].append(_item_pos(c, off))
			count += 1
	item_count = count
	for item in _buffers:
		var pts: PackedVector2Array = _buffers[item]
		var mmi := _mesh_for(item)
		var mm := mmi.multimesh
		if mm.instance_count < pts.size():
			mm.instance_count = maxi(pts.size(), maxi(mm.instance_count * 2, 64))
		mm.visible_instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform_2d(i, Transform2D(0.0, pts[i]))


func _mesh_for(item: String) -> MultiMeshInstance2D:
	if _meshes.has(item):
		return _meshes[item]
	var mmi := MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	var quad := QuadMesh.new()
	quad.size = Vector2(ICON_PX, ICON_PX)
	mm.mesh = quad
	mm.instance_count = 64
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	mmi.texture = DataRegistry.item_icon(item)
	add_child(mmi)
	_meshes[item] = mmi
	return mmi


## Weltposition eines Items auf dem Band bei offset (0..255).
static func _item_pos(c: Conveyor, off: float) -> Vector2:
	var t := off / float(Conveyor.LEN)
	var center := Vector2(c.center_px())
	var d := Vector2(c.dir())
	if c.shape == Conveyor.Shape.STRAIGHT:
		return center - d * 32.0 + d * 64.0 * t
	var s := Vector2(c.left_dir()) if c.shape == Conveyor.Shape.TURN_FROM_LEFT else Vector2(c.right_dir())
	var corner := center + s * 32.0 + d * 32.0
	var theta := t * PI / 2.0
	return corner + (-d * 32.0) * cos(theta) + (-s * 32.0) * sin(theta)
