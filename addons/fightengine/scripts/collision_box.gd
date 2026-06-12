@tool
@abstract
class_name CollisionBox2D
extends Area2D

## Base class for all FightEngine collision volumes (hit, hurt, push boxes).
##
## Filters out collisions with anything that is not another CollisionBox2D,
## and only reports collisions while both boxes are active.

signal collision(collider: CollisionBox2D)

## The combatant (usually a [Fighter2D]) this box belongs to.
## Set automatically by [Fighter2D] for all descendant boxes.
var combatant: Node = null

## Team index used for friendly-fire filtering. -1 means "no team".
@export var team: int = -1

@export var is_active: bool = true:
	set(value):
		var was_inactive = not is_active
		is_active = value
		if was_inactive and is_active:
			_on_activated()
			_check_existing_overlaps()

@export var shape: Shape2D:
	set(value):
		shape = value
		_update_collision_shape()

@onready var collision_shape: CollisionShape2D = CollisionShape2D.new()


func _init() -> void:
	area_entered.connect(_on_area_entered)


func _ready() -> void:
	add_child(collision_shape)
	_update_collision_shape()


## Called when the box flips from inactive to active. Subclasses can use this
## to reset per-activation state (e.g. the list of already-hit victims).
func _on_activated() -> void:
	pass


func _update_collision_shape() -> void:
	if not is_instance_valid(collision_shape):
		return

	collision_shape.shape = shape


## Returns the box extents in local space, derived from the assigned shape.
func get_box_rect() -> Rect2:
	if shape == null:
		return Rect2()
	return shape.get_rect()


func _check_existing_overlaps() -> void:
	for area in get_overlapping_areas():
		if area is CollisionBox2D:
			var box = area as CollisionBox2D
			if box.is_active:
				collision.emit(box)


func _on_area_entered(area: Area2D) -> void:
	if area is not CollisionBox2D:
		return
	var box = area as CollisionBox2D
	if not box.is_active or not is_active:
		return
	collision.emit(box)
