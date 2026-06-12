class_name TagTeam
extends Node

## One side's roster for tag (Marvel style) or turns team play.
##
## Handles fielding/benching fighters, raw tags with an invulnerable
## entry, assist call-ins, benched red-life regen, and KO fallthrough to the
## next character. Add one TagTeam per side, fill [member fighters], and
## point [member opponent_team] at the other side so targeting follows the
## active character automatically.
##
## Assists: [method call_assist] fields the bench character and emits
## [signal assist_called] — your state machine performs the requested move,
## then the assist is benched again after [member assist_duration_frames]
## (or when you call [method finish_assist]). Assists keep their hurtboxes,
## so they can be hit mid-assist. Happy birthday.

signal tagged_in(fighter: Fighter2D)
signal tagged_out(fighter: Fighter2D)
signal assist_called(fighter: Fighter2D, move: MoveData)
signal assist_finished(fighter: Fighter2D)
## Every fighter on this team is KO'd.
signal team_defeated

@export var fighters: Array[Fighter2D] = []
@export var opponent_team: TagTeam
## Turns mode: no manual tagging or assists; the next character only comes
## in when the active one is KO'd.
@export var turns_mode: bool = false
## Intangibility granted to the incoming character on a tag.
@export var tag_invuln_frames: int = 20
## Where the incoming character appears, relative to the outgoing one
## (facing-relative: -X is behind). Default drops them in from the air.
@export var tag_entry_offset: Vector2 = Vector2(-60, -260)
## Where assists appear relative to the active fighter (facing-relative).
@export var assist_offset: Vector2 = Vector2(-70, 0)
## Frames an assist stays on the field before being benched automatically.
@export var assist_duration_frames: int = 90
## Benched characters recover red life (see HealthComponent red life).
@export var benched_red_life_regen: bool = true
## Frames after the active character is KO'd before the next one comes in.
@export var ko_replace_delay_frames: int = 40

var active_index: int = 0

var _assist: Fighter2D = null
var _assist_frames: int = 0
var _ko_replace_frames: int = -1


func _ready() -> void:
	for i in fighters.size():
		var fighter := fighters[i]
		fighter.set_combat_enabled(i == active_index)
		fighter.died.connect(_on_fighter_died.bind(fighter))
		fighter.snapped_back.connect(_on_snapback.bind(fighter))
	if opponent_team != null:
		opponent_team.tagged_in.connect(_on_enemy_tagged)
		_retarget(opponent_team.active_fighter())


func active_fighter() -> Fighter2D:
	if fighters.is_empty():
		return null
	return fighters[active_index]


func alive_count() -> int:
	var count := 0
	for fighter in fighters:
		if fighter.health == null or not fighter.health.is_dead:
			count += 1
	return count


func _next_alive_index() -> int:
	for offset in range(1, fighters.size()):
		var i := (active_index + offset) % fighters.size()
		if fighters[i].health == null or not fighters[i].health.is_dead:
			return i
	return -1


## Whether a raw tag is currently legal.
func can_tag() -> bool:
	if turns_mode or fighters.size() < 2:
		return false
	var active := active_fighter()
	if active == null or active.in_stun() or active.is_attacking():
		return false
	var next := _next_alive_index()
	return next >= 0 and fighters[next] != _assist


## Raw tag: bench the active character, bring in the next alive one with
## entry invuln. Returns false if tagging isn't possible right now.
func tag() -> bool:
	if not can_tag():
		return false
	_switch_to(_next_alive_index(), tag_entry_offset, tag_invuln_frames)
	return true


func _switch_to(index: int, entry_offset: Vector2, invuln: int) -> void:
	var outgoing := active_fighter()
	var incoming := fighters[index]
	if incoming == _assist:
		_end_assist()

	active_index = index
	incoming.set_combat_enabled(true)
	incoming.global_position = outgoing.global_position \
			+ Vector2(entry_offset.x * outgoing.facing_sign(), entry_offset.y)
	incoming.facing_right = outgoing.facing_right
	incoming.opponent = outgoing.opponent
	incoming.intangible_frames = maxi(incoming.intangible_frames, invuln)
	incoming.velocity = Vector2.ZERO

	outgoing.set_combat_enabled(false)
	tagged_out.emit(outgoing)
	tagged_in.emit(incoming)


## Calls a bench character in to perform an assist move. [param move_id]
## selects from their FighterData movelist; your state machine receives
## [signal assist_called] and performs it.
func call_assist(move_id: StringName = &"") -> bool:
	if turns_mode or _assist != null:
		return false
	var index := _next_alive_index()
	if index < 0:
		return false
	var active := active_fighter()
	var helper := fighters[index]
	if helper == active or (helper.health != null and helper.health.is_dead):
		return false

	_assist = helper
	_assist_frames = assist_duration_frames
	helper.set_combat_enabled(true)
	helper.global_position = active.global_position \
			+ Vector2(assist_offset.x * active.facing_sign(), assist_offset.y)
	helper.facing_right = active.facing_right
	helper.opponent = active.opponent
	helper.velocity = Vector2.ZERO

	var move: MoveData = null
	if move_id != &"" and helper.data != null:
		move = helper.data.get_move(move_id)
	assist_called.emit(helper, move)
	return true


## Ends the assist early (e.g. when its move finishes).
func finish_assist() -> void:
	_end_assist()


func _end_assist() -> void:
	if _assist == null:
		return
	var helper := _assist
	_assist = null
	_assist_frames = 0
	if helper != active_fighter():
		helper.set_combat_enabled(false)
	assist_finished.emit(helper)


func _physics_process(_delta: float) -> void:
	if FightClock.active != null and FightClock.active.is_paused:
		return

	if benched_red_life_regen:
		for i in fighters.size():
			var fighter := fighters[i]
			if i != active_index and fighter != _assist \
					and fighter.health != null and not fighter.health.is_dead:
				fighter.health.regen_tick()

	if _assist != null:
		_assist_frames -= 1
		# Don't yank an assist that's mid-hitstun; bench it once it recovers.
		if _assist_frames <= 0 and not _assist.in_stun():
			_end_assist()

	if _ko_replace_frames > 0:
		_ko_replace_frames -= 1
		if _ko_replace_frames == 0:
			_ko_replace_frames = -1
			var next := _next_alive_index()
			if next >= 0:
				_switch_to(next, tag_entry_offset, tag_invuln_frames)


func _on_fighter_died(fighter: Fighter2D) -> void:
	if fighter == _assist:
		_end_assist()
		return
	if fighter != active_fighter():
		return
	if _next_alive_index() < 0:
		team_defeated.emit()
		return
	_ko_replace_frames = ko_replace_delay_frames


## Marvel snapback: the active character is forced out, raw entry for the
## next one. Assists hit by a snapback just get benched.
func _on_snapback(fighter: Fighter2D) -> void:
	if fighter == _assist:
		_end_assist()
		return
	if fighter != active_fighter():
		return
	var next := _next_alive_index()
	if next >= 0:
		_switch_to(next, tag_entry_offset, 0)


func _on_enemy_tagged(_enemy: Fighter2D) -> void:
	if opponent_team != null:
		_retarget(opponent_team.active_fighter())


func _retarget(enemy: Fighter2D) -> void:
	if enemy == null:
		return
	for fighter in fighters:
		fighter.opponent = enemy
