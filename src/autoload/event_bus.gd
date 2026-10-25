extends Node
## Globale Signale zwischen Simulation, Darstellung und UI.

signal tick_done(tick_count: int)
signal device_changed(is_gamepad: bool)
signal quip(key: String)
