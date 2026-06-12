class_name ComboTracker
extends Node

## Victim-side combo state: hit count, damage scaling, and the juggle point
## pool (IKEMEN-style: the victim owns a pool, each air hit spends points,
## and when the pool runs dry further hits are juggle-protected).
##
## [Fighter2D] drives this automatically; UI listens to the signals for
## combo counters and damage displays.

signal combo_started(attacker: Node)
signal combo_extended(hits: int, total_damage: int)
signal combo_dropped(hits: int, total_damage: int)

## Damage multiplier per combo hit (index 0 = first hit). Hits past the end
## of the array use [member min_scaling].
@export var scaling_table: PackedFloat32Array = PackedFloat32Array(
	[1.0, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.25]
)
@export var min_scaling: float = 0.2
## Juggle points available per combo. Air hits spend HitData.juggle_cost.
@export var juggle_pool: int = 15
## Ground bounces allowed per combo (anime standard: 1).
@export var max_ground_bounces: int = 1
## Wall bounces allowed per combo (anime standard: 1).
@export var max_wall_bounces: int = 1

@export_group("Kusoge dials")
## Turn off to make every hit deal full damage, no matter the combo length.
@export var enable_damage_scaling: bool = true
## Turn off to allow unlimited juggling.
@export var enable_juggle_limit: bool = false
## Hard cap on combo length; hits beyond it are juggle-protected.
## 0 = unlimited. Leave at 0 if you want your infinites.
@export var max_combo_hits: int = 0
## Turn off to allow unlimited ground and wall bounces per combo.
## Wall bounce loops forever. Welcome to the kusoge zone.
@export var enable_bounce_limits: bool = true

var hits: int = 0
var total_damage: int = 0
var juggle_points: int = 0
var ground_bounces_used: int = 0
var wall_bounces_used: int = 0
var attacker: Node = null
var active: bool = false


## Damage multiplier for the NEXT hit of the current combo.
func damage_multiplier() -> float:
	if not enable_damage_scaling or not active:
		return 1.0
	if hits < scaling_table.size():
		return maxf(scaling_table[hits], min_scaling)
	return min_scaling


## Whether another hit may connect (combo cap). Checked by Fighter2D.
func can_extend() -> bool:
	if not active or max_combo_hits <= 0:
		return true
	return hits < max_combo_hits


## Spends juggle points for an air hit. Returns false if the victim is
## juggle-protected and the hit should whiff.
func try_spend_juggle(cost: int) -> bool:
	if not enable_juggle_limit:
		return true
	if not active:
		return true
	if juggle_points < cost:
		return false
	juggle_points -= cost
	return true


## Spends a ground bounce from the combo budget. Returns false if exhausted.
func try_use_ground_bounce() -> bool:
	if not enable_bounce_limits:
		return true
	if active and ground_bounces_used >= max_ground_bounces:
		return false
	ground_bounces_used += 1
	return true


## Spends a wall bounce from the combo budget. Returns false if exhausted.
func try_use_wall_bounce() -> bool:
	if not enable_bounce_limits:
		return true
	if active and wall_bounces_used >= max_wall_bounces:
		return false
	wall_bounces_used += 1
	return true


## Called by Fighter2D when a clean hit connects on this fighter.
func register_hit(from_attacker: Node, damage_dealt: int) -> void:
	if not active:
		active = true
		hits = 0
		total_damage = 0
		juggle_points = juggle_pool
		ground_bounces_used = 0
		wall_bounces_used = 0
		attacker = from_attacker
		combo_started.emit(attacker)
	hits += 1
	total_damage += damage_dealt
	combo_extended.emit(hits, total_damage)


## Called by Fighter2D when hitstun ends or the fighter recovers.
func drop() -> void:
	if not active:
		return
	active = false
	combo_dropped.emit(hits, total_damage)
	attacker = null


func reset() -> void:
	active = false
	hits = 0
	total_damage = 0
	juggle_points = juggle_pool
	ground_bounces_used = 0
	wall_bounces_used = 0
	attacker = null


## Rollback / save-state support.
func save_state() -> Dictionary:
	return {
		"hits": hits, "total_damage": total_damage,
		"juggle_points": juggle_points, "active": active,
		"ground_bounces_used": ground_bounces_used,
		"wall_bounces_used": wall_bounces_used,
	}


func load_state(state: Dictionary) -> void:
	hits = state["hits"]
	total_damage = state["total_damage"]
	juggle_points = state["juggle_points"]
	active = state["active"]
	ground_bounces_used = state["ground_bounces_used"]
	wall_bounces_used = state["wall_bounces_used"]
