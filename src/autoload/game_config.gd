extends Node
## Globale Konstanten und Feature-Flags. Erster Autoload, registriert die Input-Map.

const TILE_SIZE := 64
const TICKS_PER_SECOND := 20
const PLAYER_SPEED_PX := 256.0  # 4 Kacheln/s (GDD Kap. 4)
const AIM_DEADZONE := 0.3
## Kamera-Zoom: 1,5 zeigt ca. 20×11 Kacheln, damit Rusty auf 7 Zoll gut erkennbar ist.
const CAMERA_ZOOM := 1.5

# Feature-Flags: Systeme werden erst sichtbar, wenn der Meilenstein fertig ist.
const FEATURE_BUILDING := false
const FEATURE_TECH := false


func _ready() -> void:
	InputMapSetup.apply()
