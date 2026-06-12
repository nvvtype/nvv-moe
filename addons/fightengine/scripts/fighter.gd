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

@export_group("Stun tuning (frames)")
@export var knockdown_frames_soft: int = 25
@export var knockdown_frames_hard: int = 45

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

var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

var _pending_knockdown: int = HitData.KnockdownType.NONE
var _was_airborne: bool = false
var _air_jumps_left: int = 0


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
	_register_boxes(self)

	if input_buffer != null:
		input_buffer.facing_right = facing_right


func _register_boxes(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionBox2D:
			var box := child as CollisionBox2D
			box.combatant = self
			box.team = team
			if box is HurtBox2D:
				(box as HurtBox2D).was_hit.connect(_on_hurtbox_hit)
		_register_boxes(child)


func _physics_process(delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_frozen(self):
		return

	_update_stun()
	_update_crouching()
	_update_facing()

	if not is_on_floor():
		var scale_g := data.gravity_scale if data != null else 1.0
		velocity.y += gravity * scale_g * delta
	else:
		_air_jumps_left = data.air_jumps if data != null else 0

	move_and_slide()
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
	return true


func end_move() -> void:
	current_move = null


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
	# Blockstun keeps guard up; otherwise the stick must be held back.
	if not in_blockstun() and not is_holding_back():
		return false
	if is_airborne():
		return hit.air_blockable
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
	if is_knocked_down() and not hit.otg:
		return
	if hit.hit_class == HitData.HitClass.THROW and not throws_ignore_state:
		if in_stun() or is_airborne():
			return
	if combo_tracker != null:
		if not combo_tracker.can_extend():
			return
		if is_airborne() and in_hitstun() \
				and not combo_tracker.try_spend_juggle(hit.juggle_cost):
			return

	var blocked := can_block(hit)
	var away := _away_sign(hitbox)

	if FightClock.active != null:
		FightClock.active.hitstop([self, attacker], hit.hitstop)

	if blocked:
		_resolve_block(hit, away)
	else:
		_resolve_clean_hit(hit, attacker, away)

	_spawn_hit_effect(hit, hitbox)
	hit_taken.emit(attacker, hit, blocked)
	if attacker != null:
		attacker.confirm_hit(self, hit, blocked)


func _resolve_block(hit: HitData, away: float) -> void:
	blockstun_frames = hit.blockstun
	if health != null:
		health.take_chip(hit)
	if meter != null:
		meter.gain(hit.meter_gain_victim)
	velocity.x = hit.block_pushback * away


func _resolve_clean_hit(hit: HitData, attacker: Fighter2D, away: float) -> void:
	# A hit on a non-stunned victim starts a fresh combo.
	if combo_tracker != null and not in_hitstun():
		combo_tracker.drop()

	var scaling := 1.0
	if combo_tracker != null:
		scaling = combo_tracker.damage_multiplier()
	if attacker != null and attacker.data != null:
		scaling *= attacker.data.attack

	var dealt := 0
	if health != null:
		dealt = health.take_hit(hit, scaling)
	if combo_tracker != null:
		combo_tracker.register_hit(attacker, dealt)
	if meter != null:
		meter.gain(hit.meter_gain_victim)

	hitstun_frames = hit.hitstun
	blockstun_frames = 0

	if is_airborne() or hit.launch != Vector2.ZERO:
		var launch := hit.launch if hit.launch != Vector2.ZERO else hit.knockback
		velocity.x = launch.x * away
		if launch.y != 0.0:
			velocity.y = launch.y
	else:
		velocity.x = hit.knockback.x * away
		if hit.knockback.y != 0.0:
			velocity.y = hit.knockback.y

	_pending_knockdown = hit.knockdown
	if not is_airborne() and hit.knockdown != HitData.KnockdownType.NONE \
			and hit.launch == Vector2.ZERO:
		_enter_knockdown(hit.knockdown == HitData.KnockdownType.HARD)


## Called on the attacker by the victim once a hit has fully resolved.
func confirm_hit(victim: Fighter2D, hit: HitData, blocked: bool) -> void:
	if meter != null:
		meter.gain(hit.meter_gain_on_block if blocked else hit.meter_gain_attacker)
	hit_landed.emit(victim, hit, blocked)


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
	if knockdown_frames > 0:
		knockdown_frames -= 1
		if knockdown_frames == 0:
			got_up.emit()
		return

	if hitstun_frames > 0:
		hitstun_frames -= 1
		if hitstun_frames == 0:
			if combo_tracker != null and not is_airborne():
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
		if _pending_knockdown != HitData.KnockdownType.NONE and in_hitstun():
			hitstun_frames = 0
			if combo_tracker != null:
				combo_tracker.drop()
			_enter_knockdown(_pending_knockdown == HitData.KnockdownType.HARD)
		_pending_knockdown = HitData.KnockdownType.NONE
		landed.emit()
	_was_airborne = airborne


func _enter_knockdown(hard: bool) -> void:
	knockdown_frames = knockdown_frames_hard if hard else knockdown_frames_soft
	hitstun_frames = 0
	blockstun_frames = 0
	_pending_knockdown = HitData.KnockdownType.NONE
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
	current_move = null
	velocity = Vector2.ZERO
	_pending_knockdown = HitData.KnockdownType.NONE
