class_name FrameAdvantageTracker
extends Node

## Training-mode frame advantage meter.
##
## Watches two fighters and, after every interaction in which both were busy
## (attacking and/or stuck in stun), reports how many frames earlier
## [member attacker] could act compared to [member defender]. Positive =
## attacker is plus, negative = minus — the number every frame-data nerd
## wants on screen.

signal measured(advantage: int)

@export var attacker: Fighter2D
@export var defender: Fighter2D

var last_advantage: int = 0

var _frame: int = 0
var _attacker_was_busy: bool = false
var _defender_was_busy: bool = false
var _attacker_busy_prev: bool = false
var _defender_busy_prev: bool = false
var _attacker_free_frame: int = 0
var _defender_free_frame: int = 0


func _physics_process(_delta: float) -> void:
	if attacker == null or defender == null:
		return
	if FightClock.active != null and FightClock.active.is_paused:
		return
	_frame += 1

	var attacker_busy := _is_busy(attacker)
	var defender_busy := _is_busy(defender)

	if attacker_busy:
		_attacker_was_busy = true
	if defender_busy:
		_defender_was_busy = true

	if _attacker_busy_prev and not attacker_busy:
		_attacker_free_frame = _frame
	if _defender_busy_prev and not defender_busy:
		_defender_free_frame = _frame

	if not attacker_busy and not defender_busy \
			and _attacker_was_busy and _defender_was_busy:
		last_advantage = _defender_free_frame - _attacker_free_frame
		measured.emit(last_advantage)
		_attacker_was_busy = false
		_defender_was_busy = false

	_attacker_busy_prev = attacker_busy
	_defender_busy_prev = defender_busy


func _is_busy(fighter: Fighter2D) -> bool:
	return fighter.in_stun() or fighter.is_attacking()
