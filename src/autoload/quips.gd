extends Node
## Rusty-Sprüche: wählt zu einem Auslöser einen zufälligen Übersetzungs-Key aus data/quips.json
## und sendet ihn über EventBus.quip. Höchstens ein Spruch alle 4 Sekunden (kosmetisch,
## daher kein Sim-Zufall nötig).

const COOLDOWN_SECONDS := 4.0

var _cooldown := 0.0
var _last_key := ""


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


## Liefert true, wenn ein Spruch ausgelöst wurde.
func say(trigger: String, force: bool = false) -> bool:
	if _cooldown > 0.0 and not force:
		return false
	var keys: Array = DataRegistry.quips.get(trigger, [])
	if keys.is_empty():
		return false
	var key := str(keys[randi() % keys.size()])
	if keys.size() > 1 and key == _last_key:
		key = str(keys[(keys.find(key) + 1) % keys.size()])
	_last_key = key
	_cooldown = COOLDOWN_SECONDS
	EventBus.quip.emit(key)
	return true
