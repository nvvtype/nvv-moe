class_name StatusEffect
extends Resource

## A status effect definition: magnetism, curse/infestation build-up, poison,
## marks — any timed/stacked state applied to a fighter.
##
## Apply via [member HitData.applies_status] (hits apply it automatically) or
## [method StatusComponent.apply] from your move logic. The engine tracks
## duration, stacks, and ticks; what the status MEANS is yours — query
## [method StatusComponent.has_status] in move conditions, listen to the
## signals for state changes (e.g. full curse stacks = mode change).

@export var id: StringName
@export var display_name: String = ""
## Icon for UI status indicators.
@export var icon: Texture2D

## Frames until the status expires. 0 = permanent until removed.
@export var duration_frames: int = 300
## Re-applying refreshes the remaining duration.
@export var refresh_on_apply: bool = true
@export var max_stacks: int = 1
## Expiry removes one stack at a time (and restarts the timer) instead of
## clearing the whole status.
@export var decay_per_stack: bool = false

@export_group("Periodic tick")
## Emit status_tick (and apply tick_damage) every N frames. 0 = no ticks.
@export var tick_interval: int = 0
## Damage per tick (poison). Never KOs: leaves the victim at 1 HP.
@export var tick_damage: int = 0
