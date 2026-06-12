class_name Fighter2D
extends CharacterBody2D

## Base class for a fighting game character.
##
## Wires together the FightEngine systems: registers all descendant collision
## boxes, resolves incoming hits (guard, damage scaling, juggle, knockback,
## hitstop), tracks stun and knockdown, faces the opponent, and exposes
## signals for your state machine (LimboAI or otherwise) and UI to react to.
##
## Expected scene layout (children, any depth):
## - A flippable rig Node2D holding sprites and boxes (assign [member rig])
## - HurtBox2D / HitBox2D / PushBox2D nodes
## - Optional HealthComponent / MeterComponent / ComboTracker / InputBuffer /
##   CommandInterpreter (auto-created with defaults when not assigned)

signal hit_landed(victim: Fighter2D, data: HitData, blocked: bool)
signal hit_taken(attacker: Fighter2D, data: HitData, blocked: bool)
## This fighter teched a throw attempted by [param attacker].
signal teched_throw(attacker: Fighter2D)
## This fighter's throw got teched by [param victim].
signal throw_was_teched(victim: Fighter2D)
## This fighter absorbed a hit with armor (damage taken, no stun).
signal armor_absorbed(attacker: Fighter2D, data: HitData)
## This fighter pushblocked and shoved the opponent away.
signal pushblocked
## This fighter triggered a guard cancel; perform [param move] in your states.
signal alpha_countered(move: MoveData)
## A hit was blocked with barrier / Faultless Defense.
signal barrier_blocked_hit(data: HitData)
## Roman/Rapid cancel performed; return to neutral in your states.
signal roman_canceled
## This fighter parried a hit.
signal parried(attacker: Fighter2D, data: HitData)
## This fighter's attack got parried.
signal got_parried(victim: Fighter2D)
## A whiffed parry window just ended; the no-block recovery has started.
signal parry_whiffed
## This fighter was hit by a snapback and must tag out (TagTeam handles it).
signal snapped_back
## This fighter got counter hit (was hit during its own attack).
signal counter_hit(attacker: Fighter2D, data: HitData)
## This fighter blocked within the instant block window.
signal instant_blocked
signal ground_bounced
signal wall_bounced
## This fighter recovered in the air after hitstun.
signal air_teched
signal air_dashed(forward: bool)
signal backdashed
signal stun_ended
signal knocked_down(hard: bool)
signal got_up
signal landed
signal side_switched(facing_right: bool)
signal died

@export var data: FighterData
@export var opponent: Fighter2D
@export var team: int = -1
## Node2D that gets X-flipped when the fighter turns around. Put sprites,
## hitboxes and hurtboxes under it so attacks always come out facing forward.
@export var rig: Node2D
@export var auto_face_opponent: bool = true

@export_group("Components")
@export var input_buffer: InputBuffer
@export var health: HealthComponent
@export var meter: MeterComponent
@export var combo_tracker: ComboTracker
## Optional: Barrier / Faultless Defense (see BarrierComponent).
@export var barrier: BarrierComponent
## Optional: Overdrive / install state (see OverdriveComponent).
@export var overdrive: OverdriveComponent
## Optional: Burst (see BurstSystem).
@export var burst: BurstSystem

@export_group("Stun tuning (frames)")
@export var knockdown_frames_soft: int = 25
@export var knockdown_frames_hard: int = 45
## Friction applied to sliding knockdowns, in px/s lost per frame.
@export var knockdown_friction: float = 30.0
## Intangibility granted when getting up from a knockdown (okizeme dial:
## 0 = meaty everything, lots = wakeup is sacred).
@export var wakeup_invuln_frames: int = 0

@export_group("Air tech")
## Automatically recover in the air when air hitstun/untech time runs out
## (Marvel/Melty style). Off = stay juggled until landing (MUGEN style).
@export var air_tech_enabled: bool = true
## Tech velocity; X is steered by held direction (forward/neutral/back).
@export var air_tech_velocity: Vector2 = Vector2(150, -250)
## Intangibility granted on air tech, in frames.
@export var tech_invuln_frames: int = 10

@export_group("Counter hits")
## Damage multiplier when the victim was hit out of its own attack.
@export var counter_hit_multiplier: float = 1.2
## Extra hitstun on counter hit, in frames.
@export var counter_hit_bonus_hitstun: int = 4

@export_group("Instant block")
## Blocking within this many frames of holding back counts as an instant
## block (GGXX style). 0 = disabled.
@export var instant_block_window: int = 0
## Blockstun shaved off by an instant block, in frames.
@export var instant_block_advantage: int = 4
## Meter awarded for an instant block.
@export var instant_block_meter_bonus: int = 50

@export_group("Alpha counter")
## Guard cancel attack (SF Alpha counter / GG Dead Angle / BB Counter
## Assault): during blockstun, pressing the trigger spends meter, cancels
## blockstun, and emits [signal alpha_countered] with the configured move —
## your state machine performs it.
@export var alpha_counter_enabled: bool = false
## Move (from FighterData.moves) used as the counterattack.
@export var alpha_counter_move_id: StringName = &""
## All of these pressed together (3-frame window) during blockstun trigger it.
@export var alpha_counter_buttons: PackedStringArray = PackedStringArray(["m", "h"])
## Optional motion requirement (e.g. 6 + buttons: sequence [6]).
@export var alpha_counter_motion: MotionInput
@export var alpha_counter_meter_cost: int = 1000
@export var alpha_counter_invuln_frames: int = 12

@export_group("Roman cancel")
## Roman / Rapid Cancel: spend meter to cancel the current move back to
## neutral. Your state machine returns to idle on [signal roman_canceled].
@export var roman_cancel_enabled: bool = false
## All of these pressed together (3-frame window) trigger it. Leave empty
## to only cancel via [method try_roman_cancel] from your states.
@export var roman_cancel_buttons: PackedStringArray = PackedStringArray(["m", "h", "s"])
@export var roman_cancel_meter_cost: int = 1000
## GGXX red-RC rule: the move must have hit or been blocked. Off = yellow
## RC anything, anytime (FRC everything — kusoge dial).
@export var roman_cancel_requires_contact: bool = true
## Brief opponent freeze on the cancel (the RC pop).
@export var roman_cancel_freeze: int = 10

@export_group("Parry / shield")
## Third Strike parry / Melty shield: tap the trigger to open a window;
## a hit arriving inside it is negated with a freeze and meter reward.
@export var parry_enabled: bool = false
## All of these tapped together attempt a parry.
@export var parry_buttons: PackedStringArray = PackedStringArray(["s"])
@export var parry_window: int = 8
## Frames you cannot block after a whiffed parry window (the risk part).
@export var parry_whiff_recovery: int = 14
## Freeze applied to both fighters on a successful parry (the clink).
@export var parry_freeze: int = 10
@export var parry_meter_gain: int = 100
@export var air_parry_allowed: bool = true
## 3S rule: standing parries can't take lows, crouching parries can't take
## highs. Off = one parry catches everything.
@export var stance_parry: bool = true

@export_group("Corner push")
## When a cornered victim can't be pushed back any further, the attacker is
## pushed away instead (IKEMEN corner push). Requires stage walls, or
## FightCamera2D limits acting as the corner.
@export var corner_push_enabled: bool = true
## Fraction of the victim's pushback transferred to the attacker.
@export var corner_push_factor: float = 1.0
## How close to a camera limit counts as cornered, in pixels.
@export var corner_margin: float = 24.0

@export_group("Throw tech")
@export var tech_enabled: bool = true
## Buttons that tech throws (any of them, pressed within the tech window).
@export var tech_buttons: PackedStringArray = PackedStringArray(["a"])
## Frames before the throw connects in which a tech input counts.
@export var tech_window: int = 8
## Pushback applied to both fighters on a successful tech, in px/s.
@export var tech_pushback: float = 250.0

@export_group("Pushblock")
## Advancing guard: pressing the pushblock buttons during blockstun shoves
## the opponent away.
@export var pushblock_enabled: bool = false
## All of these must be pressed (within a 3-frame window) to pushblock.
@export var pushblock_buttons: PackedStringArray = PackedStringArray(["a", "b"])
@export var pushblock_force: float = 600.0
@export var pushblock_meter_cost: int = 0

@export_group("Armor")
## Damage multiplier applied to hits absorbed by armor.
@export var armor_damage_multiplier: float = 0.5

@export_group("Kusoge dials")
## Throws connect even against airborne or stunned opponents (command-grab
## loops, throw combos — the good jank).
@export var throws_ignore_state: bool = false
## Always block when blocking is possible, regardless of stick position.
## Meant for training dummies, but also a legitimately terrible mechanic.
@export var auto_block: bool = false

var facing_right: bool = true:
	set(value):
		if facing_right == value:
			return
		facing_right = value
		if rig != null:
			rig.scale.x = absf(rig.scale.x) * (1.0 if value else -1.0)
		if input_buffer != null:
			input_buffer.facing_right = value
		side_switched.emit(value)

var hitstun_frames: int = 0
var blockstun_frames: int = 0
var knockdown_frames: int = 0
## Crouching state. Updated from the input buffer each frame when one is
## assigned; otherwise drive it from your state machine.
var crouching: bool = false
## The move currently being performed, set by your state machine via
## [method begin_move] / [method end_move].
var current_move: MoveData = null
## Whether the current move has touched the opponent (hit OR block).
## Used by chain/cancel rules; reset by [method begin_move].
var move_has_connected: bool = false
## Remaining armor hits. Set this from your states (e.g. during a move's
## startup) to absorb that many hits without taking stun or knockback.
var armor_hits: int = 0
## Frames of full intangibility left (backdashes, techs, wakeup invuln).
var intangible_frames: int = 0
## All collision boxes registered under this fighter.
var boxes: Array[CollisionBox2D] = []

var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

var _pending_knockdown: int = HitData.KnockdownType.NONE
var _was_airborne: bool = false
var _air_jumps_left: int = 0
var _air_dashes_left: int = 0
var _pushblock_cooldown: int = 0
var _parry_window_left: int = 0
var _parry_recovery_left: int = 0
var _last_hit: HitData = null
var _pending_ground_bounce: bool = false
var _pending_wall_bounce: bool = false
var _sliding_knockdown: bool = false


func _ready() -> void:
	if health == null:
		health = HealthComponent.new()
		add_child(health)
	if meter == null:
		meter = MeterComponent.new()
		add_child(meter)
	if combo_tracker == null:
		combo_tracker = ComboTracker.new()
		add_child(combo_tracker)

	if data != null:
		health.max_health = data.max_health
		health.defense = data.defense
		health.reset()

	health.died.connect(func() -> void: died.emit())
	boxes.clear()
	_register_boxes(self)

	if input_buffer != null:
		input_buffer.facing_right = facing_right


func _register_boxes(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionBox2D:
			var box := child as CollisionBox2D
			box.combatant = self
			box.team = team
			boxes.append(box)
			if box is HurtBox2D:
				(box as HurtBox2D).was_hit.connect(_on_hurtbox_hit)
		_register_boxes(child)


## Benches or fields the fighter (tag team systems). Benched fighters are
## hidden, stop processing, and have every box deactivated. On re-enable,
## hurt and push boxes come back; hitboxes stay off (animations drive those).
func set_combat_enabled(enabled: bool) -> void:
	visible = enabled
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	for box in boxes:
		if enabled:
			box.is_active = box is HurtBox2D or box is PushBox2D
		else:
			box.is_active = false


func _physics_process(delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_frozen(self):
		return

	_update_stun()
	_update_crouching()
	_update_facing()
	_check_pushblock()
	_check_alpha_counter()
	_check_parry_input()
	_check_roman_cancel_input()
	if barrier != null:
		barrier.frame_tick(_is_holding_barrier())

	if not is_on_floor():
		var scale_g := data.gravity_scale if data != null else 1.0
		velocity.y += gravity * scale_g * delta
	else:
		_air_jumps_left = data.air_jumps if data != null else 0
		_air_dashes_left = data.air_dashes if data != null else 0

	var pre_move_vx := velocity.x
	move_and_slide()
	_check_wall_bounce(pre_move_vx)
	_check_landing()


# --- State queries -----------------------------------------------------------

func is_airborne() -> bool:
	return not is_on_floor()


func in_hitstun() -> bool:
	return hitstun_frames > 0


func in_blockstun() -> bool:
	return blockstun_frames > 0


func is_knocked_down() -> bool:
	return knockdown_frames > 0


func in_stun() -> bool:
	return in_hitstun() or in_blockstun() or is_knocked_down()


func is_attacking() -> bool:
	return current_move != null


func can_act() -> bool:
	return not in_stun() and not is_attacking() and not (health != null and health.is_dead)


func facing_sign() -> float:
	return 1.0 if facing_right else -1.0


## Bitmask of MoveData.Situation flags describing the current situation.
func situation_flags() -> int:
	if is_airborne():
		return MoveData.Situation.AIRBORNE
	if crouching:
		return MoveData.Situation.CROUCHING
	return MoveData.Situation.STANDING


# --- Movement helpers (call from your states) --------------------------------

## Walk along X. [param direction] is facing-relative: 1 = forward, -1 = back.
func walk(direction: float) -> void:
	if data == null:
		return
	var speed := data.walk_speed if direction > 0.0 else data.back_walk_speed
	velocity.x = direction * speed * facing_sign()


func jump() -> bool:
	if data == null:
		return false
	if is_on_floor():
		velocity.y = data.jump_velocity
		return true
	if _air_jumps_left > 0:
		_air_jumps_left -= 1
		velocity.y = data.jump_velocity
		return true
	return false


## Air dash (anime mobility). Kills vertical momentum on use.
## Returns false when grounded or out of air dashes.
func air_dash(forward: bool = true) -> bool:
	if data == null or is_on_floor() or _air_dashes_left <= 0:
		return false
	_air_dashes_left -= 1
	velocity.x = (1.0 if forward else -1.0) * facing_sign() * data.air_dash_speed
	velocity.y = 0.0
	air_dashed.emit(forward)
	return true


## Backdash with startup intangibility (anime backdash).
func backdash() -> bool:
	if data == null or not is_on_floor():
		return false
	velocity.x = -facing_sign() * data.backdash_speed
	intangible_frames = maxi(intangible_frames, data.backdash_invuln_frames)
	backdashed.emit()
	return true


# --- Move bookkeeping --------------------------------------------------------

## Checks situation and meter requirements for a move.
func can_perform(move: MoveData) -> bool:
	if move == null or in_stun():
		return false
	if (move.allowed_situations & situation_flags()) == 0:
		return false
	if move.meter_cost > 0 and (meter == null or meter.value < move.meter_cost):
		return false
	return true


## Marks the move as active and pays its meter cost. Returns false if it
## couldn't be paid for. Call from your attack state's enter.
func begin_move(move: MoveData) -> bool:
	if move.meter_cost > 0 and not meter.try_spend(move.meter_cost):
		return false
	current_move = move
	move_has_connected = false
	return true


func end_move() -> void:
	current_move = null
	move_has_connected = false


## Whether the current move may cancel into [param move] right now, using
## the character's ChainRules (magic series, reverse beat, category
## cancels) plus explicit MoveData.cancels_into routes. With no move active
## it falls back to a plain [method can_perform] check.
func can_cancel_into(move: MoveData) -> bool:
	if not can_perform(move):
		return false
	if current_move == null:
		return true
	var rules := data.chain_rules if data != null else null
	if rules != null:
		return rules.can_chain(current_move, move, move_has_connected)
	if not move_has_connected:
		return false
	if move.id != &"" and current_move.cancels_into.has(move.id):
		return true
	for tag in move.tags:
		if current_move.cancels_into.has(tag):
			return true
	return false


# --- Guard -------------------------------------------------------------------

func is_holding_back() -> bool:
	if auto_block:
		return true
	if input_buffer == null:
		return false
	var dir := input_buffer.direction()
	return dir == 1 or dir == 4 or dir == 7


func can_block(hit: HitData) -> bool:
	if hit.guard_height == HitData.GuardHeight.UNBLOCKABLE:
		return false
	if hit.hit_class == HitData.HitClass.THROW:
		return false
	if is_knocked_down() or in_hitstun():
		return false
	# Whiffed parry: guard is locked out.
	if _parry_recovery_left > 0:
		return false
	# Blockstun keeps guard up; otherwise the stick must be held back.
	if not in_blockstun() and not is_holding_back():
		return false
	if is_airborne():
		if hit.air_blockable:
			return true
		return _is_holding_barrier() and barrier.air_blocks_everything
	match hit.guard_height:
		HitData.GuardHeight.HIGH:
			return not crouching
		HitData.GuardHeight.LOW:
			return crouching
	return true


# --- Hit resolution ----------------------------------------------------------

func _on_hurtbox_hit(hitbox: HitBox2D) -> void:
	receive_hit(hitbox)


func receive_hit(hitbox: HitBox2D) -> void:
	var hit := hitbox.effective_hit_data()
	var attacker := hitbox.combatant as Fighter2D

	if health != null and health.is_dead:
		return
	if intangible_frames > 0:
		return
	if is_knocked_down() and not hit.otg:
		return
	if hit.hit_class == HitData.HitClass.THROW and not throws_ignore_state:
		if in_stun() or is_airborne():
			return
	if hit.hit_class == HitData.HitClass.THROW and _teched_throw():
		var tech_away := _away_sign(hitbox)
		velocity.x = tech_pushback * tech_away
		if attacker != null:
			attacker.velocity.x = tech_pushback * -tech_away
			attacker.throw_was_teched.emit(self)
		teched_throw.emit(attacker)
		return
	if combo_tracker != null:
		if not combo_tracker.can_extend():
			return
		if is_airborne() and in_hitstun() \
				and not combo_tracker.try_spend_juggle(hit.juggle_cost):
			return

	if _try_parry(hit, attacker):
		return

	var blocked := can_block(hit)
	var away := _away_sign(hitbox)

	if FightClock.active != null:
		FightClock.active.hitstop([self, attacker], hit.hitstop)

	if not blocked and armor_hits > 0 and hit.hit_class != HitData.HitClass.THROW:
		armor_hits -= 1
		if health != null:
			health.take_hit(hit, armor_damage_multiplier)
		armor_absorbed.emit(attacker, hit)
		_spawn_hit_effect(hit, hitbox)
		hit_taken.emit(attacker, hit, false)
		if attacker != null:
			attacker.confirm_hit(self, hit, false)
		return

	if blocked:
		_resolve_block(hit, away)
	else:
		_resolve_clean_hit(hit, attacker, away)
	_apply_corner_push(attacker, away)

	_spawn_hit_effect(hit, hitbox)
	hit_taken.emit(attacker, hit, blocked)
	if attacker != null:
		attacker.confirm_hit(self, hit, blocked)


func _resolve_block(hit: HitData, away: float) -> void:
	blockstun_frames = hit.blockstun
	if _is_instant_block():
		blockstun_frames = maxi(blockstun_frames - instant_block_advantage, 1)
		if meter != null:
			meter.gain(instant_block_meter_bonus)
		instant_blocked.emit()

	var pushback := hit.block_pushback
	var barrier_on := _is_holding_barrier()
	if barrier_on:
		barrier.on_block(hit)
		pushback *= barrier.pushback_multiplier
		barrier_blocked_hit.emit(hit)

	if health != null:
		var chip_hit := hit
		if barrier_on and (barrier.negates_chip or barrier.protects_guard_gauge):
			chip_hit = hit.duplicate() as HitData
			if barrier.negates_chip:
				chip_hit.chip_damage = 0
			if barrier.protects_guard_gauge:
				chip_hit.guard_damage = 0
		health.take_chip(chip_hit)
	if meter != null:
		meter.gain(hit.meter_gain_victim)
	velocity.x = pushback * away


func _is_holding_barrier() -> bool:
	if barrier == null or not barrier.is_usable() or input_buffer == null:
		return false
	for button in barrier.barrier_buttons:
		if not input_buffer.is_held(button):
			return false
	return true


func _is_instant_block() -> bool:
	if instant_block_window <= 0 or input_buffer == null or auto_block:
		return false
	var back_frames := input_buffer.consecutive_direction_frames(
		PackedInt32Array([1, 4, 7])
	)
	return back_frames > 0 and back_frames <= instant_block_window


func _resolve_clean_hit(hit: HitData, attacker: Fighter2D, away: float) -> void:
	# A hit on a non-stunned victim starts a fresh combo.
	if combo_tracker != null and not in_hitstun():
		combo_tracker.drop()

	var is_counter := is_attacking()
	var scaling := 1.0
	if combo_tracker != null:
		scaling = combo_tracker.damage_multiplier()
	if attacker != null and attacker.data != null:
		scaling *= attacker.data.attack
	if attacker != null and attacker.overdrive != null and attacker.overdrive.is_active:
		scaling *= attacker.overdrive.attack_multiplier
	if overdrive != null and overdrive.is_active:
		scaling *= overdrive.defense_multiplier
	if is_counter:
		scaling *= counter_hit_multiplier

	var dealt := 0
	if health != null:
		dealt = health.take_hit(hit, scaling)
	if combo_tracker != null:
		combo_tracker.register_hit(attacker, dealt)
	if meter != null:
		meter.gain(hit.meter_gain_victim)

	_last_hit = hit
	hitstun_frames = hit.hitstun
	blockstun_frames = 0

	if is_airborne() or hit.launch != Vector2.ZERO:
		var launch := hit.launch if hit.launch != Vector2.ZERO else hit.knockback
		velocity.x = launch.x * away
		if launch.y != 0.0:
			velocity.y = launch.y
		if hit.untech_frames > 0:
			hitstun_frames = hit.untech_frames
	else:
		velocity.x = hit.knockback.x * away
		if hit.knockback.y != 0.0:
			velocity.y = hit.knockback.y

	if is_counter:
		hitstun_frames += counter_hit_bonus_hitstun
		counter_hit.emit(attacker, hit)

	_pending_ground_bounce = hit.ground_bounce
	_pending_wall_bounce = hit.wall_bounce
	_pending_knockdown = hit.knockdown
	if not is_airborne() and hit.knockdown != HitData.KnockdownType.NONE \
			and hit.launch == Vector2.ZERO:
		_enter_knockdown(hit.knockdown == HitData.KnockdownType.HARD)

	if hit.instant_kill and health != null:
		health.kill()
	if hit.snapback:
		snapped_back.emit()


## Called on the attacker by the victim once a hit has fully resolved.
func confirm_hit(victim: Fighter2D, hit: HitData, blocked: bool) -> void:
	move_has_connected = true
	if meter != null:
		meter.gain(hit.meter_gain_on_block if blocked else hit.meter_gain_attacker)
	hit_landed.emit(victim, hit, blocked)


func _teched_throw() -> bool:
	if not tech_enabled or input_buffer == null or in_stun():
		return false
	for button in tech_buttons:
		if input_buffer.was_pressed(button, tech_window):
			return true
	return false


func _check_pushblock() -> void:
	if _pushblock_cooldown > 0:
		_pushblock_cooldown -= 1
		return
	if not pushblock_enabled or not in_blockstun() or input_buffer == null:
		return
	if opponent == null or pushblock_buttons.is_empty():
		return
	var pressed_now := false
	for button in pushblock_buttons:
		if not input_buffer.was_pressed(button, 3):
			return
		if input_buffer.was_pressed(button, 1):
			pressed_now = true
	if not pressed_now:
		return
	if pushblock_meter_cost > 0 \
			and (meter == null or not meter.try_spend(pushblock_meter_cost)):
		return
	var away := signf(opponent.global_position.x - global_position.x)
	if away == 0.0:
		away = facing_sign()
	opponent.velocity.x = pushblock_force * away
	_pushblock_cooldown = 20
	pushblocked.emit()


## True when every button in [param button_set] was pressed within the last
## 3 frames, with at least one of them this frame (plinked multi-presses ok).
func _combo_pressed(button_set: PackedStringArray) -> bool:
	if input_buffer == null or button_set.is_empty():
		return false
	var pressed_now := false
	for button in button_set:
		if not input_buffer.was_pressed(button, 3):
			return false
		if input_buffer.was_pressed(button, 1):
			pressed_now = true
	return pressed_now


func _check_parry_input() -> void:
	if _parry_recovery_left > 0:
		_parry_recovery_left -= 1
		return
	if _parry_window_left > 0:
		_parry_window_left -= 1
		if _parry_window_left == 0:
			_parry_recovery_left = parry_whiff_recovery
			parry_whiffed.emit()
		return
	if not parry_enabled or in_stun() or is_attacking():
		return
	if _combo_pressed(parry_buttons):
		_parry_window_left = parry_window


func _try_parry(hit: HitData, attacker: Fighter2D) -> bool:
	if _parry_window_left <= 0:
		return false
	if hit.hit_class == HitData.HitClass.THROW or hit.unparryable:
		return false
	if is_airborne() and not air_parry_allowed:
		return false
	if stance_parry and not is_airborne():
		if hit.guard_height == HitData.GuardHeight.LOW and not crouching:
			return false
		if hit.guard_height == HitData.GuardHeight.HIGH and crouching:
			return false
	_parry_window_left = 0
	_parry_recovery_left = 0
	if FightClock.active != null:
		FightClock.active.hitstop([self, attacker], parry_freeze)
	if meter != null:
		meter.gain(parry_meter_gain)
	parried.emit(attacker, hit)
	if attacker != null:
		attacker.got_parried.emit(self)
	return true


func _check_roman_cancel_input() -> void:
	if roman_cancel_enabled and is_attacking() \
			and _combo_pressed(roman_cancel_buttons):
		try_roman_cancel()


## Roman / Rapid Cancel the current move. Returns true on success; your
## state machine returns to neutral on [signal roman_canceled].
func try_roman_cancel() -> bool:
	if not is_attacking():
		return false
	if roman_cancel_requires_contact and not move_has_connected:
		return false
	if roman_cancel_meter_cost > 0 \
			and (meter == null or not meter.try_spend(roman_cancel_meter_cost)):
		return false
	end_move()
	if roman_cancel_freeze > 0 and FightClock.active != null and opponent != null:
		FightClock.active.hitstop([opponent], roman_cancel_freeze)
	roman_canceled.emit()
	return true


func _check_alpha_counter() -> void:
	if not alpha_counter_enabled or not in_blockstun() or input_buffer == null:
		return
	var pressed_now := false
	for button in alpha_counter_buttons:
		if not input_buffer.was_pressed(button, 3):
			return
		if input_buffer.was_pressed(button, 1):
			pressed_now = true
	if not pressed_now:
		return
	if alpha_counter_motion != null and not alpha_counter_motion.matches(input_buffer):
		return
	if alpha_counter_meter_cost > 0 \
			and (meter == null or not meter.try_spend(alpha_counter_meter_cost)):
		return
	blockstun_frames = 0
	intangible_frames = maxi(intangible_frames, alpha_counter_invuln_frames)
	var move: MoveData = null
	if data != null and alpha_counter_move_id != &"":
		move = data.get_move(alpha_counter_move_id)
	alpha_countered.emit(move)


## Transfers pushback to the attacker when the victim is cornered.
func _apply_corner_push(attacker: Fighter2D, away: float) -> void:
	if not corner_push_enabled or attacker == null or is_airborne():
		return
	if not _is_cornered(away):
		return
	attacker.velocity.x = absf(velocity.x) * corner_push_factor * -away
	velocity.x = 0.0


func _is_cornered(push_direction: float) -> bool:
	if is_on_wall():
		return true
	var cam := FightCamera2D.active
	if cam == null:
		return false
	if push_direction < 0.0:
		return global_position.x <= cam.limit_left + corner_margin
	return global_position.x >= cam.limit_right - corner_margin


func _away_sign(hitbox: HitBox2D) -> float:
	var source := hitbox.combatant as Node2D
	var from_x := source.global_position.x if source != null else hitbox.global_position.x
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing_sign()
	return away


func _spawn_hit_effect(hit: HitData, hitbox: HitBox2D) -> void:
	if hit.shake_intensity > 0.0 and FightCamera2D.active != null:
		FightCamera2D.active.shake(hit.shake_intensity, hit.shake_frames)
	if hit.effect_scene != null:
		var fx := hit.effect_scene.instantiate()
		if fx is Node2D:
			(fx as Node2D).global_position = \
					hitbox.global_position.lerp(global_position, 0.5)
		get_tree().current_scene.add_child.call_deferred(fx)
	if hit.hit_sound != null:
		var player := AudioStreamPlayer.new()
		player.stream = hit.hit_sound
		player.finished.connect(player.queue_free)
		add_child(player)
		player.play()


# --- Frame upkeep ------------------------------------------------------------

func _update_stun() -> void:
	if intangible_frames > 0:
		intangible_frames -= 1

	if knockdown_frames > 0:
		knockdown_frames -= 1
		if _sliding_knockdown:
			velocity.x = move_toward(velocity.x, 0.0, knockdown_friction)
		if knockdown_frames == 0:
			_sliding_knockdown = false
			velocity.x = 0.0
			intangible_frames = maxi(intangible_frames, wakeup_invuln_frames)
			got_up.emit()
		return

	if hitstun_frames > 0:
		hitstun_frames -= 1
		if hitstun_frames == 0:
			if is_airborne():
				if air_tech_enabled:
					_air_tech()
				else:
					# MUGEN style: stay juggled until landing.
					hitstun_frames = 1
			else:
				if combo_tracker != null:
					combo_tracker.drop()
				stun_ended.emit()

	if blockstun_frames > 0:
		blockstun_frames -= 1
		if blockstun_frames == 0:
			stun_ended.emit()


func _update_crouching() -> void:
	if input_buffer == null or in_stun() or is_attacking():
		return
	if is_on_floor():
		var dir := input_buffer.direction()
		crouching = dir == 1 or dir == 2 or dir == 3
	else:
		crouching = false


func _update_facing() -> void:
	if not auto_face_opponent or opponent == null:
		return
	if in_stun() or is_attacking() or not is_on_floor():
		return
	facing_right = opponent.global_position.x >= global_position.x


func _check_landing() -> void:
	var airborne := not is_on_floor()
	if _was_airborne and not airborne:
		if in_hitstun() and _pending_ground_bounce and _try_ground_bounce():
			_was_airborne = false
			return
		if _pending_knockdown != HitData.KnockdownType.NONE and in_hitstun():
			hitstun_frames = 0
			if combo_tracker != null:
				combo_tracker.drop()
			_enter_knockdown(_pending_knockdown == HitData.KnockdownType.HARD)
		_pending_knockdown = HitData.KnockdownType.NONE
		_pending_ground_bounce = false
		_pending_wall_bounce = false
		landed.emit()
	_was_airborne = airborne


func _try_ground_bounce() -> bool:
	_pending_ground_bounce = false
	if _last_hit == null:
		return false
	if combo_tracker != null and not combo_tracker.try_use_ground_bounce():
		return false
	velocity.y = _last_hit.ground_bounce_velocity
	hitstun_frames = maxi(hitstun_frames, _last_hit.bounce_hitstun)
	ground_bounced.emit()
	return true


func _check_wall_bounce(pre_move_vx: float) -> void:
	if not in_hitstun() or not _pending_wall_bounce:
		return
	if absf(pre_move_vx) < 1.0:
		return
	if not _is_cornered(signf(pre_move_vx)):
		return
	_pending_wall_bounce = false
	if _last_hit == null:
		return
	if combo_tracker != null and not combo_tracker.try_use_wall_bounce():
		return
	velocity.x = -pre_move_vx * _last_hit.wall_bounce_factor
	if velocity.y > 0.0:
		velocity.y = 0.0
	hitstun_frames = maxi(hitstun_frames, _last_hit.bounce_hitstun)
	wall_bounced.emit()


func _air_tech() -> void:
	var drift := 0.0
	if input_buffer != null:
		var dir := input_buffer.direction()
		if dir == 6 or dir == 3 or dir == 9:
			drift = 1.0
		elif dir == 4 or dir == 1 or dir == 7:
			drift = -1.0
	velocity = Vector2(air_tech_velocity.x * drift * facing_sign(), air_tech_velocity.y)
	intangible_frames = maxi(intangible_frames, tech_invuln_frames)
	_pending_knockdown = HitData.KnockdownType.NONE
	_pending_ground_bounce = false
	_pending_wall_bounce = false
	if combo_tracker != null:
		combo_tracker.drop()
	air_teched.emit()
	stun_ended.emit()


func _enter_knockdown(hard: bool) -> void:
	knockdown_frames = knockdown_frames_hard if hard else knockdown_frames_soft
	hitstun_frames = 0
	blockstun_frames = 0
	_pending_knockdown = HitData.KnockdownType.NONE
	_sliding_knockdown = _last_hit != null and _last_hit.sliding_knockdown
	if not _sliding_knockdown:
		velocity.x = 0.0
	knocked_down.emit(hard)


## Resets per-round state. Called by RoundManager between rounds.
func reset_for_round() -> void:
	if health != null:
		health.reset()
	if combo_tracker != null:
		combo_tracker.reset()
	hitstun_frames = 0
	blockstun_frames = 0
	knockdown_frames = 0
	intangible_frames = 0
	armor_hits = 0
	current_move = null
	velocity = Vector2.ZERO
	_pending_knockdown = HitData.KnockdownType.NONE
	_pending_ground_bounce = false
	_pending_wall_bounce = false
	_sliding_knockdown = false
	_last_hit = null


# --- Rollback / save-state support --------------------------------------------

## Captures this fighter's gameplay state. Together with the component
## save_state() methods (health, meter, combo) and FightClock, this is the
## state set a rollback implementation or training-mode save state needs.
## Restoring animation/state-machine pose is your state machine's job —
## listen for load via [StateSnapshotter].
func save_state() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"facing_right": facing_right,
		"crouching": crouching,
		"hitstun": hitstun_frames,
		"blockstun": blockstun_frames,
		"knockdown": knockdown_frames,
		"intangible": intangible_frames,
		"armor": armor_hits,
		"air_jumps_left": _air_jumps_left,
		"air_dashes_left": _air_dashes_left,
		"pushblock_cooldown": _pushblock_cooldown,
		"parry_window_left": _parry_window_left,
		"parry_recovery_left": _parry_recovery_left,
		"pending_knockdown": _pending_knockdown,
		"pending_ground_bounce": _pending_ground_bounce,
		"pending_wall_bounce": _pending_wall_bounce,
		"sliding_knockdown": _sliding_knockdown,
		"was_airborne": _was_airborne,
		"last_hit": _last_hit,
		"current_move_id": current_move.id if current_move != null else &"",
		"move_has_connected": move_has_connected,
		"health": health.save_state() if health != null else {},
		"meter": meter.save_state() if meter != null else {},
		"combo": combo_tracker.save_state() if combo_tracker != null else {},
		"input": input_buffer.save_state() if input_buffer != null else {},
		"barrier": barrier.save_state() if barrier != null else {},
		"overdrive": overdrive.save_state() if overdrive != null else {},
		"burst": burst.save_state() if burst != null else {},
	}


func load_state(state: Dictionary) -> void:
	global_position = state["position"]
	velocity = state["velocity"]
	facing_right = state["facing_right"]
	crouching = state["crouching"]
	hitstun_frames = state["hitstun"]
	blockstun_frames = state["blockstun"]
	knockdown_frames = state["knockdown"]
	intangible_frames = state["intangible"]
	armor_hits = state["armor"]
	_air_jumps_left = state["air_jumps_left"]
	_air_dashes_left = state["air_dashes_left"]
	_pushblock_cooldown = state["pushblock_cooldown"]
	_parry_window_left = state["parry_window_left"]
	_parry_recovery_left = state["parry_recovery_left"]
	_pending_knockdown = state["pending_knockdown"]
	_pending_ground_bounce = state["pending_ground_bounce"]
	_pending_wall_bounce = state["pending_wall_bounce"]
	_sliding_knockdown = state["sliding_knockdown"]
	_was_airborne = state["was_airborne"]
	_last_hit = state["last_hit"]
	var move_id: StringName = state["current_move_id"]
	current_move = data.get_move(move_id) if (data != null and move_id != &"") else null
	move_has_connected = state["move_has_connected"]
	if health != null:
		health.load_state(state["health"])
	if meter != null:
		meter.load_state(state["meter"])
	if combo_tracker != null:
		combo_tracker.load_state(state["combo"])
	if input_buffer != null:
		input_buffer.load_state(state["input"])
	if barrier != null:
		barrier.load_state(state["barrier"])
	if overdrive != null:
		overdrive.load_state(state["overdrive"])
	if burst != null:
		burst.load_state(state["burst"])
