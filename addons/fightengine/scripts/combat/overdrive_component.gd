class_name OverdriveComponent
extends Node

## Overdrive / install activation (BlazBlue Overdrive, install supers).
##
## A timed power-up state with generic engine hooks: a dramatic activation
## freeze, attack/defense/meter multipliers applied automatically by
## [Fighter2D], duration that stretches at low health (BB style), and
## signals for everything character-specific (your install's actual gimmick:
## new moves, changed properties, regen — react to [signal overdrive_started]
## and check [member is_active] from your states and movelist logic).
##
## Add as a child of a [Fighter2D] and assign it to the fighter's
## [member Fighter2D.overdrive] slot.

signal overdrive_started(duration_frames: int)
signal overdrive_ended
signal cooldown_finished

@export var enabled: bool = true
## All of these pressed together (3-frame window) activates. Leave empty to
## only activate via [method try_activate] from your states.
@export var activation_buttons: PackedStringArray = PackedStringArray()

@export_group("Duration (frames)")
@export var base_duration: int = 300
## Extra duration at 0% health, scaled linearly with missing health
## (BlazBlue: overdrive lasts longer the closer you are to death).
@export var low_health_bonus: int = 300
@export var cooldown: int = 900
## Once per round instead of cooldown-based.
@export var once_per_round: bool = false

@export_group("Activation")
## Opponent-only freeze on activation (the dramatic screen stop).
@export var activation_freeze_frames: int = 30
## Activating while in stun also clears it (burst-style defensive
## activation, like BB's Overdrive Raid). Off = neutral only.
@export var usable_in_stun: bool = false

@export_group("While active")
@export var attack_multiplier: float = 1.1
## Incoming damage is multiplied by this while active (<1 = tankier).
@export var defense_multiplier: float = 1.0
@export var meter_gain_multiplier: float = 1.5

var is_active: bool = false
var frames_left: int = 0
var cooldown_left: int = 0
var used_this_round: bool = false

var _fighter: Fighter2D
var _saved_meter_multiplier: float = 1.0


func _ready() -> void:
	_fighter = get_parent() as Fighter2D


func _physics_process(_delta: float) -> void:
	if _fighter == null or not enabled:
		return
	if FightClock.active != null and FightClock.active.is_frozen(_fighter):
		return

	if is_active:
		frames_left -= 1
		if frames_left <= 0:
			_deactivate()
	elif cooldown_left > 0:
		cooldown_left -= 1
		if cooldown_left == 0:
			cooldown_finished.emit()

	if not activation_buttons.is_empty() and _buttons_pressed():
		try_activate()


func can_activate() -> bool:
	if _fighter == null or not enabled or is_active or cooldown_left > 0:
		return false
	if once_per_round and used_this_round:
		return false
	if _fighter.health != null and _fighter.health.is_dead:
		return false
	if _fighter.in_stun() and not usable_in_stun:
		return false
	return true


func try_activate() -> bool:
	if not can_activate():
		return false

	if _fighter.in_stun():
		_fighter.hitstun_frames = 0
		_fighter.blockstun_frames = 0
		if _fighter.combo_tracker != null:
			_fighter.combo_tracker.drop()

	var duration := base_duration
	if low_health_bonus > 0 and _fighter.health != null \
			and _fighter.health.max_health > 0:
		var missing := 1.0 - float(_fighter.health.current) / float(_fighter.health.max_health)
		duration += int(low_health_bonus * missing)

	is_active = true
	frames_left = duration
	used_this_round = true

	if _fighter.meter != null:
		_saved_meter_multiplier = _fighter.meter.gain_multiplier
		_fighter.meter.gain_multiplier *= meter_gain_multiplier

	if activation_freeze_frames > 0 and FightClock.active != null \
			and _fighter.opponent != null:
		FightClock.active.hitstop([_fighter.opponent], activation_freeze_frames)

	overdrive_started.emit(duration)
	return true


func end_now() -> void:
	if is_active:
		_deactivate()


func _deactivate() -> void:
	is_active = false
	frames_left = 0
	cooldown_left = cooldown
	if _fighter != null and _fighter.meter != null:
		_fighter.meter.gain_multiplier = _saved_meter_multiplier
	overdrive_ended.emit()


## Call from RoundManager glue (or reset_for_round) for once-per-round use.
func reset_for_round() -> void:
	if is_active:
		_deactivate()
	cooldown_left = 0
	used_this_round = false


func _buttons_pressed() -> bool:
	var buffer := _fighter.input_buffer
	if buffer == null:
		return false
	var pressed_now := false
	for button in activation_buttons:
		if not buffer.was_pressed(button, 3):
			return false
		if buffer.was_pressed(button, 1):
			pressed_now = true
	return pressed_now


## Rollback / save-state support.
func save_state() -> Dictionary:
	return {
		"is_active": is_active, "frames_left": frames_left,
		"cooldown_left": cooldown_left, "used_this_round": used_this_round,
		"saved_meter_multiplier": _saved_meter_multiplier,
	}


func load_state(state: Dictionary) -> void:
	is_active = state["is_active"]
	frames_left = state["frames_left"]
	cooldown_left = state["cooldown_left"]
	used_this_round = state["used_this_round"]
	_saved_meter_multiplier = state["saved_meter_multiplier"]
