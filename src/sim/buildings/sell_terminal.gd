class_name SellTerminal
extends Building
## Verkaufsterminal: nimmt Items in einen FIFO-Puffer und verkauft alle 10 Ticks eines.
## Die Bolts bucht SimWorld (liest `take_sold()` nach dem Tick).

const BUFFER_MAX := 40     # manuelles Einlegen
const BELT_MAX := 10       # Bänder füllen nur bis 10 (GDD Kap. 6)
const SELL_INTERVAL := 10  # 1 Item / 0,5 s


func accept_from_belt(item_id: String) -> bool:
	if buffer.size() >= BELT_MAX:
		return false
	buffer.append(item_id)
	return true

var buffer: Array[String] = []
var _cooldown := 0
var _sold := ""


func accept_stack(item_id: String, count: int) -> int:
	var n := mini(count, BUFFER_MAX - buffer.size())
	for i in n:
		buffer.append(item_id)
	return n


func tick() -> bool:
	if _cooldown > 0:
		_cooldown -= 1
		if _cooldown > 0:
			return false
	if buffer.is_empty():
		return false
	_sold = buffer.pop_front()
	_cooldown = SELL_INTERVAL
	return true


func take_sold() -> String:
	var s := _sold
	_sold = ""
	return s


func contents() -> Dictionary:
	var result: Dictionary = {}
	for item in buffer:
		result[item] = result.get(item, 0) + 1
	return result


func summary() -> Dictionary:
	return {"buffer": buffer.size(), "buffer_max": BUFFER_MAX}
