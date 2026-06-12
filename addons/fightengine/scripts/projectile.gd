class_name Projectile2D
extends Node2D

## A fireball / projectile with travel, lifetime, hit limits, and
## IKEMEN-style projectile clashing (higher HitData.priority wins; equal
## priorities destroy each other).
##
## Give it a HitBox2D child (assigned to [member hitbox] or auto-detected)
## and call [method launch] from the owning fighter.

signal expired
signal clashed(other: Projectile2D)

@export var hitbox: HitBox2D
## Facing-relative velocity in px/s; +X travels forward.
@export var speed: Vector2 = Vector2(400, 0)
## Lifetime in logical frames. 0 = until it leaves the screen or hits.
@export var lifetime_frames: int = 180
## Hurtboxes this projectile can hit before despawning.
@export var max_hits: int = 1
@export var destroy_on_clash: bool = true

var owner_fighter: Fighter2D = null
var _direction: float = 1.0
var _frames_left: int = 0
var _hits_left: int = 0


func _ready() -> void:
	if hitbox == null:
		for child in get_children():
			if child is HitBox2D:
				hitbox = child
				break
	_frames_left = lifetime_frames
	_hits_left = max_hits
	if hitbox != null:
		hitbox.hit.connect(_on_hit)
		hitbox.collision.connect(_on_box_collision)
		if hitbox.hit_data != null:
			hitbox.hit_data = hitbox.hit_data.duplicate()
			hitbox.hit_data.hit_class = HitData.HitClass.PROJECTILE


## Configures ownership and direction. Call right after instantiating.
func launch(from: Fighter2D) -> void:
	owner_fighter = from
	_direction = from.facing_sign()
	if _direction < 0.0:
		scale.x = -absf(scale.x)
	if hitbox != null:
		hitbox.combatant = from
		hitbox.team = from.team


func _physics_process(delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_frozen(self):
		return

	position += Vector2(speed.x * _direction, speed.y) * delta

	if lifetime_frames > 0:
		_frames_left -= 1
		if _frames_left <= 0:
			_expire()


func _on_hit(_hurtbox: HurtBox2D) -> void:
	_hits_left -= 1
	if _hits_left <= 0:
		_expire()


func _on_box_collision(collider: CollisionBox2D) -> void:
	# Projectile vs projectile clash.
	if collider is not HitBox2D:
		return
	var other := (collider as HitBox2D).get_parent()
	if other is not Projectile2D or other == self:
		return
	var other_projectile := other as Projectile2D

	var mine := hitbox.effective_hit_data().priority if hitbox != null else 0
	var theirs := other_projectile.hitbox.effective_hit_data().priority \
			if other_projectile.hitbox != null else 0
	if mine > theirs:
		return  # We win; the other projectile handles its own demise.
	clashed.emit(other_projectile)
	if destroy_on_clash:
		_expire()


func _expire() -> void:
	expired.emit()
	queue_free()
