# Fight Engine

A Godot 4.5+ plugin for building 2D fighting games — from honest footsies to fully weaponized kusoge.

## Overview

Fxll3n's Fight Engine (FFE) provides the systems every fighting game needs so you can spend your time on characters, not plumbing. It is data-driven (characters are resources, not code), frame-based (everything counts in 60ths of a second), and deliberately tunable past the point of good taste.

See **[FEATURES.md](FEATURES.md)** for the full feature list, mapped against IKEMEN GO's feature set, including the kusoge dials.

## What's in the box

### Collision
- **`HitBox2D` / `HurtBox2D` / `PushBox2D`** — attack, vulnerability, and body-push volumes with team filtering, per-class invulnerability (strike/throw/projectile), multi-hit re-hit intervals, and editor-visible debug colors.

### Hits
- **`HitData`** — one resource describes a hit completely: damage, chip, dizzy and guard-gauge damage, red life, hitstun/blockstun/hitstop, knockback, launch, knockdown (soft/hard), OTG, guard height (mid/overhead/low/unblockable), juggle cost, meter gains, clash priority, hit spark/sound/screen shake.

### Input
- **`InputBuffer`** — frame-accurate ring buffer, facing-relative numpad notation, SOCD cleaning modes.
- **`MotionInput`** — QCF/QCB/DP/HCF/360/charge/double-motion detection with tournament-style leniency (or strict mode, if you hate your players).
- **`CommandInterpreter`** — checks a whole movelist every frame, resolves overlapping commands by priority, supports negative edge and multi-button presses.
- **`InputRecorder`** — record/playback for training dummies and serializable replays.

### Characters
- **`Fighter2D`** — base character: auto-registers boxes, resolves hits (guard, scaling, juggle, knockback, hitstop), tracks stun/knockdown/facing, exposes signals for your state machine and UI. Ships with the anime kit: ground/wall bounces, untech time, air teching, counter hits, instant block, pushblock, throw techs, armor, intangibility windows, air dashes, and invuln backdashes.
- **`FighterData` / `MoveData`** — characters as resources: stats, mobility, and a movelist with commands, frame data, costs, and cancel tags.
- **`HealthComponent`** — health, chip, red (recoverable) life, dizzy gauge, guard gauge.
- **`MeterComponent`** — super meter with stocks.
- **`ComboTracker`** — combo counting, damage scaling, IKEMEN-style juggle points.
- **`ChainRules`** — magic series routing (L→M→H→S by default): self-chains, reverse beat, category cancels, whiff-cancel dial.
- **`BurstSystem`** — BB/GG burst: own gauge, defensive + gold bursts, configurable explosion hitbox.
- **`BarrierComponent`** — Barrier/Faultless Defense: gauge-draining enhanced guard, no chip, extra pushback, air-blocks anything, danger state.
- **`OverdriveComponent`** — install/overdrive activations: opponent freeze, low-health duration scaling, attack/defense/meter buffs, hooks for character gimmicks.

### Match
- **`FightClock`** — logical frame clock: hitstop (incl. one-sided super flash), pause, frame-step, slow motion.
- **`RoundManager`** — rounds, timer, KO / double KO / time over / perfect, match victory.
- **`FightCamera2D`** — two-fighter framing, stage zoom, screen shake.
- **`Projectile2D`** — fireballs with lifetime, hit counts, and priority-based clashing.
- **`StateSnapshotter`** — save/restore the whole fight: training save states and the save/load half of rollback.
- **`RollbackSession`** — rollback re-simulation driver: LOCAL tick driving, SYNCTEST (rewind + re-simulate + compare, for desync hunting), and ONLINE mode driving a rollback backend.
- **`RollbackNetwork`** — pure-GDScript GGPO/GekkoNet-style P2P rollback over UDP: input prediction + delay, redundant input packets, time sync, checksum desync detection. Same contract as the optional GekkoNet C++ backend (`integrations/gekkonet/`).
- **`TagTeam`** — tag and turns team play: raw tags with invuln entry, Marvel-style assist call-ins, benched red-life regen, KO fallthrough.

### Training
- **`InputHistoryDisplay`** — on-screen input viewer (arrows + buttons + frame counts).
- **`FrameAdvantageTracker`** — live +/- frame advantage after every interaction.

### State management
- **`FighterStateMachine`** — batteries-included character brain: locomotion, prejump/jumps/superjumps, step/run dashes, air dashes, frame-data-driven attacks (a move works with zero animation), hitstun/blockstun/knockdown/wakeup, dizzy with mash-out, guard crush, taunts, and a CUSTOM state hook for character gimmicks. Characters become pure resources — see [AUTHORING.md](AUTHORING.md).
- Prefer your own FSM? `Fighter2D` communicates through signals, so anything works — the demo shows a [LimboAI](https://github.com/limbonaut/limboai) (MIT, by [limbonaut](https://github.com/limbonaut)) setup, and the core addon has no hard dependency on it.

## Quick start (zero setup)

Set **`addons/fightengine/template/main_menu.tscn`** as the project's main
scene and press play: main menu → Versus or Training with two placeholder
box-men (full movelist: magic series, low, overhead, launcher, DP, command
throw, TK dive kick with rekka followup, wall-bounce lunge, super). Default
keys register automatically — P1: WASD + U/I/O/P, P2: arrows + numpad
4/5/6/+. Training has health refill, pause/frame-step, dummy
record/playback, save states, and an input display. Assign your own
character scene + `FighterData` on the FightScene exports when ready.

## Quick start (your own scene)

1. Enable the plugin in **Project → Project Settings → Plugins**.
2. Add InputMap actions for each player: `p1_up/down/left/right` plus one per attack button — for a 4-button LMHS game: `p1_l`, `p1_m`, `p1_h`, `p1_s` (and the `p2_` set). Set `InputBuffer.buttons = ["l", "m", "h", "s"]` to match.
3. Build a fighter scene (full walkthrough in [AUTHORING.md](AUTHORING.md)):
   ```
   Fighter2D (CharacterBody2D)
   ├── CollisionShape2D          # floor/wall collision
   ├── Rig (Node2D)              # assigned to Fighter2D.rig — gets X-flipped
   │   ├── Sprite2D + AnimationPlayer
   │   ├── HurtBox2D
   │   ├── HitBox (HitBox2D)     # leave inactive; frame data drives it
   │   └── PushBox2D
   ├── InputBuffer               # action_prefix = "p1_"
   ├── CommandInterpreter        # auto-filled from FighterData
   └── FighterStateMachine       # the brain — auto-wires everything
   ```
4. Create a `FighterData` resource: stats, mobility, and `MoveData` entries (each with an optional `MotionInput` and one or more `HitData` hits). Set startup/active/recovery on each move — **that's a working move, animation optional**.
5. In your 1v1 fight scene add `FightClock`, `RoundManager` (assign both fighters), and `FightCamera2D` (assign both as targets), then call `RoundManager.start_match()`.

Walking, dashing, jumping, attacks, damage, guard, combos, juggles, meter, hitstop, knockdowns, wakeups, and round flow all happen automatically from there. Characters are resources: build the scene once, swap `FighterData` per character.

## Requirements

- Godot 4.5 or higher
- [LimboAI](https://github.com/limbonaut/limboai) only if you use the demo / want behavior-tree AI

## Documentation

- [FEATURES.md](FEATURES.md) — full feature list (IKEMEN GO–referenced) and roadmap
- [AUTHORING.md](AUTHORING.md) — character creation guide (frame data first, 2–6 frame art workflow)
- Every class is documented with doc comments — see the Godot editor's class help

## License

MIT — see [LICENSE.md](LICENSE.md).

## Credits

- **Fight Engine** by Fxll3n
- **LimboAI** by [limbonaut](https://github.com/limbonaut) (MIT)
