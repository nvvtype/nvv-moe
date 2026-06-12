class_name InputHistoryDisplay
extends Label

## Training-mode input display: shows the recent input history of an
## [InputBuffer] as direction arrows + buttons, with frame counts, newest
## entry on top — like the input viewer in any modern fighter.
##
## It's a plain Label; style it with theme overrides (monospace font
## recommended).

@export var input_buffer: InputBuffer
@export var max_rows: int = 14
@export var show_frame_counts: bool = true

const _GLYPHS := {
	1: "↙", 2: "↓", 3: "↘",
	4: "←", 5: "·", 6: "→",
	7: "↖", 8: "↑", 9: "↗",
}

# Each row: [direction: int, pressed_mask: int, frames_held: int]
var _rows: Array = []


func _physics_process(_delta: float) -> void:
	if input_buffer == null:
		return
	if FightClock.active != null and FightClock.active.is_paused:
		return

	var dir := input_buffer.direction()
	var pressed := input_buffer.pressed_mask()

	if _rows.is_empty() or pressed != 0 or _rows[0][0] != dir:
		_rows.push_front([dir, pressed, 1])
		while _rows.size() > max_rows:
			_rows.pop_back()
	else:
		_rows[0][2] = mini(int(_rows[0][2]) + 1, 99)

	_render()


func _render() -> void:
	var lines := PackedStringArray()
	for row in _rows:
		var line := String(_GLYPHS.get(row[0], "?"))
		var mask := int(row[1])
		for i in input_buffer.buttons.size():
			if mask & (1 << i):
				line += " " + input_buffer.buttons[i].to_upper()
		if show_frame_counts:
			line = "%2d  %s" % [int(row[2]), line]
		lines.append(line)
	text = "\n".join(lines)


func clear_history() -> void:
	_rows.clear()
	text = ""
