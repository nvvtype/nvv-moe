class_name MotionInput
extends Resource

## A directional command in numpad notation, checked against an [InputBuffer].
##
## Examples (all facing-relative, 6 = toward opponent):
## [codeblock]
## QCF (fireball):        sequence = [2, 3, 6]
## QCB:                   sequence = [2, 1, 4]
## DP (dragon punch):     sequence = [6, 2, 3]
## HCF:                   sequence = [4, 1, 2, 3, 6]
## Double QCF (super):    sequence = [2, 3, 6, 2, 3, 6], max_duration = 24
## Charge back-forward:   sequence = [4, 6], charge_frames = 40
## Charge down-up:        sequence = [2, 8], charge_frames = 40
## 360:                   sequence = [6, 2, 4, 8], strict = false, max_duration = 24
## Double tap forward:    sequence = [6, 5, 6] (dash)
## [/codeblock]
##
## With [member strict] off (the default), cardinal steps accept their
## neighbouring diagonals (a 6 step is satisfied by 3, 6 or 9 — so down-back
## charge and sloppy fireballs work like in real fighters), and diagonal steps
## in the sequence may be skipped entirely (2,6 counts as a QCF).

@export var sequence: Array[int] = []
## Total frames allowed between the first and last step of the sequence.
@export var max_duration: int = 12
## If > 0, the first step must have been held for at least this many frames
## (charge moves). The remaining steps then follow within max_duration.
@export var charge_frames: int = 0
## Strict = exact directions only, no diagonal skipping. Leave off for
## tournament-style leniency; turn on for deliberately evil kusoge inputs.
@export var strict: bool = false

const _DIAGONALS: Array[int] = [1, 3, 7, 9]


func _dir_matches(step: int, dir: int) -> bool:
	if dir == step:
		return true
	if strict:
		return false
	match step:
		2: return dir == 1 or dir == 3
		8: return dir == 7 or dir == 9
		4: return dir == 1 or dir == 7
		6: return dir == 3 or dir == 9
	return false


## True if the motion was completed, ending within [param end_frames_ago]
## frames of now. Call this on the frame a button is pressed.
func matches(buffer: InputBuffer, end_frames_ago: int = 0) -> bool:
	if sequence.is_empty():
		return true
	if buffer == null:
		return false

	var idx := sequence.size() - 1
	var frames_ago := end_frames_ago
	var deadline := end_frames_ago + max_duration

	while frames_ago <= deadline and frames_ago < buffer.count():
		var dir := buffer.direction(frames_ago)
		if _dir_matches(sequence[idx], dir):
			if idx == 0:
				return _charge_satisfied(buffer, frames_ago)
			idx -= 1
		elif not strict and idx > 0 and sequence[idx] in _DIAGONALS \
				and _dir_matches(sequence[idx - 1], dir):
			# Skipped diagonal: this frame already satisfies the next step.
			if idx - 1 == 0:
				return _charge_satisfied(buffer, frames_ago)
			idx -= 2
		frames_ago += 1
	return false


func _charge_satisfied(buffer: InputBuffer, first_step_frames_ago: int) -> bool:
	if charge_frames <= 0:
		return true
	var accepted := PackedInt32Array()
	for dir in range(1, 10):
		if _dir_matches(sequence[0], dir):
			accepted.append(dir)
	return buffer.consecutive_direction_frames(accepted, first_step_frames_ago) >= charge_frames
