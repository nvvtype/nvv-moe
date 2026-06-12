class_name InputRecorder
extends Node

## Records and replays InputBuffer streams, frame by frame.
##
## This powers training-mode dummy recording and is the foundation for match
## replays (record both players' buffers and play them back into a fresh
## match). Assign [member input_buffer], call [method start_recording] /
## [method stop_recording], then [method play] to feed the recording back
## through the same buffer.

signal recording_started
signal recording_stopped(frames: int)
signal playback_started
signal playback_finished

enum Mode { IDLE, RECORDING, PLAYING }

@export var input_buffer: InputBuffer
@export var loop_playback: bool = false

var mode: Mode = Mode.IDLE
## Recorded frames: x = numpad direction, y = held button mask.
var frames: Array[Vector2i] = []

var _play_head: int = 0


func _init() -> void:
	# After the buffer samples each frame.
	process_physics_priority = -850


func _physics_process(_delta: float) -> void:
	if mode != Mode.RECORDING or input_buffer == null:
		return
	if FightClock.active != null and FightClock.active.is_paused:
		return
	frames.append(Vector2i(input_buffer.direction(), input_buffer.held_mask()))


func start_recording() -> void:
	stop()
	frames.clear()
	mode = Mode.RECORDING
	recording_started.emit()


func stop_recording() -> void:
	if mode == Mode.RECORDING:
		mode = Mode.IDLE
		recording_stopped.emit(frames.size())


func play() -> void:
	if frames.is_empty() or input_buffer == null:
		return
	stop()
	_play_head = 0
	mode = Mode.PLAYING
	input_buffer.playback = self
	playback_started.emit()


## Stops recording or playback and releases the buffer.
func stop() -> void:
	stop_recording()
	if mode == Mode.PLAYING:
		mode = Mode.IDLE
		if input_buffer != null and input_buffer.playback == self:
			input_buffer.playback = null
		playback_finished.emit()


## Called by InputBuffer once per frame while this recorder is its playback
## source. Returns (direction, held mask).
func next_playback_frame() -> Vector2i:
	if mode != Mode.PLAYING or frames.is_empty():
		return Vector2i(5, 0)

	var frame := frames[_play_head]
	_play_head += 1
	if _play_head >= frames.size():
		if loop_playback:
			_play_head = 0
		else:
			# Release the buffer after this frame.
			mode = Mode.IDLE
			if input_buffer != null and input_buffer.playback == self:
				input_buffer.playback = null
			playback_finished.emit()
	return frame


## Serializes the recording for saving replays to disk.
func to_bytes() -> PackedByteArray:
	var ints := PackedInt32Array()
	for frame in frames:
		ints.append(frame.x)
		ints.append(frame.y)
	return ints.to_byte_array()


func from_bytes(data: PackedByteArray) -> void:
	stop()
	frames.clear()
	var ints := data.to_int32_array()
	var i := 0
	while i + 1 < ints.size():
		frames.append(Vector2i(ints[i], ints[i + 1]))
		i += 2
