class_name FighterStateMachine
extends Node

## Batteries-included character controller.
##
## Add as a child of a [Fighter2D] and every universal fighting game state is
## handled for you, driven entirely by [FighterData]: walking, crouching,
## prejump/jumps/double jumps/superjumps, step or run dashes, backdashes, air
## dashes, attacks, hitstun, blockstun, knockdown/wakeup, dizzy, guard crush,
## and taunts. Characters become pure resources — no per-character states.
##
## Attacks are FRAME-DATA DRIVEN: startup/active/recovery on [MoveData]
## toggles the move's hitbox and applies its hits; the animation (if one
## exists) is purely visual on top. Two frames of kusoge art is plenty —
## a move with no animation at all still functions.
##
## Animations are looked up by convention on [member anim_player] and every
## one of them is optional:
## [codeblock]
## idle, walk_f, walk_b, crouch, prejump, jump, fall,
## dash, backdash, airdash, airdash_b,
## hitstun, hitstun_air, block, block_crouch, block_air,
## knockdown, getup, dizzy, guard_crush, taunt
## + MoveData.animation per move (e.g. "moves/5l")
## [/codeblock]
##
## For fully custom character gimmicks, subclass and override
## [method _on_custom_state], or bypass states entirely with your own FSM —
## this node is a convenience, not a requirement.

signal state_changed(old_state: State, new_state: State)
signal move_started(move: MoveData)
signal move_ended(move: MoveData)

enum State {
	IDLE, WALK_F, WALK_B, CROUCH,
	PREJUMP, AIR,
	DASH, BACKDASH, AIR_DASH,
	ATTACK,
	HITSTUN, BLOCKSTUN, KNOCKDOWN, GETUP,
	DIZZY, GUARD_CRUSH, TAUNT, LANDING,
	CUSTOM,
}

const _NO_ACT_STATES: Array[State] = [
	State.HITSTUN, State.BLOCKSTUN, State.KNOCKDOWN, State.GETUP,
	State.DIZZY, State.GUARD_CRUSH, State.LANDING, State.PREJUMP,
]

## Auto-detected from the parent when unset.
@export var fighter: Fighter2D
## Auto-detected (first AnimationPlayer under the fighter) when unset.
@export var anim_player: AnimationPlayer
## Auto-detected (first CommandInterpreter under the fighter) when unset.
@export var interpreter: CommandInterpreter

@export_group("Stun states (frames)")
## Dizzy stun length when HealthComponent.dizzied fires.
@export var dizzy_frames: int = 180
## Frames shaved off dizzy per button mashed.
@export var dizzy_mash_recovery: int = 3
## Hittable stun applied on guard break.
@export var guard_crush_frames: int = 45
## Frames of the getup animation after a knockdown ends.
@export var getup_frames: int = 10

@export_group("Wakeup & reversals")
## Mashing during a soft knockdown shortens it to this many remaining
## frames (quick rise). Hard knockdowns can't be quick risen.
@export var quick_rise_enabled: bool = true
@export var quick_rise_frames: int = 6
## Holding back when getting up shifts the fighter backward (back rise).
@export var back_rise_distance: float = 40.0
## Commands entered during stun/getup within this many frames of becoming
## actionable come out on the first actionable frame (wakeup DPs, reversal
## supers). 0 = no reversal buffer.
@export var reversal_window: int = 5

@export_group("Taunt")
## Button that taunts from neutral. Empty = no taunt.
@export var taunt_button: String = ""
@export var taunt_frames: int = 60
## Meter gifted to the opponent for your hubris (GG respect rules).
@export var taunt_gives_opponent_meter: int = 0

var state: State = State.IDLE
var state_frames: int = 0

var _move_frames: int = 0
var _active_hitbox: HitBox2D = null
var _hit_segment: int = -1
var _dash_motion: MotionInput
var _backdash_motion: MotionInput
var _superjump_queued: bool = false
var _queued_move: MoveData = null
var _queued_frames: int = 0
var _kd_hard: bool = false


func _ready() -> void:
	if fighter == null:
		fighter = get_parent() as Fighter2D
	if fighter == null:
		push_warning("FighterStateMachine needs a Fighter2D parent or export.")
		set_physics_process(false)
		return
	if anim_player == null:
		anim_player = _find_child_of(fighter, "AnimationPlayer") as AnimationPlayer
	if interpreter == null:
		interpreter = _find_child_of(fighter, "CommandInterpreter") as CommandInterpreter

	if interpreter != null:
		if interpreter.input_buffer == null:
			interpreter.input_buffer = fighter.input_buffer
		if interpreter.fighter == null:
			interpreter.fighter = fighter
		if interpreter.moves.is_empty() and fighter.data != null:
			interpreter.set_movelist(fighter.data.moves)
		interpreter.move_detected.connect(_on_move_detected)

	_dash_motion = MotionInput.new()
	_dash_motion.sequence = [6, 5, 6]
	_dash_motion.max_duration = 11
	_backdash_motion = MotionInput.new()
	_backdash_motion.sequence = [4, 5, 4]
	_backdash_motion.max_duration = 11

	# Deferred: children ready before parents, so the fighter's auto-created
	# components (health, burst...) don't exist yet during our _ready.
	_wire_fighter_signals.call_deferred()
	_enter(State.IDLE)


func _wire_fighter_signals() -> void:
	fighter.hit_taken.connect(_on_hit_taken)
	fighter.wall_splatted.connect(func() -> void: _play(&"wall_splat", &"hitstun"))
	fighter.knocked_down.connect(_on_knocked_down)
	fighter.got_up.connect(_on_got_up)
	fighter.stun_ended.connect(_on_stun_ended)
	fighter.air_teched.connect(_on_air_teched)
	fighter.landed.connect(_on_landed)
	fighter.alpha_countered.connect(_on_forced_move)
	fighter.roman_canceled.connect(_on_roman_canceled)
	if fighter.burst != null:
		fighter.burst.burst_performed.connect(_on_burst)
	if fighter.health != null:
		fighter.health.dizzied.connect(_on_dizzied)
		fighter.health.guard_broken.connect(_on_guard_broken)


func _find_child_of(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name) or child.get_script() != null \
				and child.get_script().get_global_name() == StringName(type_name):
			return child
		var nested := _find_child_of(child, type_name)
		if nested != null:
			return nested
	return null


func _physics_process(_delta: float) -> void:
	if fighter == null:
		return
	if FightClock.active != null and FightClock.active.is_frozen(fighter):
		return
	state_frames += 1
	if _queued_frames > 0:
		_queued_frames -= 1
		if _queued_frames == 0:
			_queued_move = null

	match state:
		State.IDLE, State.WALK_F, State.WALK_B, State.CROUCH:
			if not _try_queued_move():
				_tick_locomotion()
		State.PREJUMP:
			_tick_prejump()
		State.AIR:
			if not _try_queued_move():
				_tick_air()
		State.DASH:
			_tick_dash()
		State.BACKDASH:
			_tick_backdash()
		State.AIR_DASH:
			_tick_air_dash()
		State.ATTACK:
			_tick_attack()
		State.DIZZY:
			_tick_dizzy()
		State.KNOCKDOWN:
			_tick_knockdown()
		State.GETUP, State.TAUNT, State.LANDING:
			_tick_timed_state()
		State.CUSTOM:
			_on_custom_state()
		_:
			pass  # Stun states exit via fighter signals.


# --- State entry -------------------------------------------------------------

func _enter(new_state: State) -> void:
	var old := state
	state = new_state
	state_frames = 0
	match new_state:
		State.IDLE:
			fighter.velocity.x = 0.0
			_play(&"idle")
		State.WALK_F:
			_play(&"walk_f")
		State.WALK_B:
			_play(&"walk_b")
		State.CROUCH:
			fighter.velocity.x = 0.0
			_play(&"crouch")
		State.PREJUMP:
			_play(&"prejump")
		State.AIR:
			_play(&"jump" if fighter.velocity.y < 0 else &"fall")
		State.DASH:
			_play(&"dash")
		State.BACKDASH:
			_play(&"backdash")
		State.AIR_DASH:
			pass  # anim picked in _start_air_dash
		State.HITSTUN:
			_play(&"hitstun_air" if fighter.is_airborne() else &"hitstun")
		State.BLOCKSTUN:
			if fighter.is_airborne():
				_play(&"block_air")
			elif fighter.crouching:
				_play(&"block_crouch", &"block")
			else:
				_play(&"block")
		State.KNOCKDOWN:
			_play(&"knockdown")
		State.GETUP:
			_play(&"getup")
		State.DIZZY:
			fighter.hitstun_frames = dizzy_frames
			_play(&"dizzy", &"hitstun")
		State.GUARD_CRUSH:
			fighter.hitstun_frames = guard_crush_frames
			_play(&"guard_crush", &"hitstun")
		State.TAUNT:
			fighter.velocity.x = 0.0
			_play(&"taunt", &"idle")
			if taunt_gives_opponent_meter > 0 and fighter.opponent != null \
					and fighter.opponent.meter != null:
				fighter.opponent.meter.gain(taunt_gives_opponent_meter)
		State.LANDING:
			fighter.velocity.x = 0.0
			_play(&"landing", &"idle")
		_:
			pass
	if old != new_state:
		state_changed.emit(old, new_state)


func _to_neutral() -> void:
	_enter(State.AIR if fighter.is_airborne() else State.IDLE)


# --- Locomotion --------------------------------------------------------------

func _tick_locomotion() -> void:
	var buffer := fighter.input_buffer
	if buffer == null:
		return

	if not taunt_button.is_empty() and buffer.was_pressed(taunt_button, 1):
		_enter(State.TAUNT)
		return

	if _try_dashes():
		return

	var dir := buffer.direction()
	if dir >= 7:
		_superjump_queued = _superjump_input(buffer)
		_enter(State.PREJUMP)
		return

	var desired: State
	if dir == 1 or dir == 2 or dir == 3:
		desired = State.CROUCH
	elif dir == 6:
		desired = State.WALK_F
		fighter.walk(1.0)
	elif dir == 4:
		desired = State.WALK_B
		fighter.walk(-1.0)
	else:
		desired = State.IDLE
		fighter.velocity.x = 0.0
	if desired != state:
		_enter(desired)


## Marvel superjump: a down direction within the last 8 frames before up.
func _superjump_input(buffer: InputBuffer) -> bool:
	if fighter.data == null or not fighter.data.superjump_enabled:
		return false
	for i in range(1, 9):
		var dir := buffer.direction(i)
		if dir == 1 or dir == 2 or dir == 3:
			return true
	return false


func _try_dashes() -> bool:
	var buffer := fighter.input_buffer
	if fighter.data == null:
		return false
	var fresh_forward := buffer.direction() == 6 and buffer.direction(1) != 6
	var fresh_back := buffer.direction() == 4 and buffer.direction(1) != 4
	if fresh_forward and _dash_motion.matches(buffer):
		_enter(State.DASH)
		fighter.velocity.x = fighter.data.dash_speed * fighter.facing_sign()
		return true
	if fresh_back and _backdash_motion.matches(buffer):
		if fighter.backdash():
			_enter(State.BACKDASH)
		return true
	return false


func _tick_dash() -> void:
	var data := fighter.data
	fighter.velocity.x = data.dash_speed * fighter.facing_sign()
	if data.run_mode:
		if fighter.input_buffer != null and fighter.input_buffer.direction() != 6:
			_enter(State.IDLE)
	elif state_frames >= data.dash_frames:
		_enter(State.IDLE)


func _tick_backdash() -> void:
	if state_frames >= fighter.data.backdash_frames:
		_enter(State.IDLE)


func _tick_prejump() -> void:
	if state_frames < fighter.data.prejump_frames:
		return
	var dir := fighter.input_buffer.direction() if fighter.input_buffer != null else 8
	var drift := 0.0
	if dir == 9:
		drift = 1.0
	elif dir == 7:
		drift = -1.0
	fighter.velocity.x = drift * fighter.data.walk_speed * fighter.facing_sign()
	if _superjump_queued:
		fighter.velocity.y = fighter.data.superjump_velocity
		_superjump_queued = false
	else:
		fighter.velocity.y = fighter.data.jump_velocity
	_enter(State.AIR)


func _tick_air() -> void:
	var buffer := fighter.input_buffer
	if buffer == null:
		return
	# Air dash: double tap forward or back.
	var fresh_forward := buffer.direction() == 6 and buffer.direction(1) != 6
	var fresh_back := buffer.direction() == 4 and buffer.direction(1) != 4
	if fresh_forward and _dash_motion.matches(buffer) and _start_air_dash(true):
		return
	if fresh_back and _backdash_motion.matches(buffer) and _start_air_dash(false):
		return
	# Air jump: fresh up press.
	var up_now := buffer.direction() >= 7
	var up_before := buffer.direction(1) >= 7
	if up_now and not up_before and fighter.jump():
		var dir := buffer.direction()
		var drift := 1.0 if dir == 9 else (-1.0 if dir == 7 else 0.0)
		fighter.velocity.x = drift * fighter.data.walk_speed * fighter.facing_sign()
		_play(&"jump")
	# Fastfall: fresh down press while falling.
	if fighter.data != null and fighter.data.fastfall_speed > 0.0 \
			and fighter.velocity.y > 0.0:
		var down_now := buffer.direction() <= 3
		var down_before := buffer.direction(1) <= 3
		if down_now and not down_before:
			fighter.velocity.y = fighter.data.fastfall_speed
	if fighter.velocity.y >= 0 and state_frames > 1:
		_play_if_not(&"fall")


func _start_air_dash(forward: bool) -> bool:
	if not fighter.air_dash(forward):
		return false
	_enter(State.AIR_DASH)
	_play(&"airdash" if forward else &"airdash_b", &"airdash")
	return true


func _tick_air_dash() -> void:
	# Short fixed dash, then back to air control.
	if state_frames >= 12 or fighter.is_on_floor():
		_to_neutral()


# --- Attacks -----------------------------------------------------------------

func _on_move_detected(move: MoveData) -> void:
	if state in _NO_ACT_STATES:
		# Reversal buffer: hold the command and release it on the first
		# actionable frame (wakeup DP, reversal super).
		if reversal_window > 0:
			_queued_move = move
			_queued_frames = reversal_window
		return
	perform_move(move)


func _try_queued_move() -> bool:
	if _queued_move == null:
		return false
	var move := _queued_move
	_queued_move = null
	_queued_frames = 0
	return perform_move(move)


## Tries to perform a move right now (used by command detection, TagTeam
## assists, and AI). Honors cancel rules when already attacking.
func perform_move(move: MoveData) -> bool:
	if move == null or not fighter.can_cancel_into(move):
		return false
	_abort_move()
	if not fighter.begin_move(move):
		return false
	_enter(State.ATTACK)
	_move_frames = 0
	_hit_segment = -1
	_active_hitbox = _find_hitbox(move.hitbox_name)
	if move.animation != &"":
		_play(move.animation)
	move_started.emit(move)
	return true


func _find_hitbox(box_name: StringName) -> HitBox2D:
	for box in fighter.boxes:
		if box is HitBox2D and box.name == box_name:
			return box
	for box in fighter.boxes:
		if box is HitBox2D:
			return box
	return null


func _tick_attack() -> void:
	var move := fighter.current_move
	if move == null:
		_to_neutral()
		return
	_move_frames += 1

	var total := move.total_frames()
	if total <= 0:
		# No frame data: the animation is the timeline.
		if anim_player == null or not anim_player.is_playing():
			_finish_move()
		return

	var active_start := move.startup
	var active_end := move.startup + move.active

	if _move_frames > active_start and _move_frames <= active_end:
		_drive_active_window(move, active_start)
	elif _active_hitbox != null and _active_hitbox.is_active:
		_active_hitbox.is_active = false

	if _move_frames == active_start + 1 and move.self_velocity != Vector2.ZERO:
		fighter.velocity = Vector2(
			move.self_velocity.x * fighter.facing_sign(), move.self_velocity.y)

	if fighter.move_has_connected and fighter.input_buffer != null \
			and not fighter.is_airborne():
		if move.jump_cancelable:
			var buffer := fighter.input_buffer
			if buffer.direction() >= 7 and buffer.direction(1) < 7:
				_abort_move()
				fighter.end_move()
				_superjump_queued = _superjump_input(buffer)
				_enter(State.PREJUMP)
				return
		if move.dash_cancelable and _try_dashes():
			_abort_move()
			fighter.end_move()
			return

	if _move_frames >= total:
		_finish_move()


func _drive_active_window(move: MoveData, active_start: int) -> void:
	if _active_hitbox == null:
		return
	var segments := maxi(move.hits.size(), 1)
	var into_active := _move_frames - active_start - 1
	var segment := mini(into_active * segments / maxi(move.active, 1), segments - 1)
	if segment != _hit_segment:
		_hit_segment = segment
		if not move.hits.is_empty():
			_active_hitbox.hit_data = move.hits[segment]
		_active_hitbox.is_active = false
		_active_hitbox.is_active = true


func _finish_move() -> void:
	var move := fighter.current_move
	_abort_move()
	fighter.end_move()
	if move != null:
		move_ended.emit(move)
	_to_neutral()


func _abort_move() -> void:
	if _active_hitbox != null:
		_active_hitbox.is_active = false
		_active_hitbox = null
	_hit_segment = -1


# --- Stun & reaction states ---------------------------------------------------

func _on_hit_taken(_attacker: Fighter2D, data: HitData, blocked: bool) -> void:
	# Armor absorbs leave no stun behind; stay in the current state.
	if not fighter.in_stun():
		return
	_abort_move()
	fighter.end_move()
	if fighter.is_knocked_down():
		_enter(State.KNOCKDOWN)
	elif blocked:
		_enter(State.BLOCKSTUN)
	else:
		_enter(State.HITSTUN)
		if data.crumple_frames > 0 and not fighter.is_airborne():
			_play(&"crumple", &"hitstun")


func _on_knocked_down(hard: bool) -> void:
	_kd_hard = hard
	_abort_move()
	fighter.end_move()
	_enter(State.KNOCKDOWN)


func _tick_knockdown() -> void:
	if _kd_hard or not quick_rise_enabled:
		return
	var buffer := fighter.input_buffer
	if buffer != null and buffer.pressed_mask() != 0 \
			and fighter.knockdown_frames > quick_rise_frames:
		fighter.knockdown_frames = quick_rise_frames


func _on_got_up() -> void:
	# Back rise: holding back shifts the getup position.
	var buffer := fighter.input_buffer
	if buffer != null and back_rise_distance > 0.0:
		var dir := buffer.direction()
		if dir == 1 or dir == 4 or dir == 7:
			fighter.global_position.x -= back_rise_distance * fighter.facing_sign()
	_enter(State.GETUP)


func _on_stun_ended() -> void:
	if state in [State.HITSTUN, State.BLOCKSTUN, State.DIZZY, State.GUARD_CRUSH]:
		_to_neutral()


func _on_air_teched() -> void:
	_enter(State.AIR)


func _on_landed() -> void:
	if state == State.ATTACK and fighter.current_move != null \
			and (fighter.current_move.allowed_situations & MoveData.Situation.AIRBORNE) != 0:
		_finish_move()
	elif state == State.AIR or state == State.AIR_DASH:
		if fighter.data != null and fighter.data.landing_recovery_frames > 0:
			_enter(State.LANDING)
		else:
			_enter(State.IDLE)


func _on_forced_move(move: MoveData) -> void:
	if move != null:
		_enter(State.IDLE)  # Clear blockstun state before the counterattack.
		perform_move(move)


func _on_roman_canceled() -> void:
	_abort_move()
	_to_neutral()


func _on_burst(_gold: bool) -> void:
	_abort_move()
	fighter.end_move()
	_enter(State.AIR)


func _on_dizzied() -> void:
	_abort_move()
	fighter.end_move()
	_enter(State.DIZZY)


func _on_guard_broken() -> void:
	_abort_move()
	fighter.end_move()
	_enter(State.GUARD_CRUSH)


func _tick_dizzy() -> void:
	# Mash to recover.
	var buffer := fighter.input_buffer
	if buffer != null and dizzy_mash_recovery > 0 and buffer.pressed_mask() != 0:
		fighter.hitstun_frames = maxi(fighter.hitstun_frames - dizzy_mash_recovery, 1)


func _tick_timed_state() -> void:
	var duration := taunt_frames
	if state == State.GETUP:
		duration = getup_frames
	elif state == State.LANDING:
		duration = fighter.data.landing_recovery_frames if fighter.data != null else 0
	if state_frames >= duration:
		_enter(State.IDLE)


## Override in subclasses for character-specific states. Enter with
## [code]_enter(State.CUSTOM)[/code]; this runs every frame while in it.
func _on_custom_state() -> void:
	pass


# --- Animation helpers --------------------------------------------------------

func _play(anim: StringName, fallback: StringName = &"") -> void:
	if anim_player == null:
		return
	if anim_player.has_animation(anim):
		anim_player.play(anim)
	elif fallback != &"" and anim_player.has_animation(fallback):
		anim_player.play(fallback)


func _play_if_not(anim: StringName) -> void:
	if anim_player == null or not anim_player.has_animation(anim):
		return
	if anim_player.current_animation != String(anim):
		anim_player.play(anim)
