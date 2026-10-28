class_name CollectionPoint
extends Building
## Sammelstelle (Recycling-Container, MS34): eine je Zone. Rusty, Bots und der Kurier laden hier ab,
## Drohnen bringen das Material zum Schiff. Bolts gibt es erst, wenn es dort ankommt.

var store: Dictionary = {}   # item → Menge


## Nimmt alles an (unbegrenztes Lager).
func accept_stack(item_id: String, count: int) -> int:
	if count <= 0 or item_id == "":
		return 0
	store[item_id] = int(store.get(item_id, 0)) + count
	return count


func total() -> int:
	var n := 0
	for k in store:
		n += int(store[k])
	return n


## Entnimmt bis zu `max_n` Teile (größte Sorte zuerst, deterministisch).
func take(max_n: int) -> Dictionary:
	var out := {}
	var keys := store.keys()
	keys.sort()
	var left := max_n
	while left > 0 and total() > 0:
		var best := ""
		var best_n := 0
		for k: String in keys:
			if int(store.get(k, 0)) > best_n:
				best = k
				best_n = int(store[k])
		var n := mini(best_n, left)
		store[best] = best_n - n
		if int(store[best]) <= 0:
			store.erase(best)
		out[best] = int(out.get(best, 0)) + n
		left -= n
	return out


func contents() -> Dictionary:
	return store.duplicate()


func summary() -> Dictionary:
	return {"stored": total()}
