class_name SkillState
extends RefCounted
## Skilltree: Stufen je Skill aus data/skills.json, bezahlt mit Skillpunkten (1 je Stufe).

signal skill_changed(id: String, level: int)

var branches: Array = []
var defs: Array = []
var by_id: Dictionary = {}
var levels: Dictionary = {}  # id → Stufe


static func load_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("skills.json nicht lesbar: " + path)
		return {"branches": [], "skills": []}
	return parsed


func setup(data: Dictionary) -> void:
	branches = data.get("branches", [])
	defs = data.get("skills", [])
	by_id.clear()
	for d: Dictionary in defs:
		by_id[str(d["id"])] = d


func level_of(id: String) -> int:
	return int(levels.get(id, 0))


func max_level(id: String) -> int:
	return int(by_id.get(id, {}).get("max_level", 0))


## Fehlende Voraussetzung als {skill, level} oder {} wenn erfüllt.
func missing_requirement(id: String) -> Dictionary:
	var req: Dictionary = by_id.get(id, {}).get("requires", {})
	for other in req:
		if level_of(str(other)) < int(req[other]):
			return {"skill": str(other), "level": int(req[other])}
	return {}


## "" wenn kaufbar, sonst Grund: unknown, max, requires, points
func can_buy(id: String, skill_points: int) -> String:
	if not by_id.has(id):
		return "unknown"
	if level_of(id) >= max_level(id):
		return "max"
	if not missing_requirement(id).is_empty():
		return "requires"
	if skill_points < 1:
		return "points"
	return ""


func buy(id: String) -> void:
	levels[id] = level_of(id) + 1
	skill_changed.emit(id, levels[id])


func skills_in_branch(branch_id: String) -> Array:
	var result: Array = []
	for d: Dictionary in defs:
		if str(d.get("branch", "")) == branch_id:
			result.append(d)
	return result


func total_levels() -> int:
	var n := 0
	for d: Dictionary in defs:
		n += int(d.get("max_level", 0))
	return n


func to_dict() -> Dictionary:
	return levels.duplicate()


func from_dict(d: Dictionary) -> void:
	levels.clear()
	for k in d:
		if by_id.has(str(k)):
			levels[str(k)] = clampi(int(d[k]), 0, max_level(str(k)))
