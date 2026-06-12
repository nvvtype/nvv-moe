class_name InputBuffer
extends Node

## Frame-accurate input history for one player.
##
## Samples the Godot input map once per physics frame into a ring buffer of
## numpad-notation directions and button bitmasks. Directions are stored
## relative to facing: 6 is always "toward the opponent", so motions read the
## same on both sides.
##
## Expected input actions (with the configured prefix, e.g. "p1_"):
## p1_up, p1_down, p1_left, p1_right, plus one action per entry in
## [member buttons] (e.g. p1_a, p1_b, p1_c).

enum SOCDMode {
	NEUTRAL,        ## Left+Right = 5, Up+Down = 5 (tournament standard).
	LAST_WINS,      ## The most recently pressed direction wins.
	BACK_PRIORITY,  ## Left+Right resolves to back, Up+Down to up (charge-friendly).
	RAW,            ## No cleaning: Left+Right = back+forward = 5 anyway, Up+Down = up. Kusoge dial.
}

const BUFFER_SIZE := 120

@export var action_prefix: String = "p1_"
## Button names, in bit order. Button i maps to bit (1 << i).
@export var buttons: PackedStringArray = PackedStringArray(["a", "b", "c"])
## Macro actions: extra InputMap actions that press several buttons at once.
## E.g. {"throw": ["l", "m"]} makes the action "p1_throw" press L+M together
## — throw macro, burst macro, alpha counter macro, whatever.
@export var macros: Dictionary = {}
@export var socd_mode: SOCDMode = SOCDMode.NEUTRAL
## Mirrors left/right into back/forward. Drive this from Fighter2D.facing_right.
var facing_right: bool = true

## Optional playback source (see InputRecorder). While set, device input is
## ignored and frames come from the recorder instead.
var playback: Node = null

var _dirs := PackedInt32Array()
var _held := PackedInt32Array()
var _pressed := PackedInt32Array()
var _released := PackedInt32Array()
var _head: int = -1
var _count: int = 0
var _last_press_frame := {"left": -1, "right": -1, "up": -1, "down": -1}
var _frame_index: int = 0


func _init() -> void:
	process_physics_priority = -900
	_dirs.resize(BUFFER_SIZE)
	_held.resize(BUFFER_SIZE)
	_pressed.resize(BUFFER_SIZE)
	_released.resize(BUFFER_SIZE)


func _physics_process(_delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_paused:
		return
	sample()


## Samples the current device (or playback) state into the buffer.
func sample() -> void:
	_frame_index += 1
	var direction: int
	var held: int

	if playback != null and playback.has_method("next_playback_frame"):
		var frame_data: Vector2i = playback.next_playback_frame()
		direction = frame_data.x
		held = frame_data.y
	else:
		direction = _read_direction()
		held = _read_buttons()

	var prev_held := 0
	if _count > 0:
		prev_held = _held[_head]

	_head = (_head + 1) % BUFFER_SIZE
	_count = mini(_count + 1, BUFFER_SIZE)
	_dirs[_head] = direction
	_held[_head] = held
	_pressed[_head] = held & ~prev_held
	_released[_head] = prev_held & ~held


func _read_direction() -> int:
	for dir_name in ["left", "right", "up", "down"]:
		if Input.is_action_just_pressed(action_prefix + dir_name):
			_last_press_frame[dir_name] = _frame_index

	var left := Input.is_action_pressed(action_prefix + "left")
	var right := Input.is_action_pressed(action_prefix + "right")
	var up := Input.is_action_pressed(action_prefix + "up")
	var down := Input.is_action_pressed(action_prefix + "down")

	var x := 0
	var y := 0
	if left and right:
		match socd_mode:
			SOCDMode.NEUTRAL, SOCDMode.RAW:
				x = 0
			SOCDMode.LAST_WINS:
				x = 1 if _last_press_frame["right"] >= _last_press_frame["left"] else -1
			SOCDMode.BACK_PRIORITY:
				x = -1 if facing_right else 1
	elif left:
		x = -1
	elif right:
		x = 1

	if up and down:
		match socd_mode:
			SOCDMode.NEUTRAL:
				y = 0
			SOCDMode.LAST_WINS:
				y = 1 if _last_press_frame["up"] >= _last_press_frame["down"] else -1
			SOCDMode.BACK_PRIORITY, SOCDMode.RAW:
				y = 1
	elif up:
		y = 1
	elif down:
		y = -1

	if not facing_right:
		x = -x
	# Numpad notation, facing-relative: 6 = toward opponent.
	return 5 + x + y * 3


func _read_buttons() -> int:
	var mask := 0
	for i in buttons.size():
		if Input.is_action_pressed(action_prefix + buttons[i]):
			mask |= 1 << i
	for macro_name in macros:
		if Input.is_action_pressed(action_prefix + macro_name):
			for button in macros[macro_name]:
				mask |= button_bit(button)
	return mask


## How many frames of history are available.
func count() -> int:
	return _count


func _at(frames_ago: int) -> int:
	return (_head - frames_ago + BUFFER_SIZE * 2) % BUFFER_SIZE


## Facing-relative numpad direction, [param frames_ago] frames in the past.
func direction(frames_ago: int = 0) -> int:
	if _count == 0 or frames_ago >= _count:
		return 5
	return _dirs[_at(frames_ago)]


func held_mask(frames_ago: int = 0) -> int:
	if _count == 0 or frames_ago >= _count:
		return 0
	return _held[_at(frames_ago)]


func pressed_mask(frames_ago: int = 0) -> int:
	if _count == 0 or frames_ago >= _count:
		return 0
	return _pressed[_at(frames_ago)]


func released_mask(frames_ago: int = 0) -> int:
	if _count == 0 or frames_ago >= _count:
		return 0
	return _released[_at(frames_ago)]


func button_bit(button: String) -> int:
	var idx := buttons.find(button)
	return 0 if idx < 0 else (1 << idx)


func is_held(button: String) -> bool:
	return (held_mask() & button_bit(button)) != 0


## True if [param button] was pressed within the last [param window] frames.
func was_pressed(button: String, window: int = 1) -> bool:
	var bit := button_bit(button)
	for i in mini(window, _count):
		if (_pressed[_at(i)] & bit) != 0:
			return true
	return false


func was_released(button: String, window: int = 1) -> bool:
	var bit := button_bit(button)
	for i in mini(window, _count):
		if (_released[_at(i)] & bit) != 0:
			return true
	return false


## Rollback / save-state support. Packed arrays are copy-on-write, so this
## is cheap until the buffer is written to again.
func save_state() -> Dictionary:
	return {
		"dirs": _dirs.duplicate(), "held": _held.duplicate(),
		"pressed": _pressed.duplicate(), "released": _released.duplicate(),
		"head": _head, "count": _count, "frame_index": _frame_index,
		"facing_right": facing_right,
		"last_press": _last_press_frame.duplicate(),
	}


func load_state(state: Dictionary) -> void:
	_dirs = state["dirs"]
	_held = state["held"]
	_pressed = state["pressed"]
	_released = state["released"]
	_head = state["head"]
	_count = state["count"]
	_frame_index = state["frame_index"]
	facing_right = state["facing_right"]
	_last_press_frame = state["last_press"]


## Number of consecutive past frames (starting [param from_frames_ago] ago)
## whose direction satisfies [param dirs]. Used for charge detection.
func consecutive_direction_frames(dirs: PackedInt32Array, from_frames_ago: int = 0) -> int:
	var run := 0
	var i := from_frames_ago
	while i < _count:
		if not dirs.has(_dirs[_at(i)]):
			break
		run += 1
		i += 1
	return run
