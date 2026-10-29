class_name TaskList
extends RefCounted
## Arbeiter-Logik („WorkerBrain“) der Helfer-Roboter (Rustys Autopilot entfiel in MS38).
## Schritte: GOTO, COLLECT, HAMMER, DEPOSIT, WITHDRAW mit Ziel-Kachel.
## Das Gehirn setzt pro Tick nur Eingaben am WorkerBody (move_target, aim, suck_held,
## hammer_pressed) und nutzt die normalen Welt-Regeln; der Node bewegt den Körper.

signal waiting(reason: String)

enum Type { GOTO, COLLECT, HAMMER, DEPOSIT, WITHDRAW }

const MAX_STEPS := 12
const ARRIVE_PX := 20
const STEP_TIMEOUT_TICKS := 200   # 10 s ohne Fortschritt
const WAIT_TICKS := 100           # 5 s Pause nach Problem
const LOOSE_PICKUP_TICKS := 100   # nach dem Hämmern lose Items einsammeln

var steps: Array[Dictionary] = []  # {type: Type, tile: Vector2i, item: String}
var active := false
var index := 0
var loops := 0  # zählt, wie oft die Liste von vorne begann
var wait_ticks := 0
var _progress_ticks := 0
var _last_progress_marker := 0
var _phase := 0                   # schrittinterne Phase (z. B. HAMMER: 0 hämmern, 1 einsammeln)
var _phase_ticks := 0
var _start_total := 0             # Inventarstand beim Schrittbeginn (Fortschrittsmaß)
var _last_wait_reason := ""
var _wait_repeats := 0


# --- Bearbeiten -------------------------------------------------------------

func add_step(type: Type, tile: Vector2i, item: String = "") -> bool:
	if steps.size() >= MAX_STEPS:
		return false
	steps.append({"type": type, "tile": tile, "item": item})
	return true


# --- Steuern ----------------------------------------------------------------

func start(body: WorkerBody) -> bool:
	if steps.is_empty():
		return false
	active = true
	_enter_step(index, body)
	return true


func stop(body: WorkerBody = null) -> void:
	if not active:
		return
	if body != null:
		_release(body)
	active = false


func _release(body: WorkerBody) -> void:
	body.move_target = WorkerBody.NONE_TARGET
	body.suck_held = false


func _enter_step(i: int, body: WorkerBody) -> void:
	index = i
	wait_ticks = 0
	_progress_ticks = 0
	_phase = 0
	_phase_ticks = 0
	_last_progress_marker = body.inventory.total()
	_start_total = body.inventory.total()
	_release(body)


func _next_step(body: WorkerBody) -> void:
	_last_wait_reason = ""
	_wait_repeats = 0
	var next := (index + 1) % steps.size()
	if next == 0:
		loops += 1
	_enter_step(next, body)


func _fail(body: WorkerBody, reason: String) -> void:
	_release(body)
	wait_ticks = WAIT_TICKS
	# Spruch nur beim ersten Mal und dann alle 6 Wiederholungen (30 s), nicht alle 5 s.
	if reason != _last_wait_reason or _wait_repeats % 6 == 0:
		waiting.emit(reason)
	_last_wait_reason = reason
	_wait_repeats += 1


# --- Tick -------------------------------------------------------------------

func tick(world: SimWorld, body: WorkerBody) -> void:
	if not active or steps.is_empty():
		return
	if wait_ticks > 0:
		wait_ticks -= 1
		if wait_ticks == 0:
			_enter_step(index, body)  # erneut versuchen
		return
	var step := steps[index]
	var center := _tile_center(step["tile"])
	match int(step["type"]):
		Type.GOTO:
			if _go_to(body, center, ARRIVE_PX):
				_next_step(body)
		Type.COLLECT:
			_tick_collect(world, body, step, center)
		Type.HAMMER:
			_tick_hammer(world, body, step, center)
		Type.DEPOSIT:
			_tick_transfer(world, body, step, true)
		Type.WITHDRAW:
			_tick_transfer(world, body, step, false)


static func _tile_center(tile: Vector2i) -> Vector2i:
	return tile * WorkerBody.TILE + Vector2i(WorkerBody.TILE / 2, WorkerBody.TILE / 2)


## Setzt das Bewegungsziel; true, wenn nah genug.
func _go_to(body: WorkerBody, target: Vector2i, within_px: int) -> bool:
	var d := Vector2(target - body.pos)
	if d.length() <= within_px:
		body.move_target = WorkerBody.NONE_TARGET
		return true
	body.move_target = target
	_progress_ticks += 1
	if _progress_ticks > STEP_TIMEOUT_TICKS:
		_fail(body, "stuck")
	return false


func _node_at(world: SimWorld, tile: Vector2i) -> ResourceNode:
	var id: int = world._node_tiles.get(tile, -1)   # direkt über die Kachel (MS64)
	return world.nodes.get(id, null) if id >= 0 else null


func _tick_collect(world: SimWorld, body: WorkerBody, step: Dictionary, center: Vector2i) -> void:
	var node := _node_at(world, step["tile"])
	if node == null or node.uses_hammer():
		# Vielleicht liegen lose Items dort (z. B. nach dem Hämmern): kurz saugen, sonst weiter.
		if _suck_loose_near(world, body, center):
			return
		_next_step(body)
		return
	if body.inventory.is_full():
		_next_step(body)
		return
	if not _go_to(body, center, body.suck_range_px - 40):
		return
	body.aim = Vector2(center - body.pos).normalized() if center != body.pos else Vector2.RIGHT
	body.suck_held = true
	if node.is_depleted():
		# Quelle leer: mit dem Gesammelten weiter; ohne Ausbeute kurz warten und neu versuchen.
		if body.inventory.total() > _start_total:
			_next_step(body)
		else:
			_fail(body, "empty")
		return
	if node.tier > body.suction_tier:
		_fail(body, "too_hard")
		return
	# Fortschritt = Inventar wächst
	if body.inventory.total() != _last_progress_marker:
		_last_progress_marker = body.inventory.total()
		_phase_ticks = 0
	else:
		_phase_ticks += 1
		if _phase_ticks > STEP_TIMEOUT_TICKS:
			_fail(body, "no_progress")


## Saugt lose Items in Reichweite des Zielpunkts ein; true solange welche da sind (max. 5 s).
func _suck_loose_near(world: SimWorld, body: WorkerBody, center: Vector2i) -> bool:
	var nearest: LooseItem = null
	var best := INF
	for item: LooseItem in world.loose.values():
		var d := Vector2(item.pos - center).length()
		if d < 160.0 and d < best:
			best = d
			nearest = item
	if nearest == null or body.inventory.is_full():
		return false
	_phase_ticks += 1
	if _phase_ticks > LOOSE_PICKUP_TICKS + STEP_TIMEOUT_TICKS:
		return false
	if not _go_to(body, nearest.pos, body.suck_range_px - 40):
		return true
	body.aim = Vector2(nearest.pos - body.pos).normalized() if nearest.pos != body.pos else Vector2.RIGHT
	body.suck_held = true
	return true


func _tick_hammer(world: SimWorld, body: WorkerBody, step: Dictionary, center: Vector2i) -> void:
	var node := _node_at(world, step["tile"])
	if node == null or not node.uses_hammer():
		if _suck_loose_near(world, body, center):
			return
		_next_step(body)
		return
	if node.tier > body.hammer_tier and not node.boss:
		_fail(body, "too_hard")
		return
	# Nah heran (Schlagpunkt 48 px vor dem Körper, Reichweite hammer_range)
	if not _go_to(body, center, body.hammer_range_px + 40 - 8):
		return
	body.aim = Vector2(center - body.pos).normalized() if center != body.pos else Vector2.RIGHT
	body.hammer_pressed = true
	_phase_ticks += 1
	if _phase_ticks > STEP_TIMEOUT_TICKS * 3:
		_fail(body, "no_progress")


func _tick_transfer(world: SimWorld, body: WorkerBody, step: Dictionary, deposit: bool) -> void:
	var b := world.grid.at(step["tile"])
	if b == null:
		_fail(body, "no_building")
		return
	var r := b.rect_px()
	var target := Vector2i(r.position + r.size / 2)
	# Zum nächsten Rand des Gebäudes laufen
	var approach := Vector2i(clampi(body.pos.x, r.position.x - 40, r.end.x + 40), clampi(body.pos.y, r.position.y - 40, r.end.y + 40))
	var d := Vector2(target - body.pos)
	var reach := r.grow(44).has_point(body.pos)
	if not reach:
		if not _go_to(body, target, 0) and not r.grow(44).has_point(body.pos):
			return
	var filter := str(step.get("item", ""))
	var moved := false
	if deposit:
		for i in body.inventory.slots.size():
			var s: Dictionary = body.inventory.slots[i]
			if s["item"] == "" or (filter != "" and s["item"] != filter):
				continue
			var accepted := b.accept_stack(s["item"], int(s["count"]))
			if accepted > 0:
				body.inventory.remove(s["item"], accepted)
				world.building_changed.emit(b)
				moved = true
				if body is Helper and body.inventory.total() == 0:
					world.helper_quip.emit(body as Helper, "HELPER_LOVE")  # Herz beim Abliefern (MS44)
				break  # ein Stapel je Tick
	else:
		if not body.inventory.is_full():
			var stack := b.withdraw_stack()
			if not stack.is_empty():
				if filter != "" and stack["item"] != filter:
					b.accept_stack(stack["item"], stack["count"])
				else:
					var rest := body.inventory.add(stack["item"], stack["count"])
					if rest > 0:
						b.accept_stack(stack["item"], rest)
					world.building_changed.emit(b)
					moved = true
	if moved:
		_phase_ticks = 0
		return
	# Nichts mehr zu übertragen: fertig (oder blockiert, wenn noch etwas da wäre)
	if deposit and _has_depositable(body, filter) and _phase_ticks < 2:
		_phase_ticks += 1
		return
	if deposit and _has_depositable(body, filter):
		_fail(body, "full")
		return
	_next_step(body)


func _has_depositable(body: WorkerBody, filter: String) -> bool:
	for s: Dictionary in body.inventory.slots:
		if s["item"] != "" and (filter == "" or s["item"] == filter):
			return true
	return false

