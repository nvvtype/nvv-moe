class_name MeterComponent
extends Node

## Super meter with stocks. 1000 units = 1 stock by default, IKEMEN style.

signal meter_changed(value: int, max_value: int)
signal stock_gained(stocks: int)
signal stock_spent(stocks: int)

@export var units_per_stock: int = 1000
@export var max_stocks: int = 3
## Starting meter in units.
@export var initial_meter: int = 0
## Kusoge dial: meter gain multiplier. Crank it for a super-spam fest.
@export var gain_multiplier: float = 1.0
## Meter per logical frame: positive = Melty-style auto charge, negative =
## install-style drain. 0 = off.
@export var passive_per_frame: float = 0.0

var value: int = 0

var _passive_accum: float = 0.0


func _physics_process(_delta: float) -> void:
	if passive_per_frame == 0.0:
		return
	if FightClock.active != null and FightClock.active.is_paused:
		return
	_passive_accum += passive_per_frame
	var whole := int(_passive_accum)
	if whole != 0:
		_passive_accum -= whole
		value = clampi(value + whole, 0, max_value())
		meter_changed.emit(value, max_value())


func _ready() -> void:
	value = clampi(initial_meter, 0, max_value())
	meter_changed.emit(value, max_value())


func max_value() -> int:
	return units_per_stock * max_stocks


func stocks() -> int:
	return value / units_per_stock


func gain(amount: int) -> void:
	if amount <= 0:
		return
	var before := stocks()
	value = clampi(value + int(roundf(amount * gain_multiplier)), 0, max_value())
	meter_changed.emit(value, max_value())
	if stocks() > before:
		stock_gained.emit(stocks())


## Spends raw meter units. Returns false (and spends nothing) if short.
func try_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if value < amount:
		return false
	value -= amount
	meter_changed.emit(value, max_value())
	stock_spent.emit(stocks())
	return true


func try_spend_stocks(count: int) -> bool:
	return try_spend(count * units_per_stock)


func reset() -> void:
	value = clampi(initial_meter, 0, max_value())
	meter_changed.emit(value, max_value())


## Rollback / save-state support.
func save_state() -> Dictionary:
	return {"value": value, "passive_accum": _passive_accum}


func load_state(state: Dictionary) -> void:
	value = state["value"]
	_passive_accum = state["passive_accum"]
	meter_changed.emit(value, max_value())
