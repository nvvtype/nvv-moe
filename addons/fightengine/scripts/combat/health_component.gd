class_name HealthComponent
extends Node

## Health, red (recoverable) life, dizzy gauge, and guard gauge for one
## fighter — the defensive resource block, modelled on IKEMEN GO's life,
## red life, dizzy points, and guard break systems.
##
## Dizzy and guard break are opt-in: leave their thresholds at 0 to disable.

signal health_changed(current: int, max_health: int)
signal red_life_changed(red_life: int)
signal damaged(amount: int, data: HitData)
signal healed(amount: int)
signal dizzied
signal guard_broken
signal died

@export var max_health: int = 1000
## Defense multiplier: incoming damage is divided by this. 1.0 = normal.
@export var defense: float = 1.0

@export_group("Red life")
## Master switch for recoverable life.
@export var use_red_life: bool = false
## Red life recovered per logical frame while [method regen_tick] is called
## (call it from your idle/walk states, or every frame for constant regen).
@export var red_life_regen: float = 0.5

@export_group("Dizzy")
## Dizzy points needed to get stunned. 0 = dizzy system disabled.
@export var dizzy_threshold: int = 0
## Dizzy points that drain per frame when not being hit.
@export var dizzy_decay: float = 0.25

@export_group("Guard gauge")
## Guard damage needed to trigger a guard break. 0 = disabled.
@export var guard_gauge_max: int = 0
@export var guard_gauge_regen: float = 0.2

@export_group("Kusoge dials")
## Allow chip damage to KO. Off = chip leaves the victim at 1 HP.
@export var allow_chip_kill: bool = true

var current: int
var red_life: int = 0
var dizzy_points: float = 0.0
var guard_gauge: float = 0.0
var is_dead: bool = false

var _red_life_accum: float = 0.0


func _ready() -> void:
	current = max_health
	health_changed.emit(current, max_health)


func _physics_process(_delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_frozen(self):
		return
	if dizzy_threshold > 0 and dizzy_points > 0.0:
		dizzy_points = maxf(dizzy_points - dizzy_decay, 0.0)
	if guard_gauge_max > 0 and guard_gauge > 0.0:
		guard_gauge = maxf(guard_gauge - guard_gauge_regen, 0.0)


## Applies a clean (unblocked) hit. Returns the damage actually dealt.
func take_hit(data: HitData, scaling: float = 1.0) -> int:
	if is_dead:
		return 0
	var amount := maxi(int(roundf(data.damage * scaling / maxf(defense, 0.01))), 0)
	if data.damage > 0:
		amount = maxi(amount, 1)
	_apply_damage(amount, data)

	if use_red_life and data.red_life_fraction > 0.0:
		red_life += int(roundf(amount * data.red_life_fraction))
		red_life = mini(red_life, max_health - current)
		red_life_changed.emit(red_life)

	if dizzy_threshold > 0 and data.dizzy_points > 0:
		dizzy_points += data.dizzy_points
		if dizzy_points >= dizzy_threshold:
			dizzy_points = 0.0
			dizzied.emit()
	return amount


## Applies a blocked hit (chip damage + guard gauge). Returns chip dealt.
func take_chip(data: HitData) -> int:
	if is_dead:
		return 0
	var amount := maxi(int(roundf(data.chip_damage / maxf(defense, 0.01))), 0)
	if not allow_chip_kill and amount >= current:
		amount = maxi(current - 1, 0)
	_apply_damage(amount, data)

	if guard_gauge_max > 0 and data.guard_damage > 0:
		guard_gauge += data.guard_damage
		if guard_gauge >= guard_gauge_max:
			guard_gauge = 0.0
			guard_broken.emit()
	return amount


func _apply_damage(amount: int, data: HitData) -> void:
	if amount <= 0:
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount, data)
	health_changed.emit(current, max_health)
	if current == 0 and not is_dead:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or is_dead:
		return
	current = mini(current + amount, max_health)
	red_life = mini(red_life, max_health - current)
	healed.emit(amount)
	health_changed.emit(current, max_health)


## Converts red life back into health over time. Call from states where the
## fighter should regenerate (idle, walking, tagged out...).
func regen_tick() -> void:
	if not use_red_life or red_life <= 0 or is_dead:
		return
	_red_life_accum += red_life_regen
	if _red_life_accum < 1.0:
		return
	var amount := mini(int(_red_life_accum), red_life)
	_red_life_accum -= amount
	red_life -= amount
	current = mini(current + amount, max_health)
	red_life_changed.emit(red_life)
	health_changed.emit(current, max_health)


func is_full() -> bool:
	return current >= max_health


func reset() -> void:
	current = max_health
	red_life = 0
	dizzy_points = 0.0
	guard_gauge = 0.0
	is_dead = false
	_red_life_accum = 0.0
	health_changed.emit(current, max_health)
	red_life_changed.emit(red_life)


## Rollback / save-state support.
func save_state() -> Dictionary:
	return {
		"current": current, "red_life": red_life,
		"dizzy_points": dizzy_points, "guard_gauge": guard_gauge,
		"is_dead": is_dead, "red_life_accum": _red_life_accum,
	}


func load_state(state: Dictionary) -> void:
	current = state["current"]
	red_life = state["red_life"]
	dizzy_points = state["dizzy_points"]
	guard_gauge = state["guard_gauge"]
	is_dead = state["is_dead"]
	_red_life_accum = state["red_life_accum"]
	health_changed.emit(current, max_health)
	red_life_changed.emit(red_life)
