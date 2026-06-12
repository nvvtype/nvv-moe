class_name RoundManager
extends Node

## Round and match flow: round timer, KO / double KO / time over / perfect
## detection, round wins, and match victory.
##
## Add it to your fight scene, assign the fighters, and call
## [method start_match]. Listen to the signals for announcer text, lifebar
## updates, and scene flow. Supports any number of fighters (2 for a duel,
## more for simul-style team play — last team standing wins).

signal match_started
signal round_started(round_number: int)
## winner_index is -1 on a draw. reason is one of: &"ko", &"double_ko",
## &"time_over", &"perfect".
signal round_ended(winner_index: int, reason: StringName)
signal match_ended(winner_index: int)
signal timer_changed(seconds_left: int)

enum Phase { IDLE, PRE_ROUND, FIGHTING, ROUND_OVER, MATCH_OVER }

@export var fighters: Array[Fighter2D] = []
@export var rounds_to_win: int = 2
## Round time in seconds. 0 = infinite (training).
@export var round_time: int = 99
## Frames between round_started and control being handed to players
## ("Round 1... FIGHT!").
@export var pre_round_frames: int = 120
## Frames after a KO before round_ended fires (slow-mo replays, poses).
@export var round_end_frames: int = 90
## Maximum rounds before a match draw is declared (sudden death cap).
@export var max_rounds: int = 9

var phase: Phase = Phase.IDLE
var round_number: int = 0
var wins: PackedInt32Array = PackedInt32Array()
var seconds_left: int = 0

var _phase_frames: int = 0
var _frame_accum: int = 0
var _round_winner: int = -1
var _round_reason: StringName = &"ko"


func start_match() -> void:
	wins.resize(fighters.size())
	wins.fill(0)
	round_number = 0
	for i in fighters.size():
		var fighter := fighters[i]
		if not fighter.died.is_connected(_on_fighter_died):
			fighter.died.connect(_on_fighter_died)
	match_started.emit()
	start_round()


func start_round() -> void:
	round_number += 1
	seconds_left = round_time
	_frame_accum = 0
	for fighter in fighters:
		fighter.reset_for_round()
	phase = Phase.PRE_ROUND
	_phase_frames = pre_round_frames
	round_started.emit(round_number)
	timer_changed.emit(seconds_left)


## True while players should have control.
func is_fighting() -> bool:
	return phase == Phase.FIGHTING


func _physics_process(_delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_paused:
		return

	match phase:
		Phase.PRE_ROUND:
			_phase_frames -= 1
			if _phase_frames <= 0:
				phase = Phase.FIGHTING
		Phase.FIGHTING:
			_tick_timer()
		Phase.ROUND_OVER:
			_phase_frames -= 1
			if _phase_frames <= 0:
				_finish_round()


func _tick_timer() -> void:
	if round_time <= 0:
		return
	_frame_accum += 1
	if _frame_accum < 60:
		return
	_frame_accum = 0
	seconds_left -= 1
	timer_changed.emit(seconds_left)
	if seconds_left <= 0:
		_resolve_time_over()


func _on_fighter_died() -> void:
	if phase != Phase.FIGHTING:
		return
	var alive := _alive_indices()
	if alive.size() > 1:
		return  # Team play: fight continues while 2+ fighters stand.

	if alive.is_empty():
		_round_winner = -1
		_round_reason = &"double_ko"
	else:
		_round_winner = alive[0]
		_round_reason = &"ko"
		if fighters[_round_winner].health != null \
				and fighters[_round_winner].health.is_full():
			_round_reason = &"perfect"
	_begin_round_over()


func _resolve_time_over() -> void:
	var best := -1
	var best_ratio := -1.0
	var tied := false
	for i in fighters.size():
		var hp := fighters[i].health
		var ratio := 0.0
		if hp != null and hp.max_health > 0:
			ratio = float(hp.current) / float(hp.max_health)
		if absf(ratio - best_ratio) < 0.0001:
			tied = true
		elif ratio > best_ratio:
			best_ratio = ratio
			best = i
			tied = false
	_round_winner = -1 if tied else best
	_round_reason = &"time_over"
	_begin_round_over()


func _begin_round_over() -> void:
	phase = Phase.ROUND_OVER
	_phase_frames = round_end_frames


func _alive_indices() -> Array[int]:
	var alive: Array[int] = []
	for i in fighters.size():
		if fighters[i].health == null or not fighters[i].health.is_dead:
			alive.append(i)
	return alive


func _finish_round() -> void:
	if _round_winner >= 0:
		wins[_round_winner] += 1
	round_ended.emit(_round_winner, _round_reason)

	for i in wins.size():
		if wins[i] >= rounds_to_win:
			phase = Phase.MATCH_OVER
			match_ended.emit(i)
			return

	if round_number >= max_rounds:
		phase = Phase.MATCH_OVER
		match_ended.emit(-1)
		return

	start_round()
