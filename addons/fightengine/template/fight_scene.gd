class_name FightScene
extends Node2D

## Template fight scene: stage, two fighters, clock, rounds, camera, HUD.
## Works out of the box with placeholder box-men; assign
## [member fighter_scene] (+ per-side FighterData) once your character exists.
##
## Modes (set by the main menu via [member next_mode]):
## - versus:   best of 3, 99s timer, two local players
## - training: infinite time, health refill, pause/frame-step, dummy
##             record/playback, save states, input display
##
## Training / debug keys:
##   ESC menu · R reset positions · P pause · O frame step
##   F1 record dummy (P2) · F2 play once · F3 play looped
##   F5 save state · F8 load state

## Mode for the next instance of this scene.
static var next_mode: StringName = &"versus"

## Your character scene (root must be Fighter2D). Null = placeholder box-men.
@export var fighter_scene: PackedScene
@export var p1_data: FighterData
@export var p2_data: FighterData
@export var stage_half_width: float = 640.0
@export var floor_y: float = 360.0
@export var round_time: int = 99
@export var rounds_to_win: int = 2

var mode: StringName
var clock: FightClock
var round_manager: RoundManager
var camera: FightCamera2D
var p1: Fighter2D
var p2: Fighter2D
var hud: FightHud
var snapshotter: StateSnapshotter
var dummy_recorder: InputRecorder

var _refill_accum: int = 0


func _ready() -> void:
	mode = next_mode
	_ensure_default_controls()
	_build_stage()
	_build_fighters()
	_build_match()
	hud = FightHud.new()
	add_child(hud)
	hud.setup(p1, p2, round_manager, mode == &"training")
	round_manager.start_match()


# --- Construction ------------------------------------------------------------

func _build_stage() -> void:
	var sky := Polygon2D.new()
	sky.polygon = _rect_points(-stage_half_width - 600, -900,
			(stage_half_width + 600) * 2, 900 + floor_y + 200)
	sky.color = Color(0.13, 0.12, 0.18)
	sky.z_index = -10
	add_child(sky)

	var ground := Polygon2D.new()
	ground.polygon = _rect_points(-stage_half_width - 600, floor_y,
			(stage_half_width + 600) * 2, 200)
	ground.color = Color(0.22, 0.2, 0.26)
	ground.z_index = -9
	add_child(ground)

	var stage := StaticBody2D.new()
	stage.name = "Stage"
	add_child(stage)
	_add_static_box(stage, Vector2(0, floor_y + 50), Vector2((stage_half_width + 600) * 2, 100))
	_add_static_box(stage, Vector2(-stage_half_width - 50, floor_y - 1000), Vector2(100, 2400))
	_add_static_box(stage, Vector2(stage_half_width + 50, floor_y - 1000), Vector2(100, 2400))


func _add_static_box(body: StaticBody2D, at: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	body.add_child(shape)


func _rect_points(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
	])


func _build_fighters() -> void:
	p1 = _spawn_fighter("p1_", Color(0.36, 0.62, 0.94), p1_data)
	p2 = _spawn_fighter("p2_", Color(0.92, 0.42, 0.38), p2_data)
	_place_fighters()
	p1.opponent = p2
	p2.opponent = p1
	p2.facing_right = false


func _spawn_fighter(prefix: String, color: Color, data: FighterData) -> Fighter2D:
	var fighter: Fighter2D
	if fighter_scene != null:
		fighter = fighter_scene.instantiate() as Fighter2D
		if data != null:
			fighter.data = data
		if fighter.input_buffer != null:
			fighter.input_buffer.action_prefix = prefix
	else:
		fighter = PlaceholderFighter.create(prefix, color, data)
	add_child(fighter)
	return fighter


func _place_fighters() -> void:
	p1.global_position = Vector2(-180, floor_y)
	p2.global_position = Vector2(180, floor_y)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO


func _build_match() -> void:
	clock = FightClock.new()
	add_child(clock)

	round_manager = RoundManager.new()
	round_manager.fighters = [p1, p2]
	round_manager.rounds_to_win = rounds_to_win
	round_manager.round_time = 0 if mode == &"training" else round_time
	add_child(round_manager)
	round_manager.round_started.connect(func(_n: int) -> void: _place_fighters())

	camera = FightCamera2D.new()
	camera.targets = [p1, p2]
	camera.limit_left = int(-stage_half_width)
	camera.limit_right = int(stage_half_width)
	camera.limit_bottom = int(floor_y + 80)
	camera.limit_top = -800
	camera.position = Vector2(0, floor_y - 160)
	add_child(camera)
	camera.make_current()

	snapshotter = StateSnapshotter.new()
	snapshotter.root = self
	add_child(snapshotter)

	if mode == &"training" and p2.input_buffer != null:
		dummy_recorder = InputRecorder.new()
		dummy_recorder.input_buffer = p2.input_buffer
		add_child(dummy_recorder)


# --- Training upkeep -----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if mode != &"training":
		return
	# Refill health once both fighters have been out of any combo for a bit.
	if _out_of_action(p1) and _out_of_action(p2):
		_refill_accum += 1
		if _refill_accum >= 90:
			_refill_accum = 0
			for fighter in [p1, p2]:
				if fighter.health != null and not fighter.health.is_full() \
						and not fighter.health.is_dead:
					fighter.health.reset()
	else:
		_refill_accum = 0


func _out_of_action(fighter: Fighter2D) -> bool:
	return not fighter.in_stun() and not fighter.is_attacking() \
			and not (fighter.combo_tracker != null and fighter.combo_tracker.active)


# --- Debug keys ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			get_tree().change_scene_to_file(
					"res://addons/fightengine/template/main_menu.tscn")
		KEY_P:
			clock.is_paused = not clock.is_paused
		KEY_O:
			clock.step_frame()
		KEY_R:
			if mode == &"training":
				_place_fighters()
		KEY_F1:
			if dummy_recorder != null:
				if dummy_recorder.mode == InputRecorder.Mode.RECORDING:
					dummy_recorder.stop_recording()
				else:
					dummy_recorder.start_recording()
		KEY_F2:
			if dummy_recorder != null:
				dummy_recorder.loop_playback = false
				dummy_recorder.play()
		KEY_F3:
			if dummy_recorder != null:
				dummy_recorder.loop_playback = true
				dummy_recorder.play()
		KEY_F5:
			snapshotter.snapshot()
		KEY_F8:
			snapshotter.restore()


# --- Default controls ------------------------------------------------------------

## Registers keyboard controls at runtime if the project hasn't defined them:
## P1 = WASD + U/I/O/P, P2 = arrows + numpad 4/5/6/+.
static func _ensure_default_controls() -> void:
	var bindings := {
		"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A, "p1_right": KEY_D,
		"p1_l": KEY_U, "p1_m": KEY_I, "p1_h": KEY_O, "p1_s": KEY_P,
		"p2_up": KEY_UP, "p2_down": KEY_DOWN,
		"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT,
		"p2_l": KEY_KP_4, "p2_m": KEY_KP_5, "p2_h": KEY_KP_6, "p2_s": KEY_KP_ADD,
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
