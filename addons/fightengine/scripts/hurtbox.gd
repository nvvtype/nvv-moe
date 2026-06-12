@tool
class_name HurtBox2D
extends CollisionBox2D

## A vulnerable collision volume.
##
## Hit validation is performed by the attacking [HitBox2D]; once a contact is
## accepted, the hitbox calls [method notify_hit] which re-emits the
## [signal was_hit] signal for this box's owner to react to.

signal was_hit(hitbox: HitBox2D)

## Hit classes this box ignores. Use for strike invulnerability during
## reversals, throw invulnerability during jumps, projectile-immune armor, etc.
@export_flags("Strike", "Throw", "Projectile") var invulnerability: int = 0


func _ready() -> void:
	super._ready()
	collision_shape.debug_color = Color(0, 1, 0, 0.8)


func can_be_hit_by(data: HitData) -> bool:
	return (invulnerability & data.hit_class_bit()) == 0


## Called by the attacking HitBox2D after a contact has been validated.
func notify_hit(hitbox: HitBox2D) -> void:
	was_hit.emit(hitbox)
