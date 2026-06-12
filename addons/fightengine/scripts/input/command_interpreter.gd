class_name CommandInterpreter
extends Node

## Watches an [InputBuffer] and emits [signal move_detected] when the player
## completes the command of any [MoveData] in the movelist.
##
## Detection runs once per physics frame, after the buffer samples. Moves are
## checked in priority order (see [method MoveData.detection_priority]) and at
## most one move is reported per frame; your state machine decides whether the
## fighter can actually perform it (situation, meter, cancel rules).

signal move_detected(move: MoveData)

@export var input_buffer: InputBuffer
## Optional context: when set, moves the fighter can't currently perform
## (followup-only rekkas in neutral, supers without meter, wrong situation,
## cancel rules) are skipped so the input falls through to the next match —
## a meterless 236236H still gives you the fireball. FighterStateMachine
## wires this automatically.
@export var fighter: Fighter2D
@export var moves: Array[MoveData] = []:
	set(value):
		moves = value
		_dirty = true
## Extra frames a button press stays usable, so commands buffered slightly
## early still come out (classic input buffer leniency).
@export var press_window: int = 3
## Master switch for negative edge; individual moves opt in via
## MoveData.negative_edge.
@export var allow_negative_edge: bool = true
@export var enabled: bool = true

var _sorted: Array[MoveData] = []
var _dirty: bool = true


func _init() -> void:
	# After InputBuffer (-900), before gameplay (0).
	process_physics_priority = -800


func set_movelist(new_moves: Array[MoveData]) -> void:
	moves = new_moves


func _refresh() -> void:
	_sorted = moves.duplicate()
	_sorted.sort_custom(
		func(a: MoveData, b: MoveData) -> bool:
			return a.detection_priority() > b.detection_priority()
	)
	_dirty = false


func _physics_process(_delta: float) -> void:
	if not enabled or input_buffer == null:
		return
	if FightClock.active != null and FightClock.active.is_paused:
		return
	if _dirty:
		_refresh()

	var move := detect()
	if move != null:
		move_detected.emit(move)


## Checks the whole movelist against the buffer right now. Returns the best
## match or null. Can also be called manually (e.g. re-checking on a cancel
## window instead of every frame).
func detect() -> MoveData:
	if _dirty:
		_refresh()
	for move in _sorted:
		var press_age := _trigger_frame(move)
		if press_age < 0:
			continue
		if move.motion != null and not move.motion.matches(input_buffer, press_age):
			continue
		if fighter != null and not fighter.can_cancel_into(move):
			continue
		return move
	return null


## Returns how many frames ago the move's button trigger happened (within the
## press window), or -1 if it didn't.
func _trigger_frame(move: MoveData) -> int:
	if move.buttons.is_empty():
		return 0

	var window := maxi(press_window, 1)
	for i in mini(window, input_buffer.count()):
		if _buttons_triggered(move, i):
			return i
	return -1


func _buttons_triggered(move: MoveData, frames_ago: int) -> bool:
	var pressed := input_buffer.pressed_mask(frames_ago)
	if allow_negative_edge and move.negative_edge:
		pressed |= input_buffer.released_mask(frames_ago)

	if move.require_all_buttons:
		var mask := 0
		for button in move.buttons:
			mask |= input_buffer.button_bit(button)
		if mask == 0:
			return false
		# All buttons held, with at least one of them newly pressed this frame.
		return (input_buffer.held_mask(frames_ago) & mask) == mask \
				and (pressed & mask) != 0

	for button in move.buttons:
		if (pressed & input_buffer.button_bit(button)) != 0:
			return true
	return false
