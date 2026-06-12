class_name StatusComponent
extends Node

## Tracks [StatusEffect]s on one fighter: stacks, durations, periodic ticks.
##
## Add as a child of a [Fighter2D] and assign it to the fighter's
## [member Fighter2D.status] slot; hits with [member HitData.applies_status]
## then land their statuses automatically. This is the building block for
## magnet marks, curse meters, poison, install-enabling debuffs — the engine
## tracks the bookkeeping, your character logic reads it.

signal status_applied(effect: StatusEffect, stacks: int)
signal status_stacked(effect: StatusEffect, stacks: int)
## Emitted when full stacks are reached (curse-style "meter full" trigger).
signal status_maxed(effect: StatusEffect)
signal status_removed(effect: StatusEffect)
signal status_tick(effect: StatusEffect)

## Auto-detected from the parent when unset; used for tick damage.
@export var fighter: Fighter2D

# id -> {effect, stacks, frames_left, tick_accum}
var _active: Dictionary = {}


func _ready() -> void:
	if fighter == null:
		fighter = get_parent() as Fighter2D


func _physics_process(_delta: float) -> void:
	if _active.is_empty():
		return
	if FightClock.active != null \
			and (fighter != null and FightClock.active.is_frozen(fighter)
				or FightClock.active.is_paused):
		return

	for id in _active.keys():
		var entry: Dictionary = _active[id]
		var effect: StatusEffect = entry["effect"]

		if effect.tick_interval > 0:
			entry["tick_accum"] = int(entry["tick_accum"]) + 1
			if int(entry["tick_accum"]) >= effect.tick_interval:
				entry["tick_accum"] = 0
				_tick(effect)

		if effect.duration_frames > 0:
			entry["frames_left"] = int(entry["frames_left"]) - 1
			if int(entry["frames_left"]) <= 0:
				if effect.decay_per_stack and int(entry["stacks"]) > 1:
					entry["stacks"] = int(entry["stacks"]) - 1
					entry["frames_left"] = effect.duration_frames
					status_stacked.emit(effect, int(entry["stacks"]))
				else:
					remove_status(id)


func _tick(effect: StatusEffect) -> void:
	if effect.tick_damage > 0 and fighter != null and fighter.health != null:
		var hp := fighter.health
		var amount := mini(effect.tick_damage, maxi(hp.current - 1, 0))
		if amount > 0:
			var dot := HitData.new()
			dot.damage = amount
			hp.take_hit(dot)
	status_tick.emit(effect)


func apply(effect: StatusEffect, stacks: int = 1) -> void:
	if effect == null or stacks <= 0:
		return
	if _active.has(effect.id):
		var entry: Dictionary = _active[effect.id]
		var old_stacks := int(entry["stacks"])
		entry["stacks"] = mini(old_stacks + stacks, effect.max_stacks)
		if effect.refresh_on_apply:
			entry["frames_left"] = effect.duration_frames
		if int(entry["stacks"]) != old_stacks:
			status_stacked.emit(effect, int(entry["stacks"]))
			if int(entry["stacks"]) >= effect.max_stacks:
				status_maxed.emit(effect)
	else:
		var clamped := mini(stacks, effect.max_stacks)
		_active[effect.id] = {
			"effect": effect,
			"stacks": clamped,
			"frames_left": effect.duration_frames,
			"tick_accum": 0,
		}
		status_applied.emit(effect, clamped)
		if clamped >= effect.max_stacks:
			status_maxed.emit(effect)


func remove_status(id: StringName) -> void:
	if not _active.has(id):
		return
	var effect: StatusEffect = _active[id]["effect"]
	_active.erase(id)
	status_removed.emit(effect)


func clear() -> void:
	for id in _active.keys():
		remove_status(id)


func has_status(id: StringName) -> bool:
	return _active.has(id)


func stacks(id: StringName) -> int:
	return int(_active[id]["stacks"]) if _active.has(id) else 0


func frames_left(id: StringName) -> int:
	return int(_active[id]["frames_left"]) if _active.has(id) else 0


## Active StatusEffect resources, for UI indicator rows.
func active_effects() -> Array[StatusEffect]:
	var result: Array[StatusEffect] = []
	for id in _active:
		result.append(_active[id]["effect"])
	return result


## Rollback / save-state support.
func save_state() -> Dictionary:
	var snap := {}
	for id in _active:
		var entry: Dictionary = _active[id]
		snap[id] = {
			"effect": entry["effect"],
			"stacks": entry["stacks"],
			"frames_left": entry["frames_left"],
			"tick_accum": entry["tick_accum"],
		}
	return {"active": snap}


func load_state(state: Dictionary) -> void:
	_active = {}
	var snap: Dictionary = state["active"]
	for id in snap:
		_active[id] = (snap[id] as Dictionary).duplicate()
