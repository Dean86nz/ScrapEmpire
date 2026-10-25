class_name MenuInput
extends RefCounted
## Gemeinsame Gamepad-Logik für alle Menüs.
## A bestätigt, B geht zurück. Normalerweise verarbeitet der fokussierte Button den A-Druck selbst
## (Godots ui_accept). Kommt der Druck trotzdem als „interact“ unten an (z. B. Ally X im Desktop-Modus
## oder fehlender Fokus-Handler), löst press_focused() den fokussierten Button aus. Doppelt feuern
## kann es nicht: ein Button, der ui_accept verarbeitet, markiert das Ereignis als erledigt.


static func accept_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")


static func back_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")


## Löst den fokussierten, sichtbaren, aktiven Button aus. true, wenn einer gedrückt wurde.
static func press_focused(viewport: Viewport) -> bool:
	var f := viewport.gui_get_focus_owner()
	if f is BaseButton and f.is_visible_in_tree() and not (f as BaseButton).disabled:
		(f as BaseButton).pressed.emit()
		return true
	return false
