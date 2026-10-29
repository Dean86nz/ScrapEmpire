class_name NodeSystem
extends RefCounted
## Schrott-Objekte, lose Items, Respawn, Streuung, Zu-hart-Hinweis.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


## Beliebiges Schrott-Objekt aus scrap_objects.json. amount_override nur für Haufen.
static func add_object(w: SimWorld, kind: String, tile: Vector2i, amount_override: int = -1) -> ResourceNode:
	var n := ResourceNode.from_kind(w.next_id(), kind, tile, amount_override)
	w.nodes[n.id] = n
	w._node_tiles[tile] = n.id
	w.nav_changes.append(tile)
	w._zone_nodes_dirty = true
	w.node_added.emit(n)
	return n


static func add_pile(w: SimWorld, kind: String, tile: Vector2i, amount: int) -> ResourceNode:
	return add_object(w, kind, tile, amount)


## Endliches Hammer-Objekt mit expliziter Ausbeute (Tests, alte Karten).
static func add_wreck(w: SimWorld, tile: Vector2i, loot: Dictionary, kind: String = ResourceNode.KIND_WRECK) -> ResourceNode:
	var n := ResourceNode.make_wreck(w.next_id(), tile, loot, kind)
	w.nodes[n.id] = n
	w._node_tiles[tile] = n.id
	w.nav_changes.append(tile)
	w._zone_nodes_dirty = true
	w.node_added.emit(n)
	return n


static func add_loose(w: SimWorld, item_id: String, pos: Vector2i, tier: int = 1, count: int = 1) -> LooseItem:
	var item := LooseItem.new(w.next_id(), item_id, pos, tier, count)
	w.loose[item.id] = item
	w.loose_added.emit(item)
	return item


## Aus einem Bündel so viel nehmen, wie ins Inventar passt (MS64). Liefert die genommene Menge;
## leeres Bündel verschwindet, sonst wird es kleiner.
static func take_loose(w: SimWorld, item: LooseItem, inv: Inventory) -> int:
	var left := inv.add(item.item_id, item.count)
	var taken := item.count - left
	if taken <= 0:
		return 0
	item.count = left
	if item.count <= 0:
		w.loose.erase(item.id)
		w.loose_removed.emit(item.id)
	else:
		w.loose_changed.emit(item)
	return taken


## Hammer-Ausbeute als Bündel: je Item-Sorte ein Haufen mit Anzahl statt vieler Einzelteile.
static func drop_bundles(w: SimWorld, n: ResourceNode, amount: int) -> int:
	var counts := {}
	var got := 0
	for k in amount:
		var item_id := n.take_one()
		if item_id == "":
			break
		counts[item_id] = int(counts.get(item_id, 0)) + 1
		got += 1
	for item_id: String in counts:
		add_loose(w, item_id, n.center_px() + w._scatter(), n.tier, int(counts[item_id]))
	return got


static func _tick_respawns(w: SimWorld) -> void:
	var i := w.respawns.size() - 1
	while i >= 0:
		var r := w.respawns[i]
		r["ticks_left"] = int(r["ticks_left"]) - 1
		if int(r["ticks_left"]) <= 0:
			w.respawns.remove_at(i)
			var kind := str(r["kind"])
			var is_res: bool = ResourceNode.has_kind(kind) and (bool(ResourceNode.defs[kind].get("resource", false)) or str(ResourceNode.defs[kind].get("type", "pile")) == "pile")
			if not is_res and not w.zones.allows_trash_respawn(r["tile"], w.nodes):
				i -= 1
				continue  # Zone inzwischen sauber genug: kein Müll mehr
			if not w._node_tiles.has(r["tile"]) and w.grid.at(r["tile"]) == null:
				var n := add_object(w, kind, r["tile"])
				if w.dirt.is_active() and not is_res:
					w.dirt.soil(r["tile"], int(w.dirt_cfg.get("trash_dirt", 255)))
				w.node_respawned.emit(n)
				w.zones.refresh(w.nodes)
			else:
				r["ticks_left"] = 100  # Kachel belegt: spaeter noch einmal versuchen
				w.respawns.append(r)
		i -= 1


## Nach dem Entnehmen: leeres Objekt entfernen (Wracks melden „zerlegt“), sonst als geändert melden.
static func after_take(w: SimWorld, n: ResourceNode) -> void:
	if n.is_used_up():
		_remove_node(w, n)
		if n.is_wreck():
			w.wreck_destroyed.emit(n.id)
	else:
		w.node_changed.emit(n)


static func _remove_node(w: SimWorld, n: ResourceNode) -> void:
	SecretSystem.on_node_removed(w, n)
	w.nodes.erase(n.id)
	w._node_tiles.erase(n.tile)
	w.nav_changes.append(n.tile)
	w._zone_nodes_dirty = true
	w.node_removed.emit(n.id)
	if w.dirt.is_active() and not n.is_resource() and not n.bonus:
		var r := int(w.dirt_cfg.get("removed_trash_clean_radius", 1))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				w.dirt.clean(n.tile + Vector2i(dx, dy), 255)
	# Rohstoffquellen respawnen immer; Müll nur, solange die Zone unter 50 % sauber ist.
	if n.respawn_ticks > 0 and (n.is_resource() or w.zones.allows_trash_respawn(n.tile, w.nodes)):
		w.respawns.append({"kind": n.kind, "tile": n.tile, "ticks_left": n.respawn_ticks})
	if n.boss:
		BossSystem.release(w, n.id)
		var zid := w.zones.zone_id_at(n.tile)
		var reward := int(ResourceNode.defs.get(n.kind, {}).get("reward_bolts", 0))
		w.flags["boss_" + zid] = true
		if n.final:
			w.flags["final_boss"] = true
		if reward > 0:
			w.bolts += reward
			w.bolts_changed.emit(w.bolts)
		w.boss_defeated.emit(n.kind, zid, reward)
	w.zones.refresh(w.nodes)


static func _emit_too_hard(w: SimWorld, n: ResourceNode, tool: String) -> void:
	if w._too_hard_cooldown > 0:
		return
	w._too_hard_cooldown = SimWorld.TOO_HARD_INTERVAL
	w.too_hard.emit(n, tool)


static func _scatter(w: SimWorld) -> Vector2i:
	return Vector2i(
		w.rng.randi_range(-SimWorld.LOOT_SCATTER_PX, SimWorld.LOOT_SCATTER_PX),
		w.rng.randi_range(-SimWorld.LOOT_SCATTER_PX, SimWorld.LOOT_SCATTER_PX))
