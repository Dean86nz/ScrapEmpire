class_name Machine
extends Building
## Verarbeitende Maschine (Schmelzofen, Presse): Eingangspuffer je Item max. 10,
## Ausgangspuffer gesamt max. 10. Wählt das erste Rezept, dessen Inputs vorliegen.

const INPUT_MAX_PER_ITEM := 10
const OUTPUT_MAX_TOTAL := 10

var recipes: Array[RecipeDef] = []   # verfügbare (freigeschaltete) Rezepte, von der Welt gesetzt
var input: Dictionary = {}           # item_id → Menge
var output: Dictionary = {}          # item_id → Menge
var progress_ticks := 0
var current_recipe: RecipeDef = null


func accepts_item(item_id: String) -> bool:
	for r in recipes:
		if r.inputs.has(item_id):
			return true
	return false


func accept_stack(item_id: String, count: int) -> int:
	if not accepts_item(item_id):
		return 0
	var have: int = input.get(item_id, 0)
	var n := mini(count, INPUT_MAX_PER_ITEM - have)
	if n <= 0:
		return 0
	input[item_id] = have + n
	return n


func output_total() -> int:
	var n := 0
	for k in output:
		n += int(output[k])
	return n


func _recipe_ready(r: RecipeDef) -> bool:
	for item in r.inputs:
		if int(input.get(item, 0)) < int(r.inputs[item]):
			return false
	return true


func _output_has_room(r: RecipeDef) -> bool:
	return output_total() + r.output_count <= OUTPUT_MAX_TOTAL


## Ein Rezept hat alle Inputs, aber der Ausgang ist voll.
func is_blocked() -> bool:
	if progress_ticks > 0:
		return false
	for r in recipes:
		if _recipe_ready(r):
			return not _output_has_room(r)
	return false


## Nichts zu tun, weil keine Inputs vorliegen.
func is_idle() -> bool:
	if progress_ticks > 0:
		return false
	for r in recipes:
		if _recipe_ready(r):
			return false
	return true


func progress_fraction() -> float:
	if current_recipe == null or progress_ticks <= 0:
		return 0.0
	return 1.0 - float(progress_ticks) / float(current_recipe.ticks)


func tick() -> bool:
	if progress_ticks > 0:
		progress_ticks -= 1
		if progress_ticks == 0:
			output[current_recipe.output_item] = int(output.get(current_recipe.output_item, 0)) + current_recipe.output_count
			return true
		return false
	for r in recipes:
		if _recipe_ready(r) and _output_has_room(r):
			for item in r.inputs:
				input[item] = int(input[item]) - int(r.inputs[item])
				if input[item] == 0:
					input.erase(item)
			current_recipe = r
			progress_ticks = r.ticks
			return true
	return false


## Entnimmt zuerst aus dem Ausgang, sonst aus dem Eingang (damit Fehleinwürfe korrigierbar sind).
func withdraw_stack() -> Dictionary:
	for buf in [output, input]:
		for item in buf.keys():
			var count: int = int(buf[item])
			if count > 0:
				buf.erase(item)
				return {"item": item, "count": count}
	return {}


func contents() -> Dictionary:
	var result: Dictionary = {}
	for item in input:
		result[item] = result.get(item, 0) + int(input[item])
	for item in output:
		result[item] = result.get(item, 0) + int(output[item])
	return result


func summary() -> Dictionary:
	return {
		"input": input.duplicate(),
		"output": output.duplicate(),
		"progress": progress_fraction(),
		"blocked": is_blocked(),
		"idle": is_idle(),
		"recipe": current_recipe.id if current_recipe != null and progress_ticks > 0 else "",
	}
