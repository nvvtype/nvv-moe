# Character Authoring Guide

How to build a fighter in FightEngine, optimized for the kusoge workflow:
**frame data first, art later**. A character is one scene (shared by the whole
roster) plus a stack of resources. A new character with working normals,
specials, and a super is an afternoon of Inspector work, no code.

## The shape of a character

```
CHARACTER = FighterData (.tres)
            ├── stats & mobility (health, walk/dash/jump, air options)
            ├── chain_rules: ChainRules        (usually shared by the roster)
            └── moves: Array[MoveData]
                       ├── motion: MotionInput (236, 623, charge, ...)
                       └── hits: Array[HitData] (damage, stun, launch, bounce...)
```

Everything gameplay-relevant lives in those four resource types. The scene is
just a body with boxes; you reuse the same scene for every character and only
swap `FighterData` + sprites.

## 1. The fighter scene (build once, reuse forever)

```
Fighter2D                       # script: fighter.gd
├── CollisionShape2D            # body vs floor/walls (a capsule is fine)
├── Rig (Node2D)                # assign to Fighter2D.rig — auto X-flipped
│   ├── Sprite2D
│   ├── AnimationPlayer
│   ├── HurtBox2D               # shape covering the body
│   ├── HitBox    (HitBox2D)    # in front of the body; leave is_active off
│   └── PushBox   (PushBox2D)   # body-width box
├── InputBuffer                 # action_prefix "p1_", buttons ["l","m","h","s"]
├── CommandInterpreter          # leave moves empty — auto-filled from data
└── FighterStateMachine         # the whole brain; auto-wires everything
```

Assign on `Fighter2D`: `data` (the FighterData), `rig`, `input_buffer`, and
`opponent` (or let the fight scene set it). `FighterStateMachine` finds the
AnimationPlayer, the interpreter, and the movelist on its own.

Optional component children, only if the character uses them: `BurstSystem`,
`BarrierComponent`, `OverdriveComponent` (assign to the matching `Fighter2D`
slots). This is the character-specific switchboard — a character without a
barrier simply doesn't have the node.

## 2. FighterData — the character sheet

Health, attack/defense, walk/dash/backdash speeds, run vs step dash, prejump,
jump and superjump, air jumps, air dashes, backdash invuln. Every field has a
tooltip. This file IS the character archetype: a grappler is low speed + high
health + command grabs; a zoner is backdash invuln + projectiles; the
broken-on-purpose one is whatever you want.

## 3. MoveData — one resource per move

For a 4-button LMHS game a starter movelist is ~12 moves: 4 standing, a few
crouching/air normals, 2–3 specials, 1 super.

The fields that matter day one:

| Field | What it does |
|---|---|
| `id`, `buttons` | `&"5l"`, `["l"]`. The button's position in ChainRules.button_order is its chain weight |
| `motion` | null for normals; a MotionInput for specials (`[2,3,6]` etc.) |
| `startup / active / recovery` | **This is the move.** The state machine toggles the hitbox from these numbers |
| `hits` | One HitData per hit. 3 entries = a 3-hit move, the active window splits automatically |
| `move_type` | NORMAL / SPECIAL / EX_SPECIAL / SUPER / THROW — drives chain routing |
| `allowed_situations` | Standing / Crouching / Airborne flags |
| `meter_cost`, `priority` | Supers cost meter and get higher priority than the specials they overlap |
| `self_velocity` | Lunge applied when the active window starts — slides, dive kicks, full-screen nonsense |
| `animation` | Optional! `"moves/5l"` if it exists. **A move with no animation still works** |

Cancel routing is automatic via `ChainRules` (L→M→H→S, normals→specials→supers).
Per-move exceptions go in `cancels_into` (match against another move's `id` or
`tags`) — that's how you give one character a unique route without touching
the shared rules.

## 4. HitData — what the hit does

Damage, chip, hitstun/blockstun/hitstop, guard height (mid/overhead/low/
unblockable), knockback or launch, and the anime kit per hit: `ground_bounce`,
`wall_bounce`, `untech_frames`, `sliding_knockdown`, `otg`, `snapback`,
`instant_kill`. Plus presentation: spark scene, sound, screen shake.

Make a few shared "house style" HitData resources (light/medium/heavy/launcher)
and duplicate-tweak per move. Character-specific weirdness is just a weirder
HitData.

## 5. Animation: the 2–6 frame workflow

Gameplay never waits for art, because frame data drives the hitbox:

1. **No animation at all** — the move already works. Test the whole character
   as a sliding capsule first; this is the balancing phase.
2. **One sprite** — name an animation `moves/<id>` that shows a single pose
   for the move's total frames. Ship-quality kusoge.
3. **2–6 frames** — pose for startup, pose(s) for active, pose for recovery.
   Keyframe lengths don't need to match the data perfectly; the data is the
   truth, the art is vibes.
4. **Fancy mode** — if you want hand-keyed hitboxes instead of frame data,
   key `HitBox.is_active` + `hit_data` inside the animation and set the
   move's startup/active/recovery to 0; the state machine then uses the
   animation's length as the move timeline.

State animations use a naming convention, and **every one is optional** (missing
ones are skipped, with sensible fallbacks like guard_crush → hitstun):

```
idle, walk_f, walk_b, crouch, prejump, jump, fall,
dash, backdash, airdash, airdash_b,
hitstun, hitstun_air, block, block_crouch, block_air,
knockdown, getup, dizzy, guard_crush, taunt
```

## 6. Character-specific mechanics

- **Universal-with-a-dial**: most systems are exports on `Fighter2D` or the
  components, so they can differ per character: one character with parry, one
  with armor moves, one with reverse beat in a roster of L→M→H→S, one whose
  backdash is fully invuln. "Universal mechanic" vs "character gimmick" is
  just where you set the values.
- **Install/gimmick characters**: react to `OverdriveComponent.overdrive_started`
  / check `is_active` in your move conditions (e.g. some `MoveData` only
  selectable during install — gate it in a `move_started` listener or swap
  `interpreter.moves`).
- **Truly custom states** (flight mode, stances, puppet): subclass
  `FighterStateMachine`, call `_enter(State.CUSTOM)` and implement
  `_on_custom_state()`. Everything universal keeps working.

## 7. The fight scene (1v1)

```
Fight (Node2D)
├── FightClock
├── RoundManager        # fighters = [P1, P2]
├── FightCamera2D       # targets = [P1, P2], limit_left/right = stage walls
├── Stage (your art + floor/wall StaticBody2Ds)
├── P1: your_fighter.tscn   (data = ryu_but_worse.tres, opponent = P2)
└── P2: your_fighter.tscn   (data = literal_dog.tres,   opponent = P1)
```

Call `RoundManager.start_match()`. (`TagTeam` exists for assist/tag
experiments later — for 1v1 just don't add the node.)
