extends Node
## Rusty-Sprüche (seit MS44 dezenter): Alle Wünsche kommen über EventBus.quip (Ereignisse) oder
## Quips.say (Auslöser aus data/quips.json). Gezeigt wird höchstens eine Blase gleichzeitig:
## Ereignisse frühestens `event_gap_s` nach der letzten, Plaudereien höchstens alle `chatter_gap_s`.
## Was gezeigt wird, geht über EventBus.speak an Rustys Sprechblase.

var _since_any := 999.0
var _since_chatter := 0.0     # beim Start erst einmal Ruhe
var _last_key := ""
var _chatter_next := false


func _ready() -> void:
	if not EventBus.quip.is_connected(_on_request):
		EventBus.quip.connect(_on_request)


func _process(delta: float) -> void:
	_since_any += delta
	_since_chatter += delta


func _cfg(key: String, fallback: float) -> float:
	return float(DataRegistry.quips.get("_config", {}).get(key, fallback))


## Liefert true, wenn ein Spruch gewünscht wurde. force = echtes Ereignis, sonst Plauderei.
func say(trigger: String, force: bool = false) -> bool:
	var keys: Array = DataRegistry.quips.get(trigger, [])
	if keys.is_empty():
		return false
	if not force and (_since_chatter < _cfg("chatter_gap_s", 150.0) or _since_any < _cfg("event_gap_s", 6.0)):
		return false
	var key := str(keys[randi() % keys.size()])
	if keys.size() > 1 and key == _last_key:
		key = str(keys[(keys.find(key) + 1) % keys.size()])
	_last_key = key
	_chatter_next = not force
	EventBus.quip.emit(key)
	return true


func _on_request(key: String) -> void:
	var chatter := _chatter_next
	_chatter_next = false
	if _since_any < _cfg("event_gap_s", 6.0):
		return
	_since_any = 0.0
	if chatter:
		_since_chatter = 0.0
	EventBus.speak.emit(key, _cfg("show_s", 2.0))
