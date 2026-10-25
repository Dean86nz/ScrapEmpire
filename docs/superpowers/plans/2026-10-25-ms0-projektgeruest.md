# MS0 Projektgerüst – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein startbares Godot-4.7.2-Projekt, in dem Rusty (SVG-Platzhalter) sich per linkem Stick/WASD über eine begrenzte Fläche bewegt, die Kamera folgt, ein Debug-Overlay FPS und Tick-Zeit zeigt, Sim-Clock mit 20 Ticks/s läuft und ein Headless-Test-Runner grün ist.

**Architecture:** Simulation (`src/sim/`, reine RefCounted-Klassen, Integer-Ticks) ist von der Darstellung (`src/world/`, `src/ui/`) getrennt. Autoloads (`src/autoload/`) verbinden beide. Input-Aktionen werden zur Laufzeit per `InputMap` registriert (testbar, kein handgeschriebenes Serialisierungsformat in project.godot).

**Tech Stack:** Godot 4.7.2 stable (liegt in `Godot_v4.7.2-stable_win64.exe/`), GDScript, SVG-Platzhalter, Git.

**Spec:** `docs/02_ARCHITECTURE.md` (Kap. 2, 4.1, 4.9, 5, 6, 7), `docs/03_ROADMAP.md` (MS0), `docs/01_GDD.md` (Kap. 4, 12).

## Global Constraints

- Auflösung 1920×1080, Stretch `canvas_items`, Aspect `keep`
- Kachelgröße 64 px, Rusty 4 Kacheln/s = 256 px/s, Deadzone 0,2
- 20 Ticks/s (TICK_DT = 0,05 s), Sim ohne Floats
- Schrift: Standard 24 px, Minimum 22 px
- Keine Plugins/Addons, kein C#
- Engine-Ordner, `.godot/`, `export/` nicht im Git
- Godot-Aufruf headless: `./Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe --headless --path . <args>`

---

### Task 1: Git, .gitignore, project.godot, Ordner

**Files:**
- Create: `.gitignore`, `project.godot`, `README.md`, `.gitattributes`
- Create (leer, mit `.gitkeep`): `assets/sprites/{robot,items,buildings,tiles,ui}`, `assets/fonts`, `assets/audio`, `data/maps`, `locale`, `src/autoload`, `src/sim/buildings`, `src/world/player`, `src/ui/{theme,hud,build_menu,tech_tree,pause_menu,task_editor,task_hud,tutorial,widgets}`, `tests`, `addons`

**Interfaces:**
- Produces: Projekt öffnet im Editor, Hauptszene `res://src/world/main.tscn` (kommt in Task 4), Autoload-Einträge für Task 2/3.

- [x] **Step 1: .gitignore**

```
# Godot
.godot/
export/
*.translation
# Engine binary lives in project folder but not in repo
Godot_v4.7.2-stable_win64.exe/
# OS
Thumbs.db
.DS_Store
```

- [x] **Step 2: project.godot** (Autoloads werden in Task 2 ergänzt, Hauptszene in Task 4)

```ini
; Engine configuration file.
config_version=5

[application]
config/name="Scrap Empire"
config/version="0.0.1"
run/main_scene="res://src/world/main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode.template=3
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[gui]
theme/custom="res://src/ui/theme/scrap_theme.tres"

[input_devices]
pointing/emulate_touch_from_mouse=false

[rendering]
renderer/rendering_method="mobile"
environment/defaults/default_clear_color=Color(0.96, 0.87, 0.55, 1)
textures/canvas_textures/default_texture_filter=1
```

Begründung `mobile`-Renderer: niedrigerer GPU-Verbrauch im 15-W-Modus, 2D braucht Forward+ nicht.

- [x] **Step 3: git init, Ordner anlegen, erster Commit**

```bash
git init -b main
mkdir -p ... (siehe Files)
git add -A && git commit -m "ms0: Projektgerüst, .gitignore, project.godot"
```

---

### Task 2: Sim-Kern und Test-Runner

**Files:**
- Create: `src/sim/tick_accumulator.gd`, `src/sim/world.gd`
- Create: `tests/test_case.gd`, `tests/run_tests.gd`, `tests/test_tick_accumulator.gd`, `tests/test_world.gd`

**Interfaces:**
- Produces: `class_name TickAccumulator` mit `advance(delta: float) -> int` (Anzahl fälliger Ticks) und `alpha: float`; `class_name SimWorld` mit `tick_count: int`, `queue_command(cmd: Dictionary)`, `tick()`; `class_name TestCase` mit `assert_eq`, `assert_true`, `failures: Array[String]`.

- [x] **Step 1: Test-Basisklasse und Runner**

```gdscript
# tests/test_case.gd
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var _current: String = ""

func set_current(name: String) -> void:
    _current = name

func assert_eq(actual, expected, msg: String = "") -> void:
    if actual != expected:
        failures.append("%s: expected %s, got %s %s" % [_current, str(expected), str(actual), msg])

func assert_true(cond: bool, msg: String = "") -> void:
    if not cond:
        failures.append("%s: expected true %s" % [_current, msg])
```

```gdscript
# tests/run_tests.gd
extends SceneTree

func _initialize() -> void:
    var total := 0
    var failed: Array[String] = []
    for file in DirAccess.get_files_at("res://tests"):
        if not file.begins_with("test_") or not file.ends_with(".gd"):
            continue
        var script: GDScript = load("res://tests/" + file)
        var case: TestCase = script.new()
        for m in script.get_script_method_list():
            if not m.name.begins_with("test_"):
                continue
            total += 1
            case.set_current(file + "::" + m.name)
            case.call(m.name)
        failed.append_array(case.failures)
    for f in failed:
        printerr("FAIL " + f)
    print("%d tests, %d failures" % [total, failed.size()])
    quit(1 if failed.size() > 0 else 0)
```

- [x] **Step 2: Failing tests**

```gdscript
# tests/test_tick_accumulator.gd
extends TestCase

func test_one_tick_per_50ms() -> void:
    var acc := TickAccumulator.new()
    assert_eq(acc.advance(0.05), 1)

func test_accumulates_partial_frames() -> void:
    var acc := TickAccumulator.new()
    assert_eq(acc.advance(0.03), 0)
    assert_eq(acc.advance(0.03), 1)
    assert_true(abs(acc.alpha - 0.2) < 0.001, "alpha nach 0.06s")

func test_clamps_large_delta() -> void:
    var acc := TickAccumulator.new()
    assert_eq(acc.advance(10.0), 5)  # max 0.25 s = 5 Ticks
```

```gdscript
# tests/test_world.gd
extends TestCase

func test_tick_increments() -> void:
    var w := SimWorld.new()
    w.tick()
    w.tick()
    assert_eq(w.tick_count, 2)

func test_commands_consumed_on_tick() -> void:
    var w := SimWorld.new()
    w.queue_command({"type": "noop"})
    assert_eq(w.pending_commands(), 1)
    w.tick()
    assert_eq(w.pending_commands(), 0)
```

- [x] **Step 3: Run, expect FAIL** (Klassen fehlen → Parse-Fehler, Exit ≠ 0)

- [x] **Step 4: Implementierung**

```gdscript
# src/sim/tick_accumulator.gd
class_name TickAccumulator
extends RefCounted

const TICK_DT := 0.05
const MAX_FRAME_DT := 0.25

var _accumulator := 0.0
var alpha := 0.0

func advance(delta: float) -> int:
    _accumulator += minf(delta, MAX_FRAME_DT)
    var ticks := 0
    while _accumulator >= TICK_DT - 0.000001:
        _accumulator -= TICK_DT
        ticks += 1
    alpha = _accumulator / TICK_DT
    return ticks
```

```gdscript
# src/sim/world.gd
class_name SimWorld
extends RefCounted

var tick_count: int = 0
var _commands: Array[Dictionary] = []

func queue_command(cmd: Dictionary) -> void:
    _commands.append(cmd)

func pending_commands() -> int:
    return _commands.size()

func tick() -> void:
    for cmd in _commands:
        _apply(cmd)
    _commands.clear()
    tick_count += 1

func _apply(_cmd: Dictionary) -> void:
    pass  # Befehle kommen ab MS1
```

- [x] **Step 5: Run, expect `5 tests, 0 failures`, Commit** `ms0: Sim-Kern (TickAccumulator, SimWorld) und Test-Runner`

---

### Task 3: Autoloads (GameConfig, InputMapSetup, EventBus, SimClock, DataRegistry-Stub, SaveManager-Stub, InputRouter)

**Files:**
- Create: `src/autoload/game_config.gd`, `src/autoload/event_bus.gd`, `src/autoload/sim_clock.gd`, `src/autoload/data_registry.gd`, `src/autoload/save_manager.gd`, `src/autoload/input_router.gd`, `src/autoload/input_map_setup.gd`
- Modify: `project.godot` (Abschnitt `[autoload]`)
- Test: `tests/test_input_map.gd`

**Interfaces:**
- Produces: `GameConfig.TILE_SIZE = 64`, `GameConfig.PLAYER_SPEED_PX = 256.0`, `GameConfig.TICKS_PER_SECOND = 20`; `SimClock.world: SimWorld`, `SimClock.paused: bool`, `SimClock.last_tick_ms: float`, `SimClock.alpha`; `InputMapSetup.apply()` (static) registriert Aktionen `move_left/right/up/down, aim_left/right/up/down, tool_primary, tool_secondary, interact, cancel, build_menu, tool_swap, hotbar_prev, hotbar_next, tech_tree, pause, cursor_up/down/left/right, debug_overlay, toggle_fullscreen`; `EventBus` Signale `tick_done(tick_count)`, `device_changed(is_gamepad)`.

- [x] **Step 1: Failing test**

```gdscript
# tests/test_input_map.gd
extends TestCase

func test_all_actions_registered() -> void:
    InputMapSetup.apply()
    for action in InputMapSetup.ACTIONS.keys():
        assert_true(InputMap.has_action(action), "Aktion fehlt: " + action)

func test_apply_is_idempotent() -> void:
    InputMapSetup.apply()
    InputMapSetup.apply()
    assert_eq(InputMap.action_get_events("move_left").size(), InputMapSetup.ACTIONS["move_left"].size())
```

- [x] **Step 2: InputMapSetup**

```gdscript
# src/autoload/input_map_setup.gd
class_name InputMapSetup
extends RefCounted

const DEADZONE := 0.2

static func _key(code: Key) -> InputEventKey:
    var e := InputEventKey.new(); e.physical_keycode = code; return e
static func _btn(b: JoyButton) -> InputEventJoypadButton:
    var e := InputEventJoypadButton.new(); e.button_index = b; return e
static func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
    var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v; return e
static func _mouse(b: MouseButton) -> InputEventMouseButton:
    var e := InputEventMouseButton.new(); e.button_index = b; return e

static var ACTIONS: Dictionary = {
    "move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
    "move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
    "move_up": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
    "move_down": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
    "aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
    "aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
    "aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
    "aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
    "tool_primary": [_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _mouse(MOUSE_BUTTON_LEFT)],
    "tool_secondary": [_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _mouse(MOUSE_BUTTON_RIGHT)],
    "interact": [_btn(JOY_BUTTON_A), _key(KEY_E)],
    "cancel": [_btn(JOY_BUTTON_B), _key(KEY_ESCAPE)],
    "build_menu": [_btn(JOY_BUTTON_Y), _key(KEY_TAB)],
    "tool_swap": [_btn(JOY_BUTTON_X), _key(KEY_Q)],
    "hotbar_prev": [_btn(JOY_BUTTON_LEFT_SHOULDER), _mouse(MOUSE_BUTTON_WHEEL_UP)],
    "hotbar_next": [_btn(JOY_BUTTON_RIGHT_SHOULDER), _mouse(MOUSE_BUTTON_WHEEL_DOWN)],
    "tech_tree": [_btn(JOY_BUTTON_BACK), _key(KEY_T)],
    "pause": [_btn(JOY_BUTTON_START), _key(KEY_ESCAPE)],
    "cursor_up": [_btn(JOY_BUTTON_DPAD_UP), _key(KEY_UP)],
    "cursor_down": [_btn(JOY_BUTTON_DPAD_DOWN), _key(KEY_DOWN)],
    "cursor_left": [_btn(JOY_BUTTON_DPAD_LEFT), _key(KEY_LEFT)],
    "cursor_right": [_btn(JOY_BUTTON_DPAD_RIGHT), _key(KEY_RIGHT)],
    "debug_overlay": [_key(KEY_F3)],
    "toggle_fullscreen": [_key(KEY_F11)],
}

static func apply() -> void:
    for action in ACTIONS.keys():
        if InputMap.has_action(action):
            InputMap.action_erase_events(action)
        else:
            InputMap.add_action(action, DEADZONE)
        for ev in ACTIONS[action]:
            InputMap.action_add_event(action, ev)
```

- [x] **Step 3: Übrige Autoloads**

```gdscript
# src/autoload/game_config.gd
extends Node
const TILE_SIZE := 64
const TICKS_PER_SECOND := 20
const PLAYER_SPEED_PX := 256.0   # 4 Kacheln/s
const AIM_DEADZONE := 0.3
func _ready() -> void:
    InputMapSetup.apply()
```

```gdscript
# src/autoload/event_bus.gd
extends Node
signal tick_done(tick_count: int)
signal device_changed(is_gamepad: bool)
```

```gdscript
# src/autoload/sim_clock.gd
extends Node
var world: SimWorld = SimWorld.new()
var paused := false
var last_tick_ms := 0.0
var alpha := 0.0
var _acc := TickAccumulator.new()

func _process(delta: float) -> void:
    if paused:
        return
    var ticks := _acc.advance(delta)
    for i in ticks:
        var t0 := Time.get_ticks_usec()
        world.tick()
        last_tick_ms = (Time.get_ticks_usec() - t0) / 1000.0
        EventBus.tick_done.emit(world.tick_count)
    alpha = _acc.alpha
```

```gdscript
# src/autoload/data_registry.gd
extends Node
# Lädt ab MS1 data/*.json. MS0: leer, damit der Autoload-Pfad steht.
var items: Dictionary = {}
```

```gdscript
# src/autoload/save_manager.gd
extends Node
# Kommt in MS6. Platzhalter, damit Autoload-Reihenfolge feststeht.
const SAVE_VERSION := 1
```

```gdscript
# src/autoload/input_router.gd
extends Node
enum Context { GAME, BUILD, MENU }
var context: Context = Context.GAME
var is_gamepad := true

func _input(event: InputEvent) -> void:
    var gp := event is InputEventJoypadButton or event is InputEventJoypadMotion
    var kb := event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion
    if gp and not is_gamepad:
        is_gamepad = true
        EventBus.device_changed.emit(true)
    elif kb and is_gamepad and not (event is InputEventMouseMotion and event.relative.length() < 2.0):
        is_gamepad = false
        EventBus.device_changed.emit(false)
    if event.is_action_pressed("toggle_fullscreen"):
        var w := get_window()
        w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
```

project.godot:

```ini
[autoload]
GameConfig="*res://src/autoload/game_config.gd"
EventBus="*res://src/autoload/event_bus.gd"
DataRegistry="*res://src/autoload/data_registry.gd"
SimClock="*res://src/autoload/sim_clock.gd"
SaveManager="*res://src/autoload/save_manager.gd"
InputRouter="*res://src/autoload/input_router.gd"
```

- [x] **Step 4: Tests grün (7 tests), Commit** `ms0: Autoloads, Input-Map zur Laufzeit, SimClock`

---

### Task 4: Welt, Rusty, Kamera, Theme, Debug-Overlay, Hauptszene

**Files:**
- Create: `assets/sprites/robot/rusty.svg`, `assets/sprites/tiles/ground.svg`, `icon.svg`
- Create: `src/ui/theme/scrap_theme.tres`
- Create: `src/world/player/player.gd`, `src/world/player/player.tscn`, `src/world/camera.gd`, `src/world/main.gd`, `src/world/main.tscn`
- Create: `src/ui/hud/debug_overlay.gd`, `src/ui/hud/debug_overlay.tscn`

**Interfaces:**
- Produces: `Player` (CharacterBody2D) mit `aim_dir: Vector2`, `facing: Vector2`; `Main` baut Boden (Sprite2D, repeat, 120×90 Kacheln) und vier StaticBody2D-Wände; `DebugOverlay` liest `Engine.get_frames_per_second()`, `SimClock.last_tick_ms`, `SimClock.world.tick_count`.

- [x] **Step 1: SVGs** (Rusty 56 px: orange runder Körper, dunkle 4-px-Outline, zwei Augen, Antenne; Boden 64 px: sandgelb mit zwei helleren Kieseln)

- [x] **Step 2: Theme**

```
[gd_resource type="Theme" format=3]
[resource]
default_font_size = 24
```

- [x] **Step 3: player.gd**

```gdscript
class_name Player
extends CharacterBody2D

var aim_dir := Vector2.RIGHT
var facing := Vector2.RIGHT
@onready var _aim_marker: Node2D = $AimMarker

func _physics_process(_delta: float) -> void:
    var move := Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.2)
    velocity = move * GameConfig.PLAYER_SPEED_PX
    move_and_slide()
    var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", GameConfig.AIM_DEADZONE)
    if not InputRouter.is_gamepad:
        aim = (get_global_mouse_position() - global_position).normalized()
    if aim.length() > 0.0:
        aim_dir = aim.normalized()
    elif move.length() > 0.0:
        aim_dir = move.normalized()
    if move.length() > 0.0:
        facing = move.normalized()
    _aim_marker.rotation = aim_dir.angle()
```

Szene `player.tscn`: CharacterBody2D (motion_mode Floating) → CollisionShape2D (CircleShape2D r=24) → Sprite2D (rusty.svg) → AimMarker (Node2D) → Polygon2D (kleines Dreieck bei x=36) → Camera2D (position_smoothing_enabled, speed 8, zoom 1).

- [x] **Step 4: main.gd baut Boden und Wände**

```gdscript
extends Node2D
const WORLD_W := 120
const WORLD_H := 90
@onready var _player: Player = $Player

func _ready() -> void:
    var px := WORLD_W * GameConfig.TILE_SIZE
    var py := WORLD_H * GameConfig.TILE_SIZE
    var ground := Sprite2D.new()
    ground.texture = load("res://assets/sprites/tiles/ground.svg")
    ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    ground.region_enabled = true
    ground.region_rect = Rect2(0, 0, px, py)
    ground.centered = false
    ground.z_index = -10
    add_child(ground)
    move_child(ground, 0)
    for wall in [Rect2(-64, -64, px + 128, 64), Rect2(-64, py, px + 128, 64), Rect2(-64, 0, 64, py), Rect2(px, 0, 64, py)]:
        var body := StaticBody2D.new()
        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = wall.size
        shape.shape = rect
        shape.position = wall.position + wall.size / 2.0
        body.add_child(shape)
        add_child(body)
    _player.position = Vector2(px, py) / 2.0
    var cam: Camera2D = _player.get_node("Camera2D")
    cam.limit_left = 0; cam.limit_top = 0; cam.limit_right = px; cam.limit_bottom = py
```

- [x] **Step 5: Debug-Overlay**

```gdscript
extends CanvasLayer
@onready var _label: Label = $Label
var _item_count := 0

func _ready() -> void:
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("debug_overlay"):
        visible = not visible

func _process(_delta: float) -> void:
    if not visible:
        return
    _label.text = "FPS %d\nTick %.2f ms\nTicks %d\nItems %d\n%s" % [
        Engine.get_frames_per_second(), SimClock.last_tick_ms, SimClock.world.tick_count, _item_count,
        "Gamepad" if InputRouter.is_gamepad else "Tastatur"]
```

- [x] **Step 6: Editor-Import headless** `--headless --import`, dann Spiel kurz headless starten (`--headless --quit-after 60`) → keine Fehler im Log. Commit `ms0: Rusty bewegt sich, Kamera, Debug-Overlay`

---

### Task 5: Export-Preset und Windows-Build

**Files:**
- Create: `export_presets.cfg`, `build.ps1`
- Modify: `README.md` (Build-Anleitung), `CHANGELOG.md`, `TODO.md`

- [x] **Step 1: Export-Templates 4.7.2 holen** (falls nicht unter `%APPDATA%/Godot/export_templates/4.7.2.stable/`): Download `Godot_v4.7.2-stable_export_templates.tpz` von github.com/godotengine/godot/releases, entpacken nach dort.
- [x] **Step 2: export_presets.cfg** für „Windows Desktop“, Pfad `export/windows/ScrapEmpire.exe`, embed_pck=true.
- [x] **Step 3: build.ps1** ruft `--headless --export-release "Windows Desktop" export/windows/ScrapEmpire.exe`.
- [x] **Step 4: Build läuft, EXE existiert.** CHANGELOG/TODO aktualisieren, Commit `ms0: Export-Preset und Build-Skript`.

---

## Self-Review

- Spec-Abdeckung MS0 (Roadmap): project.godot ✔ T1, Ordnerstruktur ✔ T1, Autoloads ✔ T3, Input-Map ✔ T3, Theme ✔ T4, Rusty+Kamera ✔ T4, Debug-Overlay ✔ T4, Test-Runner ✔ T2, Git ✔ T1, Export ✔ T5.
- Abweichung von Architektur-Doc: Input-Map wird zur Laufzeit registriert statt in project.godot. Wird in 02_ARCHITECTURE.md 4.9 nachgetragen.
- Typen: `SimWorld`, `TickAccumulator`, `InputMapSetup`, `Player` konsistent zwischen Tasks.
