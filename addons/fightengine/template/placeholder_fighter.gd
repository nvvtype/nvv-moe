class_name PlaceholderFighter
extends RefCounted

## Factory for "box-man": a fully playable placeholder fighter built entirely
## in code — no scene, no sprites, no animations. Used by the template fight
## scene whenever no character scene is assigned, so the game is playable
## before any art exists.
##
## The default movelist doubles as living documentation: LMHS normals with
## magic series, a low, an overhead, a launcher (jump-cancelable), a DP, a
## wall-bounce lunge with an air-hit override, a TK-able air dive kick with
## an on-clean-hit rekka followup, a command throw, and a super.


static func create(prefix: String, color: Color, data: FighterData = null) -> Fighter2D:
	var f := Fighter2D.new()
	f.name = prefix.trim_suffix("_").to_upper()

	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(48, 112)
	body_shape.shape = body_rect
	body_shape.position = Vector2(0, -56)
	f.add_child(body_shape)

	var rig := Node2D.new()
	rig.name = "Rig"
	f.add_child(rig)
	f.rig = rig

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-24, -112), Vector2(24, -112), Vector2(24, 0), Vector2(-24, 0),
	])
	body.color = color
	rig.add_child(body)

	# Facing marker: a little beak pointing forward.
	var beak := Polygon2D.new()
	beak.polygon = PackedVector2Array([
		Vector2(24, -100), Vector2(40, -92), Vector2(24, -84),
	])
	beak.color = color.darkened(0.45)
	rig.add_child(beak)

	var hurt := HurtBox2D.new()
	hurt.name = "HurtBox"
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(52, 112)
	hurt.shape = hurt_rect
	hurt.position = Vector2(0, -56)
	rig.add_child(hurt)

	var hit := HitBox2D.new()
	hit.name = "HitBox"
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(76, 44)
	hit.shape = hit_rect
	hit.position = Vector2(56, -72)
	hit.is_active = false
	rig.add_child(hit)

	var push := PushBox2D.new()
	push.name = "PushBox"
	var push_rect := RectangleShape2D.new()
	push_rect.size = Vector2(44, 108)
	push.shape = push_rect
	push.position = Vector2(0, -54)
	rig.add_child(push)

	var buffer := InputBuffer.new()
	buffer.name = "InputBuffer"
	buffer.action_prefix = prefix
	buffer.buttons = PackedStringArray(["l", "m", "h", "s"])
	f.add_child(buffer)
	f.input_buffer = buffer

	var interpreter := CommandInterpreter.new()
	interpreter.name = "CommandInterpreter"
	f.add_child(interpreter)

	var machine := FighterStateMachine.new()
	machine.name = "FighterStateMachine"
	f.add_child(machine)

	f.data = data if data != null else default_data()
	f.tech_buttons = PackedStringArray(["l"])
	return f


static func default_data() -> FighterData:
	var d := FighterData.new()
	d.display_name = "BOXMAN"
	d.max_health = 1000
	d.superjump_enabled = true
	d.air_jumps = 1
	d.air_dashes = 1
	d.chain_rules = ChainRules.new()

	var standing := MoveData.Situation.STANDING
	var crouching := MoveData.Situation.CROUCHING
	var airborne := MoveData.Situation.AIRBORNE

	var moves: Array[MoveData] = []

	moves.append(_move(&"5l", ["l"], [], MoveData.MoveType.NORMAL, standing,
			4, 3, 8, _hit(35, 14, 10, Vector2(150, 0))))
	moves.append(_move(&"5m", ["m"], [], MoveData.MoveType.NORMAL, standing,
			7, 4, 12, _hit(65, 17, 12, Vector2(190, 0))))
	moves.append(_move(&"5h", ["h"], [], MoveData.MoveType.NORMAL, standing,
			10, 5, 16, _hit(100, 20, 14, Vector2(260, 0))))

	var low := _move(&"2l", ["l"], [], MoveData.MoveType.NORMAL, crouching,
			5, 3, 9, _hit(30, 14, 10, Vector2(130, 0)))
	low.priority = 1
	low.hits[0].guard_height = HitData.GuardHeight.LOW
	moves.append(low)

	var launcher := _move(&"5s", ["s"], [], MoveData.MoveType.NORMAL, standing,
			11, 4, 20, _hit(80, 24, 12, Vector2(80, 0)))
	launcher.jump_cancelable = true
	launcher.hits[0].launch = Vector2(100, -460)
	launcher.hits[0].untech_frames = 35
	moves.append(launcher)

	var air_h := _move(&"jh", ["h"], [], MoveData.MoveType.NORMAL, airborne,
			8, 5, 12, _hit(85, 19, 13, Vector2(180, 0)))
	air_h.hits[0].guard_height = HitData.GuardHeight.HIGH
	moves.append(air_h)

	# Ground 214H: slow command overhead (same input as the air dive kick).
	var overhead := _move(&"ground_214h", ["h"], [2, 1, 4],
			MoveData.MoveType.COMMAND_NORMAL, standing,
			20, 4, 18, _hit(90, 22, 12, Vector2(160, 0)))
	overhead.hits[0].guard_height = HitData.GuardHeight.HIGH
	overhead.priority = 4
	moves.append(overhead)

	# Air 214H dive kick with an on-clean-hit rekka followup (TK-able).
	var dive := _move(&"dive_kick", ["h"], [2, 1, 4],
			MoveData.MoveType.SPECIAL, airborne,
			8, 8, 14, _hit(80, 22, 14, Vector2(140, 0)))
	dive.self_velocity = Vector2(320, 520)
	dive.priority = 4
	dive.cancels_into = [&"dive_followup"]
	moves.append(dive)

	var followup := _move(&"dive_followup", ["h"], [],
			MoveData.MoveType.SPECIAL, standing | airborne,
			6, 4, 16, _hit(70, 20, 12, Vector2(220, 0)))
	followup.followup_only = true
	followup.requires_clean_hit = true
	followup.priority = 10
	followup.hits[0].knockdown = HitData.KnockdownType.SOFT
	moves.append(followup)

	# 623M: launcher DP.
	var dp := _move(&"dp", ["m"], [6, 2, 3], MoveData.MoveType.SPECIAL, standing,
			5, 6, 26, _hit(110, 26, 14, Vector2(90, 0)))
	dp.self_velocity = Vector2(80, -520)
	dp.priority = 6
	dp.hits[0].launch = Vector2(120, -480)
	dp.hits[0].untech_frames = 40
	moves.append(dp)

	# 236H: lunging strike; wall-bounces AIRBORNE victims only.
	var lunge := _move(&"lunge", ["h"], [2, 3, 6], MoveData.MoveType.SPECIAL,
			standing, 12, 8, 20, _hit(95, 22, 14, Vector2(320, 0)))
	lunge.self_velocity = Vector2(460, 0)
	lunge.priority = 5
	var air_version := _hit(95, 22, 14, Vector2(280, 0))
	air_version.launch = Vector2(260, -160)
	air_version.wall_bounce = true
	air_version.untech_frames = 32
	lunge.hits[0].air_override = air_version
	moves.append(lunge)

	# L+M command throw.
	var throw := _move(&"throw", ["l", "m"], [], MoveData.MoveType.THROW, standing,
			5, 2, 22, _hit(120, 0, 0, Vector2(240, 0)))
	throw.require_all_buttons = true
	throw.priority = 7
	throw.hits[0].hit_class = HitData.HitClass.THROW
	throw.hits[0].knockdown = HitData.KnockdownType.HARD
	moves.append(throw)

	# 236236S super: three hits, big freeze.
	var super_move := _move(&"super", ["s"], [2, 3, 6, 2, 3, 6],
			MoveData.MoveType.SUPER, standing, 8, 12, 28,
			_hit(80, 24, 16, Vector2(120, 0)))
	super_move.motion.max_duration = 26
	super_move.meter_cost = 1000
	super_move.priority = 9
	super_move.self_velocity = Vector2(380, 0)
	super_move.hits[0].hitstop = 18
	var super_mid := _hit(80, 24, 16, Vector2(120, 0))
	var super_end := _hit(120, 30, 18, Vector2(420, 0))
	super_end.knockdown = HitData.KnockdownType.HARD
	super_end.sliding_knockdown = true
	super_move.hits.append(super_mid)
	super_move.hits.append(super_end)
	moves.append(super_move)

	d.moves = moves
	return d


static func _move(id: StringName, buttons: Array, motion_steps: Array,
		type: MoveData.MoveType, situations: int, startup: int, active: int,
		recovery: int, first_hit: HitData) -> MoveData:
	var m := MoveData.new()
	m.id = id
	m.display_name = String(id).to_upper()
	m.buttons = PackedStringArray(buttons)
	if not motion_steps.is_empty():
		var motion := MotionInput.new()
		var steps: Array[int] = []
		steps.assign(motion_steps)
		motion.sequence = steps
		m.motion = motion
	m.move_type = type
	m.allowed_situations = situations
	m.startup = startup
	m.active = active
	m.recovery = recovery
	m.hits = [first_hit]
	return m


static func _hit(damage: int, hitstun: int, blockstun: int, knockback: Vector2) -> HitData:
	var h := HitData.new()
	h.damage = damage
	h.hitstun = hitstun
	h.blockstun = blockstun
	h.knockback = knockback
	h.chip_damage = maxi(damage / 10, 0)
	return h
