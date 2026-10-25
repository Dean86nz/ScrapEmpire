class_name Progression
extends RefCounted
## Erfahrung, Level und Skillpunkte (GDD Kap. 15). Zahlen aus data/progression.json.

signal xp_changed(xp: int, needed: int, level: int)
signal level_up(level: int, skill_points: int)

var base_xp := 100
var growth := 1.15
var round_to := 5
var level_cap := 20
var points_per_level := 1
var collect_per_tier := 1
var bolts_per_xp := 5
var build_xp := 5
var tech_cost_divisor := 10

var xp: int = 0            # XP innerhalb des aktuellen Levels
var level: int = 1
var skill_points: int = 0
var total_xp: int = 0
var _bolts_accum: int = 0


static func load_config(path: String) -> Progression:
	var p := Progression.new()
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("progression.json nicht lesbar: " + path)
		return p
	p.base_xp = int(parsed.get("level_base_xp", 100))
	p.growth = float(parsed.get("level_growth", 1.15))
	p.round_to = int(parsed.get("level_round_to", 5))
	p.level_cap = int(parsed.get("level_cap", 20))
	p.points_per_level = int(parsed.get("skill_points_per_level", 1))
	var src: Dictionary = parsed.get("xp_sources", {})
	p.collect_per_tier = int(src.get("collect_per_tier", 1))
	p.bolts_per_xp = int(src.get("bolts_per_xp", 5))
	p.build_xp = int(src.get("build", 5))
	p.tech_cost_divisor = int(src.get("tech_cost_divisor", 10))
	return p


## XP, die nötig sind, um von Level n-1 auf Level n zu kommen (n ≥ 2).
func xp_for_level(n: int) -> int:
	if n <= 1:
		return 0
	var raw := float(base_xp) * pow(growth, n - 2)
	return maxi(int(round(raw / round_to)) * round_to, 1)


func xp_needed() -> int:
	return xp_for_level(level + 1)


func is_max_level() -> bool:
	return level >= level_cap


func add_xp(amount: int) -> void:
	if amount <= 0 or is_max_level():
		return
	xp += amount
	total_xp += amount
	while not is_max_level() and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += points_per_level
		level_up.emit(level, skill_points)
	if is_max_level():
		xp = 0
	xp_changed.emit(xp, xp_needed(), level)


func on_collect(tier: int) -> void:
	add_xp(collect_per_tier * maxi(tier, 1))


func on_sale(bolts: int) -> void:
	_bolts_accum += bolts
	var gained := _bolts_accum / bolts_per_xp
	if gained > 0:
		_bolts_accum -= gained * bolts_per_xp
		add_xp(gained)


func on_build() -> void:
	add_xp(build_xp)


func on_tech(cost_bolts: int) -> void:
	add_xp(cost_bolts / tech_cost_divisor)


func to_dict() -> Dictionary:
	return {"xp": xp, "level": level, "skill_points": skill_points, "total_xp": total_xp, "bolts_accum": _bolts_accum}


func from_dict(d: Dictionary) -> void:
	xp = int(d.get("xp", 0))
	level = clampi(int(d.get("level", 1)), 1, level_cap)
	skill_points = int(d.get("skill_points", 0))
	total_xp = int(d.get("total_xp", 0))
	_bolts_accum = int(d.get("bolts_accum", 0))
	xp_changed.emit(xp, xp_needed(), level)
