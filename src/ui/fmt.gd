class_name Fmt
extends RefCounted
## Zahlen für die Anzeige.


## Ganzzahl mit Tausenderpunkt (de) bzw. -komma (en): 12.000 / 12,000.
static func int_str(n: int) -> String:
	var s := str(absi(n))
	var sep := "." if TranslationServer.get_locale().begins_with("de") else ","
	var out := ""
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
