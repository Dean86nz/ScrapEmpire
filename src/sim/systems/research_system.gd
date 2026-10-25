class_name ResearchSystem
extends RefCounted
## Forschung, Skills, Modifikatoren, Freischaltungen, Rezepte, Verkaufswert.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


static func is_building_unlocked(w: SimWorld, def_id: String) -> bool:
	if not w.gate_buildings:
		return true
	var def: BuildingDef = w.defs.get(def_id)
	if def != null and def.requires_feature != "":
		return w.unlocked_features.has(def.requires_feature)
	return w.unlocked_buildings.has(def_id)


static func recompute_modifiers(w: SimWorld) -> void:
	var upgrade_defs: Array = []
	upgrade_defs.append_array(w.helper_cfg.get("upgrades", []))
	upgrade_defs.append_array(w.drone_cfg.get("upgrades", []))
	var upgrade_levels := w.helper_upgrades.duplicate()
	upgrade_levels.merge(w.drone_upgrades)
	w.mods = Modifiers.compute(w.skills.defs, w.skills.levels, w.tech.defs, w.tech.unlocked, upgrade_defs, upgrade_levels)
	if w.player.apply_modifiers(w.mods):
		w.inventory_resized.emit()
	for h: Helper in w.helpers.values():
		w._apply_helper_mods(h)
	for d: Drone in w.drones.values():
		w._apply_drone_mods(d)
	for b: Building in w.buildings.values():
		if b is SellTerminal:
			(b as SellTerminal).sell_interval = int(w.mods["sell_interval"])
	w.modifiers_changed.emit(w.mods)


static func _apply_tech_effects(w: SimWorld, id: String) -> void:
	w.unlocked_tech[id] = true
	for eff: Dictionary in w.tech.effects_of(id):
		match str(eff.get("type", "")):
			"unlock_building":
				w.unlocked_buildings[str(eff["id"])] = true
			"unlock_recipe":
				pass  # über unlocked_tech + refresh_recipes
			"unlock_feature":
				w.unlocked_features[str(eff["id"])] = true
	refresh_recipes(w)


static func _cmd_research(w: SimWorld, cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := w.tech.can_start(id, w.bolts, w.player.inventory, ShipSystem.extra_inventories(w))
	if reason != "":
		w.research_failed.emit(reason)
		return
	var d: Dictionary = w.tech.by_id[id]
	w.bolts -= int(d.get("cost_bolts", 0))
	ShipSystem.pay(w, d.get("cost_items", {}))
	w.bolts_changed.emit(w.bolts)
	w.progression.on_tech(int(d.get("cost_bolts", 0)))
	w.tech.start(id)
	if w.tech.current_id == "":  # Zeit 0: sofort fertig
		pass


static func _cmd_buy_skill(w: SimWorld, cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := w.skills.can_buy(id, w.progression.skill_points)
	if reason != "":
		w.skill_failed.emit(reason)
		return
	w.progression.skill_points -= 1
	w.skills.buy(id)
	recompute_modifiers(w)
	w.skill_bought.emit(id, w.skills.level_of(id))


## Verkaufswert mit Boni: Feilschen, Kenner (seltene Items), Großhändler (Puffer ≥ 20).
static func sale_value(w: SimWorld, item_id: String, buffer_size_at_sale: int) -> int:
	var v := float(w.item_values.get(item_id, 0)) * float(w.mods["sell_mult"])
	if w.rare_items.has(item_id):
		v *= float(w.mods["rare_mult"])
	if buffer_size_at_sale >= 20:
		v *= 1.0 + float(w.mods["bulk_bonus"])
	return maxi(int(round(v)), 0)


## Rezepte einer Maschinenart, die ohne Tech oder mit freigeschalteter Tech verfügbar sind.
static func available_recipes(w: SimWorld, machine_id: String) -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	for r in w.recipes:
		if r.machine == machine_id and (r.tech == "" or w.unlocked_tech.has(r.tech)):
			result.append(r)
	return result


## Nach einer Tech-Freischaltung: Rezeptlisten aller Maschinen erneuern.
static func refresh_recipes(w: SimWorld) -> void:
	for b: Building in w.buildings.values():
		if b is Machine:
			(b as Machine).recipes = available_recipes(w, b.def.id)
