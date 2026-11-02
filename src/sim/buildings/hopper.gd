class_name Hopper
extends CollectionPoint
## Fangtrichter (MS77): frei baubar, fängt die Müllwürfel der Streuner auf. Hat eine Kapazität;
## ist er voll, fliegen Würfel zum nächsten freien Trichter. Drohnen holen ab wie bei der
## Sammelstelle (geerbt) und bringen alles zum Schiff.

var capacity := 120
var incoming := 0   # Teile in Würfeln, die gerade hierher fliegen (Platz ist schon reserviert)


## Nimmt nur so viel an, wie noch passt; gibt die angenommene Menge zurück.
func accept_stack(item_id: String, count: int) -> int:
	return super.accept_stack(item_id, mini(count, maxi(capacity - total(), 0)))


## Platz für neue Würfel (abzüglich schon fliegender).
func free_space() -> int:
	return capacity - total() - incoming


func is_full() -> bool:
	return total() >= capacity


func summary() -> Dictionary:
	return {"stored": total(), "capacity": capacity}
