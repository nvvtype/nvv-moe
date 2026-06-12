class_name MoveData
extends Resource

## Data definition for one move: its command, frame data, hits, and costs.
##
## Build a movelist as an Array[MoveData] on a [FighterData] resource and feed
## it to a [CommandInterpreter] to get a `move_detected` signal whenever the
## player completes the command. The engine never plays animations for you —
## your state machine reacts to the signal, plays [member animation], and
## toggles hitboxes (typically via animation tracks keyed on
## HitBox2D.is_active).

enum MoveType { NORMAL, COMMAND_NORMAL, SPECIAL, EX_SPECIAL, SUPER, THROW, MOVEMENT }

enum Situation {
	STANDING = 1,
	CROUCHING = 2,
	AIRBORNE = 4,
}

@export var id: StringName
@export var display_name: String = ""
## Human-readable command for movelist screens, e.g. "236P" or "↓↘→ + Punch".
@export var notation: String = ""
@export var move_type: MoveType = MoveType.NORMAL

@export_group("Command")
## Directional part of the command. Null = button-only (a plain normal).
@export var motion: MotionInput
## Buttons that trigger the move (any of them). Names must match
## InputBuffer.buttons entries, e.g. ["a"] or ["a", "b"].
@export var buttons: PackedStringArray = PackedStringArray()
## True if pressing ALL listed buttons together is required (e.g. throws, EX
## moves) rather than any single one.
@export var require_all_buttons: bool = false
## Also trigger on button release (classic negative edge for specials).
@export var negative_edge: bool = false
## Detection precedence. Higher is checked first. Give DPs higher priority
## than QCFs and supers higher than specials so overlapping inputs resolve
## the way players expect.
@export var priority: int = 0

@export_group("Requirements")
@export_flags("Standing", "Crouching", "Airborne") var allowed_situations: int = 3
@export var meter_cost: int = 0

@export_group("Frame data")
## Informational frame data for movelists, training displays, and design
## review. The animation remains the source of truth at runtime.
@export var startup: int = 0
@export var active: int = 0
@export var recovery: int = 0
@export var advantage_on_hit: int = 0
@export var advantage_on_block: int = 0

@export_group("Gameplay")
@export var animation: StringName
## Name of the HitBox2D node (under the fighter) this move activates when
## FighterStateMachine runs it from frame data.
@export var hitbox_name: StringName = &"HitBox"
## Facing-relative velocity applied to the fighter when the active window
## starts (lunging specials, slides, dive kicks). Zero = no movement.
@export var self_velocity: Vector2 = Vector2.ZERO
## Hit definitions, in order, for multi-hit moves. With FighterStateMachine,
## the active window is split evenly between entries (each one re-arms the
## hitbox), so a 3-entry array makes a true 3-hit move from data alone.
@export var hits: Array[HitData] = []
## Tags this move can cancel into (checked by your state machine).
## E.g. a light normal might allow ["special", "super"], a special ["super"].
@export var cancels_into: Array[StringName] = []
## Tags describing this move, matched against other moves' cancels_into.
@export var tags: Array[StringName] = []
## On contact, pressing up cancels this move into a jump (jump cancel /
## superjump cancel — launchers in Marvel).
@export var jump_cancelable: bool = false
## On contact, a double-tap dash cancels this move (dash cancel pressure).
@export var dash_cancelable: bool = false


## Total animation length implied by the frame data.
func total_frames() -> int:
	return startup + active + recovery


## Sort key used by CommandInterpreter: explicit priority first, then motion
## complexity so longer commands win over their sub-motions.
func detection_priority() -> int:
	var motion_length := 0
	if motion != null:
		motion_length = motion.sequence.size()
		if motion.charge_frames > 0:
			motion_length += 2
	return priority * 100 + motion_length
