class_name ToolSystem
extends RefCounted
## Saugen, Hämmern, Magnet für Rusty und Helfer.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


## Saugen/Hämmern für einen Helfer (gleiche Regeln wie Rusty, aber ohne Kegel: Reichweite reicht).
static func helper_work(w: SimWorld, h: Helper) -> void:
	if h.suck_held:
		clean_around(w, h.pos, h.suck_range_px, int(w.dirt_cfg.get("helper_clean_rate_per_tick", 10)))
		if h.suck_cooldown > 0:
			h.suck_cooldown -= 1
		else:
			var target: Variant = _find_suck_target_for(w, h)
			if target != null and h.inventory.can_add(target.item_id if target is LooseItem else _peek_suck_item(w, target)):
				var item_id: String
				if target is LooseItem:
					item_id = target.item_id
					w.loose.erase(target.id)
					w.loose_removed.emit(target.id)
				else:
					var node := target as ResourceNode
					item_id = node.take_one()
					NodeSystem.after_take(w, node)
				h.inventory.add(item_id, 1)
				h.suck_cooldown = maxi(1, int(PlayerState.BASE_SUCK_INTERVAL / h.work_mult))
				w.progression.on_collect(1)
	if h.hammer_pressed:
		h.hammer_pressed = false
		if h.hammer_cooldown > 0:
			pass
		else:
			var hit_point := Vector2(h.pos) + h.aim * PlayerState.HAMMER_REACH_PX
			for n: ResourceNode in w.nodes.values():
				if not n.uses_hammer() or (n.tier > h.hammer_tier and not n.boss):
					continue
				if hit_point.distance_to(Vector2(n.center_px())) <= float(h.hammer_range_px):
					h.hammer_cooldown = PlayerState.BASE_HAMMER_INTERVAL
					if n.boss and not BossSystem.can_damage(w, n):
						w.boss_swing.emit(n)
						break
					for k in ceili(ResourceNode.items_per_hit(n, h.hammer_tier) * h.work_mult):
						var item_id := n.take_one()
						if item_id == "":
							break
						w.add_loose(item_id, n.center_px() + w._scatter(), n.tier)
					w.wreck_hit.emit(n)
					NodeSystem.after_take(w, n)
					break
	if h.hammer_cooldown > 0:
		h.hammer_cooldown -= 1


static func _find_suck_target_for(w: SimWorld, h: Helper) -> Variant:
	var best: Variant = null
	var best_d := INF
	for item: LooseItem in w.loose.values():
		var d := Vector2(item.pos - h.pos).length()
		if d <= h.suck_range_px and d < best_d:
			best_d = d
			best = item
	if best != null:
		return best
	for n: ResourceNode in w.nodes.values():
		if n.uses_hammer() or n.is_depleted() or n.tier > h.suction_tier:
			continue
		var d := Vector2(n.center_px() - h.pos).length()
		if d <= h.suck_range_px and d < best_d:
			best_d = d
			best = n
	return best


## Magnet-Skill: lose Items im Radius werden ohne Zielen eingesammelt (1 je Tick).
static func _tick_magnet(w: SimWorld) -> void:
	if w.player.magnet_radius_px <= 0:
		return
	var r2 := w.player.magnet_radius_px * w.player.magnet_radius_px
	for item: LooseItem in w.loose.values():
		if Vector2(item.pos - w.player.pos).length_squared() > r2:
			continue
		if not w.player.inventory.can_add(item.item_id):
			return
		w.loose.erase(item.id)
		w.loose_removed.emit(item.id)
		w.player.inventory.add(item.item_id, 1)
		w.progression.on_collect(item.tier)
		w.item_collected.emit(item.item_id, item.pos)
		return


## Je Zug bis zu `suck_targets` Teile (Skill Saugtempo): vom dünnen Strahl bis zum Wirbel.
static func _tick_suction(w: SimWorld) -> void:
	if not w.player.suck_held or w.player.suck_cooldown > 0:
		return
	for i in w.player.suck_targets:
		if not _suck_one(w, i == 0):
			break
	w.player.suck_cooldown = w.player.suck_interval


## Saugt ein Teil ein. false, wenn nichts (mehr) da ist oder die Taschen voll sind.
static func _suck_one(w: SimWorld, first: bool) -> bool:
	var target: Variant = _find_suck_target(w)
	if target == null:
		if first:
			var hard := _find_too_hard_suck_target(w)
			if hard != null:
				w._emit_too_hard(hard, "suction")
		return false
	var item_id: String = target.item_id if target is LooseItem else _peek_suck_item(w, target as ResourceNode)
	if not w.player.inventory.can_add(item_id):
		if not w._full_notified:
			w._full_notified = true
			w.inventory_full.emit()
		return false
	var from_pos: Vector2i
	var tier := 1
	if target is LooseItem:
		from_pos = target.pos
		tier = target.tier
		w.loose.erase(target.id)
		w.loose_removed.emit(target.id)
	else:
		var node := target as ResourceNode
		from_pos = node.center_px()
		tier = node.tier
		node.take_one()
		NodeSystem.after_take(w, node)
	w.player.inventory.add(item_id, 1)
	w.progression.on_collect(tier)
	w.item_collected.emit(item_id, from_pos)
	return true


## Sauger putzt den Boden im Saugkegel (auch ohne Ziel). Unter liegendem Müll geht das nicht.
static func _tick_clean(w: SimWorld) -> void:
	if not w.player.suck_held or not w.dirt.is_active():
		return
	var rate := int(w.dirt_cfg.get("clean_rate_per_tick", 22))
	var r := int(ceil(w.player.suck_range_px / float(SimWorld.TILE)))
	var center := w.player_tile()
	var cleaned := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := center + Vector2i(dx, dy)
			if w.dirt.value(t) == 0 or w._node_tiles.has(t):
				continue
			var c := t * SimWorld.TILE + Vector2i(SimWorld.TILE / 2, SimWorld.TILE / 2)
			if dx == 0 and dy == 0 or _cone_distance(w, c) < INF:
				if w.dirt.clean(t, rate):
					cleaned += 1
	if cleaned > 0:
		_reward_cleaning(w, cleaned)


## Putzen im Umkreis (Bots). Kein Kleinschrott, damit Bots die Taschen von Rusty nicht füllen.
static func clean_around(w: SimWorld, pos: Vector2i, radius_px: int, rate: int) -> int:
	if not w.dirt.is_active():
		return 0
	var r := int(ceil(radius_px / float(SimWorld.TILE)))
	var center := Vector2i(pos.x / SimWorld.TILE, pos.y / SimWorld.TILE)
	var cleaned := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := center + Vector2i(dx, dy)
			if w.dirt.value(t) == 0 or w._node_tiles.has(t):
				continue
			if Vector2(dx, dy).length() * SimWorld.TILE <= radius_px and w.dirt.clean(t, rate):
				cleaned += 1
	return cleaned


## Alle paar geputzten Kacheln fällt ein Stück Kleinschrott in Rustys Taschen.
static func _reward_cleaning(w: SimWorld, n: int) -> void:
	w._dirt_reward += n
	var every := int(w.dirt_cfg.get("scrap_every_tiles", 5))
	while every > 0 and w._dirt_reward >= every:
		w._dirt_reward -= every
		if w.player.inventory.can_add("scrap"):
			w.player.inventory.add("scrap", 1)
			w.progression.on_collect(1)
			w.item_collected.emit("scrap", w.player.pos + Vector2i(w.player.aim * 80.0))


## Welches Item ein Saug-Objekt als Naechstes liefert (ohne es zu entnehmen).
static func _peek_suck_item(w: SimWorld, node: ResourceNode) -> String:
	if node.is_pile():
		return node.item_id()
	var keys := node.loot.keys()
	keys.sort()
	var best := ""
	var best_n := 0
	for k: String in keys:
		if int(node.loot[k]) > best_n:
			best = k
			best_n = int(node.loot[k])
	return best


## Saug-Objekt im Kegel, dessen Stufe zu hoch ist (fuer Feedback).
static func _find_too_hard_suck_target(w: SimWorld) -> ResourceNode:
	for n: ResourceNode in w.nodes.values():
		if n.uses_hammer() or n.is_depleted() or n.tier <= w.player.suction_tier:
			continue
		if _cone_distance(w, n.center_px()) < INF:
			return n
	return null


## Lose Items haben Vorrang vor Haufen; innerhalb einer Gruppe das nächstgelegene.
static func _find_suck_target(w: SimWorld) -> Variant:
	var best: Variant = null
	var best_d := INF
	for item: LooseItem in w.loose.values():
		var d := _cone_distance(w, item.pos)
		if d < best_d:
			best_d = d
			best = item
	if best != null:
		return best
	for n: ResourceNode in w.nodes.values():
		if n.uses_hammer() or n.is_depleted() or n.tier > w.player.suction_tier:
			continue
		var d := _cone_distance(w, n.center_px())
		if d < best_d:
			best_d = d
			best = n
	return best


## Abstand zum Ziel, wenn es im Saugkegel liegt, sonst INF.
static func _cone_distance(w: SimWorld, target: Vector2i) -> float:
	var d := Vector2(target - w.player.pos)
	var dist := d.length()
	if dist > w.player.suck_range_px:
		return INF
	if dist < 1.0:
		return 0.0
	if w.player.suck_half_angle < PI and d.normalized().dot(w.player.aim) < cos(w.player.suck_half_angle):
		return INF
	return dist


static func _tick_hammer(w: SimWorld) -> void:
	if not w.player.hammer_pressed or w.player.hammer_cooldown > 0:
		return
	var wreck := _find_wreck_target(w)
	if wreck == null:
		return
	w.player.hammer_cooldown = w.player.hammer_interval
	if wreck.boss:
		# Verstärkung rufen; Schaden nur gemeinsam
		BossSystem.rally(w, wreck)
		if not BossSystem.can_damage(w, wreck):
			w.boss_blocked.emit(wreck, BossSystem.helpers_at(w, wreck), wreck.bots_needed)
			return
	elif wreck.tier > w.player.hammer_tier:
		w._emit_too_hard(wreck, "hammer")
		return
	var per_hit := ceili(ResourceNode.items_per_hit(wreck, w.player.hammer_tier) * (1.0 + w.player.hammer_power))
	var one_hit := per_hit >= wreck.amount
	w.hammer_impact.emit(wreck, w.player.hammer_tier, one_hit)
	for i in per_hit:
		var item_id := wreck.take_one()
		if item_id == "":
			break
		w.add_loose(item_id, wreck.center_px() + w._scatter(), wreck.tier)
	w.wreck_hit.emit(wreck)
	NodeSystem.after_take(w, wreck)


static func _find_wreck_target(w: SimWorld) -> ResourceNode:
	var hit_point := Vector2(w.player.pos) + w.player.aim * PlayerState.HAMMER_REACH_PX
	var best: ResourceNode = null
	var best_d := float(w.player.hammer_range_px)
	for n: ResourceNode in w.nodes.values():
		if not n.uses_hammer():
			continue
		var d := hit_point.distance_to(Vector2(n.center_px()))
		if d <= best_d:
			best_d = d
			best = n
	return best
