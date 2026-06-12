class_name FightCamera2D
extends Camera2D

## Two-fighter framing camera with IKEMEN-style stage zoom and screen shake.
##
## Keeps every target on screen, zooming out as they separate and back in as
## they close, clamped by the Camera2D limit_* properties (set those to your
## stage bounds). Hit effects request shake through [method shake], which
## [Fighter2D] does automatically for hits with shake values.

static var active: FightCamera2D

@export var targets: Array[Node2D] = []
## Closest allowed zoom (1 = native). Bigger numbers = more zoomed in.
@export var max_zoom: float = 1.0
## Farthest allowed zoom out.
@export var min_zoom: float = 0.7
## Extra horizontal space kept around the fighters, in pixels.
@export var margin: float = 120.0
## 0..1 smoothing per frame; 1 = instant.
@export_range(0.01, 1.0) var follow_speed: float = 0.15
## Vertical bias: 0 = center on fighters, negative = aim above them.
@export var vertical_offset: float = -40.0

var _shake_frames: int = 0
var _shake_intensity: float = 0.0


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


func shake(intensity: float, frames: int) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_frames = maxi(_shake_frames, frames)


func _physics_process(_delta: float) -> void:
	var valid: Array[Node2D] = []
	for target in targets:
		if is_instance_valid(target):
			valid.append(target)
	if valid.is_empty():
		return

	var bounds := Rect2(valid[0].global_position, Vector2.ZERO)
	for target in valid:
		bounds = bounds.expand(target.global_position)

	var center := bounds.get_center() + Vector2(0, vertical_offset)
	global_position = global_position.lerp(center, follow_speed)

	var viewport_width := get_viewport_rect().size.x
	if viewport_width > 0.0:
		var needed := (bounds.size.x + margin * 2.0) / viewport_width
		var target_zoom := clampf(1.0 / maxf(needed, 0.001), min_zoom, max_zoom)
		var smoothed := lerpf(zoom.x, target_zoom, follow_speed)
		zoom = Vector2(smoothed, smoothed)

	if _shake_frames > 0:
		_shake_frames -= 1
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		if _shake_frames == 0:
			_shake_intensity = 0.0
			offset = Vector2.ZERO
