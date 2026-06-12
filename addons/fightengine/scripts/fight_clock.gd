class_name FightClock
extends Node

## Central logic clock for a fight scene.
##
## Owns the logical frame counter, per-actor hitstop, global slow motion, and
## the pause / frame-step controls used by training mode. Add one FightClock
## node to your fight scene; every FightEngine node finds it through
## [member FightClock.active].
##
## Anything that should freeze during hitstop checks
## [code]FightClock.active.is_frozen(self)[/code] at the top of its
## physics process. [Fighter2D] does this automatically.

static var active: FightClock

signal frame_advanced(frame: int)
signal paused_changed(is_paused: bool)

## Logical frame counter. Only advances while unpaused (or when stepping).
var frame: int = 0

## Global slow motion. 2 = half speed, 3 = third speed, etc. Logic frames
## only advance every Nth physics frame. 1 = normal speed.
@export var slowdown: int = 1

var is_paused: bool = false:
	set(value):
		if is_paused == value:
			return
		is_paused = value
		paused_changed.emit(is_paused)

var _stepping: bool = false
var _step_requested: bool = false
var _hitstop_until: Dictionary = {}
var _slowdown_accum: int = 0


func _init() -> void:
	# Run before fighters and input buffers every physics frame.
	process_physics_priority = -1000


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


func _physics_process(_delta: float) -> void:
	_stepping = _step_requested
	_step_requested = false

	if is_paused and not _stepping:
		return

	_slowdown_accum += 1
	if _slowdown_accum < maxi(slowdown, 1) and not _stepping:
		return
	_slowdown_accum = 0

	frame += 1
	frame_advanced.emit(frame)


## True if the given actor should not advance this frame (hitstop, pause,
## or a skipped slow-motion frame).
func is_frozen(actor: Object) -> bool:
	if is_paused and not _stepping:
		return true
	if _slowdown_accum != 0:
		return true
	if _hitstop_until.has(actor):
		if frame <= int(_hitstop_until[actor]):
			return true
		_hitstop_until.erase(actor)
	return false


## Freezes each actor in [param actors] for [param frames] logical frames.
## Pass only the victim to make a super-flash style one-sided freeze.
func hitstop(actors: Array, frames: int) -> void:
	if frames <= 0:
		return
	for actor in actors:
		if actor != null:
			var until := frame + frames
			_hitstop_until[actor] = maxi(until, int(_hitstop_until.get(actor, 0)))


func clear_hitstop(actor: Object = null) -> void:
	if actor == null:
		_hitstop_until.clear()
	else:
		_hitstop_until.erase(actor)


## Advances exactly one logical frame while paused (training mode frame step).
func step_frame() -> void:
	_step_requested = true


## Rollback / save-state support. Hitstop entries are stored by node path so
## they survive a restore.
func save_state() -> Dictionary:
	var hitstop_paths := {}
	for actor in _hitstop_until:
		if actor is Node and (actor as Node).is_inside_tree():
			hitstop_paths[(actor as Node).get_path()] = _hitstop_until[actor]
	return {
		"frame": frame,
		"slowdown_accum": _slowdown_accum,
		"hitstop": hitstop_paths,
	}


func load_state(state: Dictionary) -> void:
	frame = state["frame"]
	_slowdown_accum = state["slowdown_accum"]
	_hitstop_until.clear()
	var hitstop_paths: Dictionary = state["hitstop"]
	for path in hitstop_paths:
		var node := get_node_or_null(path)
		if node != null:
			_hitstop_until[node] = hitstop_paths[path]
