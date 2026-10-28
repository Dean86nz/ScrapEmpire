class_name ResearchSystem
extends RefCounted
## Skills, Modifikatoren (Skills + Schiff-, Bot- und Drohnen-Upgrades), Freischaltungen, Verkaufswert.
## Der frühere Forschungsbaum ist leer (data/tech.json); Freischaltungen kommen über Schiffsstufen.
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
	upgrade_defs.append_array(w.ship_cfg.get("upgrades", []))
	var upgrade_levels := w.helper_upgrades.duplicate()
	upgrade_levels.merge(w.drone_upgrades)
	upgrade_levels.merge(w.ship_upgrades)
	w.mods = Modifiers.compute(w.skills.defs, w.skills.levels, w.tech.defs, w.tech.unlocked, upgrade_defs, upgrade_levels)
	w.mods["sell_mult"] = float(w.mods["sell_mult"]) * SecretSystem.sell_bonus(w)  # Secrets (MS60)
	if w.player.apply_modifiers(w.mods):
		w.inventory_resized.emit()
	for h: Helper in w.helpers.values():
		w._apply_helper_mods(h)
	for d: Drone in w.drones.values():
		w._apply_drone_mods(d)
	w.modifiers_changed.emit(w.mods)


static func _apply_tech_effects(w: SimWorld, id: String) -> void:
	w.unlocked_tech[id] = true
	for eff: Dictionary in w.tech.effects_of(id):
		match str(eff.get("type", "")):
			"unlock_building":
				w.unlocked_buildings[str(eff["id"])] = true
			"unlock_feature":
				w.unlocked_features[str(eff["id"])] = true


static func _cmd_buy_skill(w: SimWorld, cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := w.skills.can_buy(id, w.progression.skill_points)
	if reason != "":
		w.skill_failed.emit(reason)
		return
	w.progression.skill_points -= w.skills.cost(id)
	w.skills.buy(id)
	recompute_modifiers(w)
	w.skill_bought.emit(id, w.skills.level_of(id))
