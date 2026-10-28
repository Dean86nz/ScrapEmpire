extends Node
## Globale Signale zwischen Simulation, Darstellung und UI.

signal tick_done(tick_count: int)
signal device_changed(is_gamepad: bool)
signal quip(key: String)                     # Wunsch: Rusty soll etwas sagen (Quips filtert)
signal speak(key: String, seconds: float)    # wird wirklich gezeigt (eine Blase, MS44)
