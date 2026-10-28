class_name BossSystem
extends RefCounted
## Müllberg-Bosse mit Verstärkung (MS42): Haut Rusty auf einen Boss, ruft er alle Bots im Umkreis.
## Sie rennen hin und hauen mit. Schaden nimmt der Boss nur, solange mindestens `bots_needed` Bots
## bei ihm sind. Werte in data/helpers.json („reinforce_*“) und data/scrap_objects.json.


## Ruft alle Bots im Umkreis zum Boss. Gibt die Zahl neu gerufener Bots zurück.
static func rally(w: SimWorld, boss: ResourceNode) -> int:
	var radius := float(w.helper_cfg.get("reinforce_radius_tiles", 30)) * SimWorld.TILE
	var center := Vector2(boss.center_px())
	var called := 0
	for h: Helper in w.helpers.values():
		if h.rally_id == boss.id:
			continue
		if Vector2(h.pos).distance_to(center) <= radius:
			h.rally_id = boss.id
			h.bored = ""
			h.tasks.stop(h)
			h.request_replan()
			called += 1
	if called > 0:
		w.boss_rally.emit(boss, called)
	return called


## Bots, die gerade beim Boss stehen und mithauen.
static func helpers_at(w: SimWorld, boss: ResourceNode) -> int:
	var reach := float(w.helper_cfg.get("reinforce_reach_px", 260))
	var center := Vector2(boss.center_px())
	var n := 0
	for h: Helper in w.helpers.values():
		if h.rally_id == boss.id and Vector2(h.pos).distance_to(center) <= reach:
			n += 1
	return n


## Nur gemeinsam: Schaden erst, wenn genug Bots dabei sind.
static func can_damage(w: SimWorld, boss: ResourceNode) -> bool:
	return helpers_at(w, boss) >= boss.bots_needed


## Boss weg: alle gerufenen Bots kehren zur normalen Arbeit zurück.
static func release(w: SimWorld, boss_id: int) -> void:
	for h: Helper in w.helpers.values():
		if h.rally_id == boss_id:
			h.rally_id = -1
			h.request_replan()
