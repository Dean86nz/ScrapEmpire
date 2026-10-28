class_name Modifiers
extends RefCounted
## Zentrale Sammlung aller aktiven Boni aus Skills und Tech (GDD Kap. 16, Architektur 10).
## Alle Spielwerte, die Skills/Tech beeinflussen, lesen nur hieraus.

const DEFAULTS := {
	"speed_mult": 1.0,          # Laufgeschwindigkeit
	"turn_mult": 1.0,           # Drehgeschwindigkeit
	"boost_cooldown": 0.0,      # Sekunden; 0 = kein Boost freigeschaltet
	"boost_mult": 1.4,
	"boost_seconds": 2.0,
	"slots_add": 0,             # zusätzliche Inventar-Slots
	"stack_add": 0,             # zusätzliche Stapelgröße
	"magnet_radius": 0,         # Kacheln, 0 = aus
	"sell_mult": 1.0,           # alle Verkäufe
	"rare_mult": 1.0,           # Kupfer, Plastik, Chrom und Produkte daraus
	"bulk_bonus": 0.0,          # wenn Terminal-Puffer ≥ 20 beim Verkauf
	"hammer_tier": 1,
	"suction_tier": 1,
	"mine_speed_mult": 1.0,     # Sauger- und Hammer-Takt
	"suck_interval_mult": 1.0,  # Tech Turbo-Sauger
	"range_add": 0.0,           # Kacheln Saug-/Hammerreichweite
	"hammer_items": 1,          # Items pro Hammerschlag
	"suck_speed_mult": 1.0,     # Schiff-Upgrade Saugtempo (teilt den Saugtakt)
	"suck_targets": 1,          # Teile je Saug-Zug (Skill Saugtempo, bis zum Wirbel)
	"suck_cone_deg": 90.0,      # Öffnung des Saugkegels; 360 = Wirbel rundherum
	"autopilot_speed_mult": 1.0,
	"helper_tier": 1,
	"helper_speed_mult": 1.0,
	"helper_capacity_add": 0,
	"drone_speed_mult": 1.0,
	"drone_capacity_add": 0,
}


## Berechnet die Boni aus Skill-Stufen und freigeschalteten Techs.
static func compute(skill_defs: Array, skill_levels: Dictionary, tech_defs: Array, unlocked_tech: Dictionary, upgrade_defs: Array = [], upgrade_levels: Dictionary = {}) -> Dictionary:
	var m: Dictionary = DEFAULTS.duplicate()
	for sd: Dictionary in skill_defs:
		var level: int = int(skill_levels.get(str(sd["id"]), 0))
		if level <= 0:
			continue
		for eff: Dictionary in sd.get("effects", []):
			_apply_skill_effect(m, eff, level)
	for ud: Dictionary in upgrade_defs:
		var ulevel: int = int(upgrade_levels.get(str(ud["id"]), 0))
		if ulevel <= 0:
			continue
		for eff: Dictionary in ud.get("effects", []):
			_apply_skill_effect(m, eff, ulevel)
	for td: Dictionary in tech_defs:
		if not unlocked_tech.has(str(td["id"])):
			continue
		for eff: Dictionary in td.get("effects", []):
			if str(eff.get("type", "")) == "modifier":
				_apply_tech_effect(m, eff)
	return m


static func _apply_skill_effect(m: Dictionary, eff: Dictionary, level: int) -> void:
	var key := str(eff["key"])
	match str(eff.get("op", "add")):
		"add":
			var per: float = float(eff.get("per_level", 0.0))
			if m[key] is int:
				m[key] = int(m[key]) + int(round(per * level))
			else:
				m[key] = float(m[key]) + per * level
		"table":
			var values: Array = eff.get("values", [])
			if not values.is_empty():
				m[key] = values[clampi(level, 1, values.size()) - 1]


static func _apply_tech_effect(m: Dictionary, eff: Dictionary) -> void:
	var key := str(eff["key"])
	var value: Variant = eff.get("value", 0)
	match str(eff.get("op", "set")):
		"add":
			if m[key] is int:
				m[key] = int(m[key]) + int(value)
			else:
				m[key] = float(m[key]) + float(value)
		"mult":
			m[key] = float(m[key]) * float(value)
		"set":
			m[key] = value
