class_name BarrierComponent
extends Node

## Barrier / Faultless Defense (BlazBlue Barrier, GGXX FD): an enhanced
## guard held with extra buttons that negates chip, pushes the attacker's
## pressure away, and lets you block normally-unblockable air situations —
## all paid for from its own draining gauge.
##
## Add as a child of a [Fighter2D] and assign it to the fighter's
## [member Fighter2D.barrier] slot. The fighter drives it: while the barrier
## buttons are held and the gauge has charge, blocks become barrier blocks.
##
## When the gauge empties it enters a "danger" state ([signal depleted],
## [member in_danger]) until it refills past [member recover_fraction] —
## wire a defense penalty to that if you want BB's Danger State.

signal gauge_changed(value: float, max_value: float)
signal depleted
signal recovered
signal barrier_blocked(data: HitData)

@export var enabled: bool = true
## All of these must be held (along with back) to barrier.
@export var barrier_buttons: PackedStringArray = PackedStringArray(["a", "b"])

@export_group("Gauge")
@export var gauge_max: float = 100.0
## Drain per frame while the barrier is held.
@export var hold_drain: float = 0.12
## Extra drain per blocked hit.
@export var block_drain: float = 4.0
## Regen per frame while not holding.
@export var regen: float = 0.05
## Fraction the gauge must refill to before barrier works again after
## being emptied.
@export_range(0.0, 1.0) var recover_fraction: float = 0.5

@export_group("Effects")
## Barrier blocks take no chip damage.
@export var negates_chip: bool = true
## Pushback multiplier on barrier blocks (shove them out).
@export var pushback_multiplier: float = 1.7
## Barrier allows air-blocking hits flagged air_blockable = false.
@export var air_blocks_everything: bool = true
## Barrier blocks also skip guard gauge damage (no guard break through FD).
@export var protects_guard_gauge: bool = true

var gauge: float = 0.0
var in_danger: bool = false


func _ready() -> void:
	gauge = gauge_max
	gauge_changed.emit(gauge, gauge_max)


## Whether the barrier can currently be used.
func is_usable() -> bool:
	return enabled and gauge > 0.0 and not in_danger


## Called by Fighter2D once per logical frame.
func frame_tick(holding: bool) -> void:
	if holding and is_usable():
		_drain(hold_drain)
	elif gauge < gauge_max:
		gauge = minf(gauge + regen, gauge_max)
		if in_danger and gauge >= gauge_max * recover_fraction:
			in_danger = false
			recovered.emit()
		gauge_changed.emit(gauge, gauge_max)


## Called by Fighter2D when a hit is barrier-blocked.
func on_block(data: HitData) -> void:
	_drain(block_drain)
	barrier_blocked.emit(data)


func _drain(amount: float) -> void:
	if amount <= 0.0:
		return
	gauge = maxf(gauge - amount, 0.0)
	gauge_changed.emit(gauge, gauge_max)
	if gauge == 0.0 and not in_danger:
		in_danger = true
		depleted.emit()


## Rollback / save-state support.
func save_state() -> Dictionary:
	return {"gauge": gauge, "in_danger": in_danger}


func load_state(state: Dictionary) -> void:
	gauge = state["gauge"]
	in_danger = state["in_danger"]
	gauge_changed.emit(gauge, gauge_max)
