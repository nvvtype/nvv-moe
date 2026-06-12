# Changelog

## 0.2.0 — Feature build-out

Everything on the original roadmap, plus the systems around it. See
[FEATURES.md](FEATURES.md) for the full IKEMEN GO–referenced feature map.

### Added
- `HitData` resource: complete hit definitions (damage, chip, dizzy, guard
  damage, red life, stun/hitstop, knockback/launch/knockdown/OTG, guard
  heights, hit classes, juggle cost, meter gains, clash priority,
  sparks/sounds/shake).
- `PushBox2D`: body-to-body push collision.
- `FightClock`: logical frame clock with hitstop (incl. one-sided super
  flash), pause, frame-step, and slow motion.
- `InputBuffer`: frame-accurate ring buffer, facing-relative numpad notation,
  SOCD cleaning (neutral / last-wins / back-priority / raw).
- `MotionInput`: QCF/QCB/DP/HCF/360/charge/double-motion detection with
  configurable leniency.
- `CommandInterpreter`: movelist-wide command detection with priorities,
  press-window buffering, negative edge, and multi-button commands.
- `InputRecorder`: dummy recording/playback and serializable replays.
- `MoveData` / `FighterData`: data-driven movelists and character stats with
  informational frame data.
- `Fighter2D`: base character — box auto-registration, guard logic
  (high/mid/low/overhead/unblockable, air block), hit resolution, stun and
  knockdown tracking, auto-facing, movement helpers, and kusoge dials.
- `HealthComponent`: health, chip (with chip-kill dial), red life, dizzy
  gauge, guard gauge.
- `MeterComponent`: super meter with stocks.
- `ComboTracker`: combo counting, table-driven damage scaling, IKEMEN-style
  juggle point pool.
- `RoundManager`: rounds, timer, KO / double KO / time over / perfect, match
  flow.
- `FightCamera2D`: two-fighter framing, stage zoom, screen shake.
- `Projectile2D`: lifetime, hit counts, priority-based projectile clashing.
- `FEATURES.md`: full feature list referenced against IKEMEN GO.
- Anime fighter kit on `Fighter2D`/`HitData`: ground bounce, wall bounce
  (with per-combo budgets in `ComboTracker`), untech time, air teching with
  directional influence and tech invuln, sliding knockdowns, counter hits,
  instant block, pushblock/advancing guard, throw teching, armor hits,
  intangibility windows, corner push, air dashes, and invuln backdashes.
- `StateSnapshotter` + `save_state()`/`load_state()` across all gameplay
  classes: training save states and the serialization half of rollback
  netcode.
- Training widgets: `InputHistoryDisplay`, `FrameAdvantageTracker`.
- `TagTeam`: tag / turns team play with assist call-ins, invulnerable tag
  entries, benched red-life regen, and KO fallthrough.
- `BurstSystem`: BB/GG-style burst with its own gauge, gold bursts, and a
  configurable explosion hitbox.
- `BarrierComponent`: Barrier / Faultless Defense with drain/regen gauge,
  chip negation, pushback boost, universal air blocking, danger state.
- `OverdriveComponent`: install/overdrive activations with opponent freeze,
  low-health duration scaling, and stat multipliers applied engine-side.
- `ChainRules`: magic series chain routing (LMHS), rapid-fire self-chains,
  Melty-style reverse beat, category cancels, and whiff-cancel dial, used
  by `Fighter2D.can_cancel_into()`.
- Alpha counters (guard cancel attacks) on `Fighter2D` with meter cost,
  invuln, and the `alpha_countered` signal.
- `MoveData.MoveType.EX_SPECIAL` for EX/ES moves.
- Roman/Rapid Cancel on `Fighter2D` (meter cost, red-RC contact rule,
  freeze pop, button auto-detect or `try_roman_cancel()`).
- Parry/shield system: tap window, whiffed-parry guard lockout, stance
  rules, both-sides freeze, meter reward, `unparryable` HitData flag.
- Marvel snapbacks (`HitData.snapback` + `TagTeam` forced switch), DHCs
  (`ChainRules.supers_to_supers`), and Astral-style instant kill hits
  (`HitData.instant_kill`, `HealthComponent.kill()`).
- `FighterStateMachine`: batteries-included character controller covering
  every universal state (locomotion, prejump/air/superjump, step & run
  dashes, air dashes, backdashes, attacks, hitstun/blockstun, knockdown/
  getup, dizzy with mash-out, guard crush, taunt) with frame-data-driven
  attack execution — moves work with no animation; animations are an
  optional, convention-named layer on top. CUSTOM state hook for gimmicks.
- Character authoring: `MoveData.hitbox_name`/`self_velocity` (lunges),
  multi-hit active-window splitting from the `hits` array,
  `FighterData` prejump/dash/run/superjump fields, guts curve on
  `HealthComponent`, wakeup invuln on `Fighter2D`, and `AUTHORING.md`
  (frame-data-first, 2–6 frame art workflow).
- Hit reactions: crumple (`HitData.crumple_frames`), wall splat
  (`HitData.wall_splat_frames`), restand (`HitData.restand`).
- `StatusEffect` + `StatusComponent`: stacked/timed statuses with poison
  ticks, max-stack triggers (curse/magnetism architecture), applied from
  hits via `HitData.applies_status`.
- Input macros (`InputBuffer.macros`): one action presses several buttons
  (throw macro, burst macro).
- Mobility: 8-way air dashes, fastfall, landing recovery (per character);
  jump cancels and dash cancels per move; reversal input buffer, quick
  rise, and back rise in `FighterStateMachine`.
- `Projectile2D`: `delay_frames` (delayed shots / traps) and `durability`
  (beams survive multiple clashes).
- `MeterComponent.passive_per_frame` (auto charge or drain).
- Deterministic seeded gameplay RNG on `FightClock` (state included in
  snapshots for rollback).
- Rollback netcode: `RollbackSession` (re-simulation tick driver with
  LOCAL / SYNCTEST / ONLINE modes) and `RollbackNetwork` (pure-GDScript
  GekkoNet/GGPO-strategy P2P UDP backend: input prediction and delay,
  redundant input packets, rollback + re-simulate on misprediction, time
  sync, checksum desync detection). `integrations/gekkonet/` ships a
  GDExtension wrapper scaffold for the GekkoNet C library as a drop-in
  alternative backend (no official Godot addon exists upstream).
- Game template (`template/`): main menu (Versus / Training / Quit),
  fight scene with code-built stage, HUD (health/meter bars, timer, round
  pips, combo counters, announcements), runtime-registered default
  keyboard controls for both players, and training mode (health refill,
  pause/frame-step, dummy record/playback via F-keys, save states, input
  display, frame advantage). `PlaceholderFighter` builds a fully playable
  box-man with a complete movelist in code, so the game runs before any
  art or character authoring.
- Fixed `FighterStateMachine` connecting to auto-created fighter
  components too early (children ready before parents); wiring is now
  deferred.
- Conditional move design: `MoveData.followup_only` + `requires_clean_hit`
  (rekka followups that only exist after a clean hit), `HitData.air_override`
  / `counter_override` (different reactions on air hit / counter hit), and
  context-aware command detection (`CommandInterpreter.fighter` skips
  currently-illegal moves so inputs fall through correctly).

### Changed
- `CollisionBox2D`: boxes now know their `combatant` and `team`; added
  `_on_activated()` hook and `get_box_rect()`.
- `HitBox2D`: hit validation centralized (self/team filtering,
  invulnerability, once-per-activation with optional `rehit_interval`);
  carries a `HitData` (legacy `damage`/`stun` exports still work).
- `HurtBox2D`: per-class invulnerability flags; hits are now reported once,
  by the attacking box, via `notify_hit`.

## 0.1.0

- Initial release: `CollisionBox2D`, `HitBox2D`, `HurtBox2D`, LimboAI demo.
