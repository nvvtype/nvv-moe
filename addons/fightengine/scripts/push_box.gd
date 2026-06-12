@tool
class_name PushBox2D
extends CollisionBox2D

## Body-to-body push volume (the classic fighting game "you can't walk through
## your opponent" box).
##
## Each physics frame, overlapping PushBox2D pairs push their combatants apart
## horizontally so fighters never stack. Cross-ups still work: jumping over an
## opponent only overlaps briefly and gets resolved to whichever side you land.

## Per-frame cap on how far a single push can move each fighter, in pixels.
@export var max_push_per_frame: float = 6.0
## 0.5 = both fighters share the push evenly. 1.0 = only the other fighter
## moves (useful for super-armored or grounded-boss characters).
@export_range(0.0, 1.0) var push_weight: float = 0.5


func _ready() -> void:
	super._ready()
	collision_shape.debug_color = Color(1, 1, 0, 0.5)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_active:
		return
	for area in get_overlapping_areas():
		if area is PushBox2D:
			var other = area as PushBox2D
			if other.is_active and get_instance_id() < other.get_instance_id():
				_resolve(other)


func _push_target() -> Node2D:
	if combatant is Node2D:
		return combatant
	return get_parent() as Node2D


func _resolve(other: PushBox2D) -> void:
	var a := _push_target()
	var b := other._push_target()
	if a == null or b == null or a == b:
		return

	var half_a := get_box_rect().size.x * 0.5 * absf(global_scale.x)
	var half_b := other.get_box_rect().size.x * 0.5 * absf(other.global_scale.x)
	var dx := other.global_position.x - global_position.x
	var overlap := (half_a + half_b) - absf(dx)
	if overlap <= 0.0:
		return

	var dir := 1.0 if dx >= 0.0 else -1.0
	var push_a := minf(overlap * (1.0 - push_weight), max_push_per_frame)
	var push_b := minf(overlap * push_weight, max_push_per_frame)
	a.global_position.x -= push_a * dir
	b.global_position.x += push_b * dir
