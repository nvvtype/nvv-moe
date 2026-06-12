class_name HitData
extends Resource

## Describes everything that happens when a single hit connects.
##
## Assign a HitData to a [HitBox2D] (or to a [MoveData] entry) to drive damage,
## stun, knockback, meter, and presentation. All frame values assume a 60 FPS
## logic rate.

enum HitClass { STRIKE, THROW, PROJECTILE }
enum GuardHeight { MID, HIGH, LOW, UNBLOCKABLE } ## HIGH = overhead, must be blocked standing. LOW must be blocked crouching.
enum KnockdownType { NONE, SOFT, HARD } ## SOFT can be teched, HARD cannot.

@export_group("Damage")
@export var damage: int = 100
## Damage dealt through block. 0 = no chip.
@export var chip_damage: int = 0
## Points added to the victim's dizzy gauge (see HealthComponent). 0 = none.
@export var dizzy_points: int = 0
## Damage dealt to the victim's guard gauge on block. 0 = none.
@export var guard_damage: int = 0
## Fraction of the damage dealt as recoverable red life instead of permanent.
@export_range(0.0, 1.0) var red_life_fraction: float = 0.0

@export_group("Stun & freeze (frames)")
@export var hitstun: int = 14
@export var blockstun: int = 10
## Freeze applied to both attacker and victim on contact.
@export var hitstop: int = 6

@export_group("Movement")
## Velocity applied to a grounded victim on hit, in px/s.
## X is automatically pointed away from the attacker.
@export var knockback: Vector2 = Vector2(150, 0)
## Velocity applied on hit when the victim is (or becomes) airborne.
## A negative Y launches the victim upward. Zero = use knockback instead.
@export var launch: Vector2 = Vector2.ZERO
## Horizontal pushback applied to a blocking victim, in px/s.
@export var block_pushback: float = 200.0
## Knockdown behaviour when the hit ends the victim's air time or connects grounded.
@export var knockdown: KnockdownType = KnockdownType.NONE
## Whether this hit can connect on a knocked-down victim (off-the-ground hit).
@export var otg: bool = false

@export_group("Conditional overrides")
## If set, this entire HitData is replaced by [member air_override] when the
## victim is airborne at the moment of contact. The standard "different
## reaction on air hit" tool: e.g. a fireball that knocks back grounded
## opponents but wall-bounces airborne ones (put wall_bounce on the override
## only). Overrides do not chain (an override's own air_override is ignored).
@export var air_override: HitData
## Same, for counter hits (victim was mid-attack). Checked before
## air_override; if both apply, counter wins.
@export var counter_override: HitData

@export_group("Bounces & air state (anime)")
## Victim bounces off the ground when landing during hitstun (Marvel-style
## ground bounce). Budgeted per combo by ComboTracker.
@export var ground_bounce: bool = false
## Upward velocity of the ground bounce (negative = up), in px/s.
@export var ground_bounce_velocity: float = -500.0
## Victim bounces off walls / camera limits during hitstun (wall bounce).
## Budgeted per combo by ComboTracker.
@export var wall_bounce: bool = false
## Fraction of the impact speed kept after a wall bounce. Over 1.0 = the
## victim comes back FASTER. You know what to do.
@export_range(0.0, 3.0) var wall_bounce_factor: float = 0.8
## Hitstun refreshed when a bounce triggers, in frames.
@export var bounce_hitstun: int = 20
## Air untech time: overrides hitstun while the victim is airborne (0 = use
## hitstun). The victim cannot air tech until it runs out.
@export var untech_frames: int = 0
## Victim keeps sliding with horizontal momentum during the knockdown
## (Vampire Savior style sliding knockdown).
@export var sliding_knockdown: bool = false
## Restand: no launch — an airborne victim falls into grounded standing
## hitstun instead (combo resets to standing, Marvel style).
@export var restand: bool = false
## Crumple: after hitstun the grounded victim collapses into a hard
## knockdown, hittable the whole way (SF crumple). 0 = off; value = extra
## crumple frames appended to hitstun.
@export var crumple_frames: int = 0
## Wall splat: the victim sticks to the wall for this many frames (hittable),
## then falls into hard knockdown. 0 = off. Takes precedence over wall_bounce
## and spends a wall bounce from the combo budget.
@export var wall_splat_frames: int = 0

@export_group("Guard & class")
@export var guard_height: GuardHeight = GuardHeight.MID
@export var air_blockable: bool = true
@export var hit_class: HitClass = HitClass.STRIKE

@export_group("Status")
## Status effect applied to the victim on clean hit (magnetism, curse,
## poison... see StatusEffect / StatusComponent).
@export var applies_status: StatusEffect
@export var status_stacks: int = 1
## Also apply the status on block (pressure-marking moves).
@export var status_on_block: bool = false

@export_group("Special properties")
## Marvel snapback: on clean hit, forces the victim's TagTeam to switch
## the victim out (no effect in 1v1).
@export var snapback: bool = false
## Astral Heat / Instant Kill: a clean hit KOs outright. Gate the move with
## meter costs and conditions in your states; this just does the deed.
@export var instant_kill: bool = false
## This hit cannot be parried/shielded (throws never can regardless).
@export var unparryable: bool = false

@export_group("Juggle")
## Juggle points spent from the victim's pool when this hit connects airborne.
## If the pool can't afford it, the hit is juggle-protected (whiffs).
@export var juggle_cost: int = 3

@export_group("Meter")
@export var meter_gain_attacker: int = 30
@export var meter_gain_victim: int = 15
@export var meter_gain_on_block: int = 10

@export_group("Clash")
## Used when two active hitboxes meet (trades / projectile clashes).
## Higher priority wins; equal priority trades or mutually cancels.
@export var priority: int = 4

@export_group("Presentation")
## Optional scene spawned at the contact point (spark, dust, etc.).
@export var effect_scene: PackedScene
@export var hit_sound: AudioStream
## Screen shake intensity in pixels requested from FightCamera2D. 0 = none.
@export var shake_intensity: float = 0.0
@export var shake_frames: int = 0


## Bitmask form of hit_class, matched against HurtBox2D.invulnerability.
func hit_class_bit() -> int:
	return 1 << hit_class
