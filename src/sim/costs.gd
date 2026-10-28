class_name Costs
extends RefCounted
## Upgrade-Kosten (MS57): entweder Liste `cost_bolts` je Stufe (alt) oder Formel
## `cost_base` × `cost_growth`^Stufe für tiefe Upgrades (20–50 Stufen).


static func upgrade(u: Dictionary, level: int) -> int:
	if u.has("cost_base"):
		return int(round(float(u["cost_base"]) * pow(float(u.get("cost_growth", 1.2)), level)))
	var list: Array = u.get("cost_bolts", [])
	return int(list[clampi(level, 0, list.size() - 1)]) if not list.is_empty() else 0
