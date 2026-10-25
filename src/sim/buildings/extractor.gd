class_name Extractor
extends Building
## Saugstation (1×1): zieht alle 60 Ticks ein Item aus einem angrenzenden Haufen (Tier 1)
## in einen Puffer (max 5) und gibt es vorne (rot = Richtung) auf ein Band. Der Füllstand
## des Haufens bleibt unberührt: die Station gräbt tiefer (GDD Kap. 6, Saugstation).

const INTERVAL := 60
const BUFFER_MAX := 5
const TIER := 1

var buffer: Array[String] = []
var counter := 0


func dir() -> Vector2i:
	return Conveyor.DIRS[posmod(rot, 4)]


func output_tile() -> Vector2i:
	return tile + dir()


func wants_item() -> bool:
	return buffer.size() < BUFFER_MAX


## Von der Welt pro Tick aufgerufen; liefert true, wenn jetzt ein Item gezogen werden soll.
func tick_extract() -> bool:
	if not wants_item():
		counter = 0
		return false
	counter += 1
	if counter >= INTERVAL:
		counter = 0
		return true
	return false


func has_output() -> bool:
	return not buffer.is_empty()


func pop_output_one() -> String:
	return buffer.pop_front() if not buffer.is_empty() else ""


func withdraw_stack() -> Dictionary:
	if buffer.is_empty():
		return {}
	var item := buffer[0]
	var n := 0
	while not buffer.is_empty() and buffer[0] == item:
		buffer.pop_front()
		n += 1
	return {"item": item, "count": n}


func contents() -> Dictionary:
	var result: Dictionary = {}
	for item in buffer:
		result[item] = result.get(item, 0) + 1
	return result


func summary() -> Dictionary:
	return {"buffer": buffer.size(), "buffer_max": BUFFER_MAX}
