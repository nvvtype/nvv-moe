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
- **`StateSnapshotter`** — save/restore the whole fight: training save states today, rollback netcode groundwork tomorrow.
- **`TagTeam`** — tag and turns team play: raw tags with invuln entry, Marvel-style assist call-ins, benched red-life regen, KO fallthrough.

### Training
- **`InputHistoryDisplay`** — on-screen input viewer (arrows + buttons + frame counts).
- **`FrameAdvantageTracker`** — live +/- frame advantage after every interaction.

### State management
- Demo uses [LimboAI](https://github.com/limbonaut/limboai) by [limbonaut](https://github.com/limbonaut) (MIT) for state machines. The core addon has **no hard dependency** on it — `Fighter2D` communicates through signals, so any FSM works.

## Quick start

1. Enable the plugin in **Project → Project Settings → Plugins**.
2. Add InputMap actions for each player: `p1_up/down/left/right` plus one per attack button — for a 4-button LMHS game: `p1_l`, `p1_m`, `p1_h`, `p1_s` (and the `p2_` set). Set `InputBuffer.buttons = ["l", "m", "h", "s"]` to match.
3. Build a fighter scene:
   ```
   Fighter2D (CharacterBody2D)
   ├── CollisionShape2D          # floor/wall collision
   ├── Rig (Node2D)              # assigned to Fighter2D.rig — gets X-flipped
   │   ├── Sprite2D + AnimationPlayer
   │   ├── HurtBox2D
   │   ├── HitBox2D              # is_active keyed in attack animations
   │   └── PushBox2D
   ├── InputBuffer               # action_prefix = "p1_"
   └── CommandInterpreter        # input_buffer + moves from FighterData
   ```
4. Create a `FighterData` resource, fill in stats, and add `MoveData` entries (each with an optional `MotionInput` and one or more `HitData` hits).
5. In your fight scene add `FightClock`, `RoundManager` (assign both fighters), and `FightCamera2D` (assign both as targets), then call `RoundManager.start_match()`.
6. React to `CommandInterpreter.move_detected` in your state machine: check `fighter.can_perform(move)`, call `fighter.begin_move(move)`, play `move.animation`, and key `HitBox2D.is_active` + `hit_data` in the animation. Call `fighter.end_move()` when it finishes.

Damage, guard, combos, juggles, meter, hitstop, knockdowns, and round flow all happen automatically from there.

## Requirements

- Godot 4.5 or higher
- [LimboAI](https://github.com/limbonaut/limboai) only if you use the demo / want behavior-tree AI

## Documentation

- [FEATURES.md](FEATURES.md) — full feature list (IKEMEN GO–referenced) and roadmap
- Every class is documented with doc comments — see the Godot editor's class help

## License

MIT — see [LICENSE.md](LICENSE.md).

## Credits

- **Fight Engine** by Fxll3n
- **LimboAI** by [limbonaut](https://github.com/limbonaut) (MIT)
