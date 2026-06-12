class_name BurstSystem
extends Node

## Burst (BlazBlue / GGXX style): a separate defensive gauge that, when
## full, lets the fighter explode out of pressure.
##
## Add as a child of a [Fighter2D] and assign a HitBox2D (usually a big
## circle around the body) to [member burst_hitbox]. The system fills the
## gauge passively and from damage taken, detects the burst input, and on
## burst: clears stun, drops the combo, grants intangibility, pops the
## fighter upward, and activates the hitbox for a few frames.
##
## Bursting in neutral (not in stun) is a gold burst — same explosion, plus
## the [signal gold_burst] signal for your bonus of choice (BB refills heat,
## GG refills tension; wire it to taste).

signal gauge_changed(value: float, max_value: float)
signal burst_performed(gold: bool)
signal burst_ended
## Emitted alongside burst_performed when the burst was done in neutral.
signal gold_burst

@export var enabled: bool = true
## The explosion hitbox, toggled by the system. Give it a HitData with a big
## launch and zero damage (or nonzero damage — kusoge dial, damaging bursts).
@export var burst_hitbox: HitBox2D

@export_group("Gauge")
@export var gauge_max: float = 100.0
@export var start_full: bool = true
## Gauge gained per logical frame.
@export var passive_gain: float = 0.01
## Gauge gained per point of damage taken.
@export var gain_per_damage: float = 0.02
## Bursting spends the whole gauge. Lower this for multi-burst kusoge.
@export_range(0.0, 1.0) var burst_cost_fraction: float = 1.0

@export_group("Burst behaviour")
## All of these pressed together (3-frame window) triggers the burst.
## Leave empty to only burst via [method try_burst] from your states.
@export var burst_buttons: PackedStringArray = PackedStringArray()
@export var burst_invuln_frames: int = 25
@export var burst_active_frames: int = 10
## Upward pop applied to the bursting fighter.
@export var burst_velocity: Vector2 = Vector2(0, -350)
## Allow bursting out of blockstun too (BB yes, GG no).
@export var burst_from_blockstun: bool = true
## Allow bursting while being thrown/knocked down. Off in every sane game.
@export var burst_from_knockdown: bool = false

var gauge: float = 0.0
var is_bursting: bool = false

var _fighter: Fighter2D
var _active_frames_left: int = 0


func _ready() -> void:
	_fighter = get_parent() as Fighter2D
	if start_full:
		gauge = gauge_max
	if _fighter != null:
		_fighter.hit_taken.connect(_on_hit_taken)
	if burst_hitbox != null:
		burst_hitbox.is_active = false
	gauge_changed.emit(gauge, gauge_max)


func _physics_process(_delta: float) -> void:
	if _fighter == null or not enabled:
		return
	if FightClock.active != null and FightClock.active.is_frozen(_fighter):
		return

	if gauge < gauge_max:
		gauge = minf(gauge + passive_gain, gauge_max)
		gauge_changed.emit(gauge, gauge_max)

	if _active_frames_left > 0:
		_active_frames_left -= 1
		if _active_frames_left == 0:
			if burst_hitbox != null:
				burst_hitbox.is_active = false
			is_bursting = false
			burst_ended.emit()

	if not burst_buttons.is_empty() and _buttons_pressed():
		try_burst()


func is_ready() -> bool:
	return enabled and not is_bursting and gauge >= gauge_max * burst_cost_fraction


func can_burst() -> bool:
	if _fighter == null or not is_ready():
		return false
	if _fighter.health != null and _fighter.health.is_dead:
		return false
	if _fighter.is_knocked_down() and not burst_from_knockdown:
		return false
	if _fighter.in_blockstun() and not burst_from_blockstun:
		return false
	return true


## Performs the burst if possible. Returns true on success.
func try_burst() -> bool:
	if not can_burst():
		return false

	var gold := not _fighter.in_stun()
	gauge -= gauge_max * burst_cost_fraction
	gauge_changed.emit(gauge, gauge_max)

	_fighter.hitstun_frames = 0
	_fighter.blockstun_frames = 0
	_fighter.knockdown_frames = 0
	if _fighter.combo_tracker != null:
		_fighter.combo_tracker.drop()
	_fighter.intangible_frames = maxi(_fighter.intangible_frames, burst_invuln_frames)
	_fighter.velocity = burst_velocity

	is_bursting = true
	_active_frames_left = burst_active_frames
	if burst_hitbox != null:
		burst_hitbox.is_active = true

	burst_performed.emit(gold)
	if gold:
		gold_burst.emit()
	return true


func _buttons_pressed() -> bool:
	var buffer := _fighter.input_buffer
	if buffer == null:
		return false
	var pressed_now := false
	for button in burst_buttons:
		if not buffer.was_pressed(button, 3):
			return false
		if buffer.was_pressed(button, 1):
			pressed_now = true
	return pressed_now


func _on_hit_taken(_attacker: Fighter2D, data: HitData, blocked: bool) -> void:
	if blocked or gain_per_damage <= 0.0:
		return
	gauge = minf(gauge + data.damage * gain_per_damage, gauge_max)
	gauge_changed.emit(gauge, gauge_max)


## Rollback / save-state support.
func save_state() -> Dictionary:
	return {
		"gauge": gauge, "is_bursting": is_bursting,
		"active_frames_left": _active_frames_left,
	}


func load_state(state: Dictionary) -> void:
	gauge = state["gauge"]
	is_bursting = state["is_bursting"]
	_active_frames_left = state["active_frames_left"]
	gauge_changed.emit(gauge, gauge_max)
