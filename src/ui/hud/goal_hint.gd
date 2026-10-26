class_name GoalHint
extends RefCounted
## Nächstes Ziel für das HUD: das günstigste Schiff-Ziel (Reparatur, Ertrag, Bot, Drohne).
## Leistbares zuerst, dann ein freier Skillpunkt, sonst „noch N Bolts bis …“.


static func next_goal(w: SimWorld) -> Dictionary:
	var s := w.ship()
	var options: Array = []
	if s != null and ShipSystem.next_stage_cost(w, s) > 0 and ShipSystem.can_upgrade(w, s) != "planet":
		options.append({"name": TranslationServer.translate("SHIP_REPAIR_TO") % (s.stage + 1), "cost": ShipSystem.next_stage_cost(w, s),
			"icon": str(ShipSystem.stage_def(w, s.stage + 1).get("sprite", ""))})
	for u: Dictionary in ShipSystem.upgrade_defs(w):
		var c := ShipSystem.upgrade_cost(w, str(u["id"]))
		if c > 0:
			options.append({"name": "%s %d" % [TranslationServer.translate(str(u["name_key"])), ShipSystem.upgrade_level(w, str(u["id"])) + 1], "cost": c, "icon": str(u.get("icon", ""))})
	if w.can_buy_helper() in ["", "bolts"]:
		options.append({"name": TranslationServer.translate("BOT_CARD"), "cost": int(w.next_helper_cost()["bolts"]), "icon": "res://assets/sprites/robot/rusty.svg"})
	if w.can_buy_drone() in ["", "bolts"]:
		options.append({"name": TranslationServer.translate("DRONE_CARD"), "cost": int(w.next_drone_cost()["bolts"]), "icon": "res://assets/sprites/robot/drone.svg"})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["cost"]) < int(b["cost"]))
	for o: Dictionary in options:
		if w.bolts >= int(o["cost"]):
			return {"text": TranslationServer.translate("HUD_GOAL_READY") % o["name"], "icon": o["icon"], "ready": true}
	for d: Dictionary in w.skills.defs:
		if w.skills.can_buy(str(d["id"]), w.progression.skill_points) == "":
			return {"text": TranslationServer.translate("HUD_GOAL_SKILL"), "icon": "res://assets/sprites/ui/tab_skills.svg", "ready": true}
	if options.is_empty():
		return {}
	var o0: Dictionary = options[0]
	return {"text": TranslationServer.translate("HUD_GOAL_LEFT") % [Fmt.int_str(int(o0["cost"]) - w.bolts), o0["name"]], "icon": o0["icon"], "ready": false}
