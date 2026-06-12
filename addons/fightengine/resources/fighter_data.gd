class_name FighterData
extends Resource

## Per-character tuning: stats, mobility, and the movelist.
##
## Assign one FighterData to each [Fighter2D]. Everything a character "is"
## lives here, so building your roster is mostly building these resources.

@export var display_name: String = ""
@export var portrait: Texture2D

@export_group("Stats")
@export var max_health: int = 1000
## Incoming damage is divided by this.
@export var defense: float = 1.0
## Outgoing damage is multiplied by this.
@export var attack: float = 1.0

@export_group("Mobility (px/s, 60fps logic)")
@export var walk_speed: float = 150.0
@export var back_walk_speed: float = 120.0
@export var jump_velocity: float = -420.0
@export var gravity_scale: float = 1.0
## Frames of prejump (grounded, throw-vulnerable) before leaving the floor.
@export var prejump_frames: int = 4
## Extra jumps available while airborne (0 = single jump, 1 = double jump...).
@export var air_jumps: int = 0
@export var air_dashes: int = 0
## Horizontal speed of air dashes, in px/s.
@export var air_dash_speed: float = 500.0
@export var dash_speed: float = 300.0
## Step dash duration. Ignored when run_mode is on.
@export var dash_frames: int = 18
## Hold-to-run instead of a fixed step dash.
@export var run_mode: bool = false
@export var backdash_speed: float = 350.0
@export var backdash_frames: int = 15
## Intangibility granted at the start of a backdash (anime backdash invuln).
@export var backdash_invuln_frames: int = 8
## Marvel-style superjump (tap down, then up).
@export var superjump_enabled: bool = false
@export var superjump_velocity: float = -650.0
## UMvC3-style 8-way air dash: the held direction steers air dashes.
@export var eight_way_airdash: bool = false
## Holding down while falling fastfalls at this speed. 0 = no fastfall.
@export var fastfall_speed: float = 0.0
## Frames of landing recovery after airtime (0 = none).
@export var landing_recovery_frames: int = 0

@export_group("Movelist")
@export var moves: Array[MoveData] = []
## Magic series / chain combo routing. Null = explicit cancels_into only.
@export var chain_rules: ChainRules


func get_move(id: StringName) -> MoveData:
	for move in moves:
		if move.id == id:
			return move
	return null


## Moves grouped for movelist UI screens, in declaration order.
func moves_of_type(type: MoveData.MoveType) -> Array[MoveData]:
	var result: Array[MoveData] = []
	for move in moves:
		if move.move_type == type:
			result.append(move)
	return result
