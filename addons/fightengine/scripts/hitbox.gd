@tool
class_name HitBox2D
extends CollisionBox2D

## An attacking collision volume.
##
## Emits [signal hit] when it touches an active [HurtBox2D] belonging to
## another combatant. All hit validation (self-hit, teams, invulnerability,
## re-hit limiting) happens here, after which the hurtbox is notified, so each
## contact is reported exactly once and from a single place.

signal hit(hurtbox: HurtBox2D)

## Full description of the hit. If unset, the legacy [member damage] and
## [member stun] values are wrapped into a HitData automatically.
@export var hit_data: HitData

## Legacy simple values, used only when [member hit_data] is not assigned.
@export var damage: int = 0
@export var stun: int = 0

@export var can_hit_teammates: bool = false
## Frames before the same hurtbox can be hit again while this box stays
## active. 0 = each hurtbox can only be hit once per activation (use for
## single hits; set > 0 for multi-hit moves like rapid jabs or beams).
@export var rehit_interval: int = 0

var _victims: Dictionary = {}


func _init() -> void:
	super._init()
	collision.connect(_on_collision)


func _ready() -> void:
	super._ready()
	collision_shape.debug_color = Color(1, 0, 0, 0.8)


func _on_activated() -> void:
	_victims.clear()


## Returns the HitData driving this box, building one from the legacy
## damage/stun exports if none is assigned.
func effective_hit_data() -> HitData:
	if hit_data != null:
		return hit_data
	var data := HitData.new()
	data.damage = damage
	data.hitstun = stun
	return data


func _on_collision(collider: CollisionBox2D) -> void:
	if collider is not HurtBox2D:
		return

	var box = collider as HurtBox2D

	if combatant != null and box.combatant == combatant:
		return
	if not can_hit_teammates and team >= 0 and box.team == team:
		return
	if not box.can_be_hit_by(effective_hit_data()):
		return

	var now := Engine.get_physics_frames()
	if _victims.has(box):
		if rehit_interval <= 0:
			return
		if now - int(_victims[box]) < rehit_interval:
			return
	_victims[box] = now

	box.notify_hit(self)
	hit.emit(box)
