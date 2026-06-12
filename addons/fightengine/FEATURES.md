# FightEngine Feature List

A full fighting game feature map for FightEngine, using **[IKEMEN GO](https://github.com/ikemen-engine/Ikemen-GO)** as the reference point for what a complete fighting game engine offers. IKEMEN GO is the open-source successor to M.U.G.E.N — its feature set (game modes, dizzy/guard-break/red-life systems, juggle points, tag battles, movelists, training tools, netplay) is the yardstick used below.

FightEngine is **not** a MUGEN-compatible content engine: it's a Godot-native toolkit. Where IKEMEN GO ships a finished game shell that loads characters, FightEngine gives you typed nodes and resources to build that shell yourself — which is exactly what you want for a kusoge fighter, because every system has dials you're allowed to turn the wrong way.

## Legend

| Mark | Meaning |
|------|---------|
| ✅ | Implemented in the addon |
| 🧩 | Hooks/signals provided — small amount of game-side code needed |
| 🎮 | Game-side recipe — built *with* the addon, not *in* it |
| 🚧 | Planned |
| ❌ | Non-goal |

---

## 1. Core combat (IKEMEN: HitDef, juggle, corner push, projectiles)

| Feature | Status | Where |
|---------|--------|-------|
| Hit boxes / hurt boxes with active toggling | ✅ | `HitBox2D`, `HurtBox2D` |
| Push boxes (body collision, no fighter stacking) | ✅ | `PushBox2D` |
| Full hit definitions: damage, chip, stun, knockback, launch, knockdown, OTG | ✅ | `HitData` resource (IKEMEN HitDef equivalent) |
| Hitstop / pause on contact, incl. one-sided (super flash) | ✅ | `FightClock.hitstop()` |
| Hitstun, blockstun, soft/hard knockdown, wakeup timing | ✅ | `Fighter2D` |
| Multi-hit moves (re-hit interval) | ✅ | `HitBox2D.rehit_interval` |
| Strike / throw / projectile hit classes + per-class invulnerability | ✅ | `HitData.hit_class`, `HurtBox2D.invulnerability` |
| Throws (grounded-only by default, kusoge override available) | ✅ | `HitData.HitClass.THROW` |
| Projectiles with lifetime, hit count, and priority clashing | ✅ | `Projectile2D` (IKEMEN projpriority) |
| Trades (simultaneous hits) | 🧩 | Both `was_hit` signals fire the same frame; resolve per `HitData.priority` |
| Corner push (attacker pushed back when victim is cornered) | ✅ | `Fighter2D` corner push (stage walls or `FightCamera2D` limits) |
| Armor / hyper armor (absorb hits without stun) | ✅ | `Fighter2D.armor_hits` + `armor_damage_multiplier` |
| Counter hits (bonus damage/stun when interrupting startup) | ✅ | `Fighter2D.counter_hit_multiplier`/`counter_hit_bonus_hitstun`, `counter_hit` signal |
| Throw teching | ✅ | `Fighter2D.tech_buttons`/`tech_window`, `teched_throw` signal |
| Intangibility windows (backdash invuln, tech invuln, wakeup) | ✅ | `Fighter2D.intangible_frames` |

## 1.5 Anime fighter systems (Marvel 3 / Vampire Savior / GGXX / Melty Blood / BlazBlue)

The kusoge design template gets its own section. These are the systems that make air-dash anime jank possible:

| Feature | Status | Where |
|---------|--------|-------|
| OTG hits (hit them while they're down) | ✅ | `HitData.otg` |
| Ground bounce (per-move property) | ✅ | `HitData.ground_bounce`/`ground_bounce_velocity` |
| Wall bounce off walls & camera limits (per-move property) | ✅ | `HitData.wall_bounce`/`wall_bounce_factor` |
| Per-combo bounce budgets (1 ground + 1 wall, anime standard) | ✅ | `ComboTracker.max_ground_bounces`/`max_wall_bounces` |
| Untech time (air hitstun separate from ground hitstun) | ✅ | `HitData.untech_frames` |
| Air teching with directional influence + tech invuln | ✅ | `Fighter2D.air_tech_enabled`/`air_tech_velocity`/`tech_invuln_frames` |
| Sliding knockdowns (Vampire Savior style) | ✅ | `HitData.sliding_knockdown`, `Fighter2D.knockdown_friction` |
| Double jumps / triple jumps | ✅ | `FighterData.air_jumps` |
| Air dashes (count, speed, momentum kill) | ✅ | `FighterData.air_dashes`/`air_dash_speed`, `Fighter2D.air_dash()` |
| Invuln backdashes | ✅ | `FighterData.backdash_invuln_frames`, `Fighter2D.backdash()` |
| Counter hits (CH damage + bonus hitstun, GGXX style) | ✅ | `Fighter2D.counter_hit_*`, `counter_hit` signal |
| Instant block (GGXX: less blockstun + meter) | ✅ | `Fighter2D.instant_block_window`/`instant_block_advantage` |
| Pushblock / advancing guard (Marvel) | ✅ | `Fighter2D.pushblock_*` |
| Command grabs / air throws | ✅ | `THROW` class + `MotionInput`; air throws via `throws_ignore_state` or custom states |
| Chain / gatling combos (magic series) | 🧩 | `MoveData.cancels_into` tags; state machine enforces routes |
| EX moves & supers with meter costs | ✅ | `MoveData.meter_cost`, `require_all_buttons` |
| Roman cancel / rapid cancel | 🎮 | `end_move()` + `meter.try_spend()` + `FightClock.hitstop()`; ~10 lines in a state |
| Burst (BlazBlue) | 🎮 | Meter + a 360° `HitBox2D` + `intangible_frames`; all pieces exist |
| Vampire Savior round flow (no round resets, carry health) | 🎮 | Skip `reset_for_round()`, keep fighting |
| Assists / strikers (Marvel) | 🚧 | Planned with tag support |
| Dramatic super flash cinematics | ✅ | `FightClock.hitstop([opponent], frames)` freezes them mid-air |

## 2. Input (IKEMEN: command buffer, SOCD, button assist, ~~AI cheap inputs~~)

| Feature | Status | Where |
|---------|--------|-------|
| Frame-accurate input ring buffer (2 seconds of history) | ✅ | `InputBuffer` |
| Numpad notation, facing-relative (6 = toward opponent) | ✅ | `InputBuffer.direction()` |
| Motion inputs: QCF/QCB, DP, HCF/HCB, double-QCF supers, dashes | ✅ | `MotionInput` |
| Charge moves (back-charge, down-charge, db-charge counts) | ✅ | `MotionInput.charge_frames` |
| 360s / pretzel inputs (arbitrary sequences) | ✅ | `MotionInput.sequence` |
| Input leniency (diagonal skipping, axis-tolerant cardinals) | ✅ | `MotionInput.strict = false` |
| Press buffering (inputs eaten slightly early still come out) | ✅ | `CommandInterpreter.press_window` |
| Negative edge (specials on button release) | ✅ | `MoveData.negative_edge` |
| Multi-button commands (throws, EX moves) | ✅ | `MoveData.require_all_buttons` |
| Command priority resolution (DP beats QCF, super beats special) | ✅ | `MoveData.priority` |
| SOCD cleaning: neutral / last-wins / back-priority / raw | ✅ | `InputBuffer.socd_mode` |
| Input recording & playback | ✅ | `InputRecorder` |
| Per-player action prefixes (p1_/p2_, any device via InputMap) | ✅ | `InputBuffer.action_prefix` |
| Button assist (one-button specials) | 🎮 | Make a `MoveData` with no motion and high priority |
| Input display widget (training) | ✅ | `InputHistoryDisplay` |

## 3. Offense (IKEMEN: juggle points, combo counter, score)

| Feature | Status | Where |
|---------|--------|-------|
| Combo tracking with hit count and total damage | ✅ | `ComboTracker` |
| Damage scaling (table-driven, per-hit) | ✅ | `ComboTracker.scaling_table` |
| Juggle point system (victim-owned pool, per-hit cost — IKEMEN style) | ✅ | `ComboTracker.juggle_pool`, `HitData.juggle_cost` |
| Juggle protection (hits whiff when the pool is dry) | ✅ | `ComboTracker.try_spend_juggle()` |
| Cancel routing (chains, special cancels, super cancels) | 🧩 | `MoveData.cancels_into`/`tags`; your state machine enforces |
| Movelist data with frame data & notation for UI | ✅ | `MoveData` (startup/active/recovery/advantage) |
| Attacker damage multiplier per character | ✅ | `FighterData.attack` |
| Score / stylish rank systems | 🎮 | Listen to `ComboTracker` signals |

## 4. Defense (IKEMEN: guard break, dizzy, red life)

| Feature | Status | Where |
|---------|--------|-------|
| Blocking: high (overhead) / mid / low / unblockable | ✅ | `HitData.guard_height`, `Fighter2D.can_block()` |
| Air blocking (per-hit flag) | ✅ | `HitData.air_blockable` |
| Chip damage | ✅ | `HitData.chip_damage` |
| Guard gauge & guard break (IKEMEN guard-break system) | ✅ | `HealthComponent.guard_gauge_max`, `guard_broken` signal |
| Dizzy / stun gauge (IKEMEN dizzy system) | ✅ | `HealthComponent.dizzy_threshold`, `dizzied` signal |
| Red life / recoverable health (IKEMEN red life) | ✅ | `HealthComponent.use_red_life`, `regen_tick()` |
| Per-character defense multiplier | ✅ | `FighterData.defense` |
| Invulnerability windows (strike/throw/projectile) | ✅ | Toggle `HurtBox2D.invulnerability` from animations |
| Pushblock / advancing guard | ✅ | `Fighter2D.pushblock_*`, optional meter cost |
| Burst / combo breakers | 🎮 | Spend meter, fire a `HitBox2D`; all pieces exist |

## 5. Resources & supers (IKEMEN: power bar, stocks)

| Feature | Status | Where |
|---------|--------|-------|
| Super meter with stocks (1000/stock, IKEMEN-style) | ✅ | `MeterComponent` |
| Meter gain on hit / being hit / blocking | ✅ | `HitData.meter_gain_*` |
| Meter costs on moves, checked before performing | ✅ | `MoveData.meter_cost`, `Fighter2D.can_perform()` |
| Super flash (freeze opponent only) | ✅ | `FightClock.hitstop([opponent], frames)` |
| Custom gauges (install meters, heat, GRD...) | 🎮 | Add a second `MeterComponent` |

## 6. Match flow & game modes (IKEMEN: Arcade, VS, Survival, Time Attack, Boss Rush, Watch...)

| Feature | Status | Where |
|---------|--------|-------|
| Rounds, best-of-N, round timer | ✅ | `RoundManager` |
| KO / double KO / time over / perfect detection | ✅ | `RoundManager.round_ended` reasons |
| Pre-round ceremony & post-KO slow-mo windows | ✅ | `pre_round_frames`, `round_end_frames`, `FightClock.slowdown` |
| Versus (local PvP) | 🎮 | Two `Fighter2D` + `RoundManager`; ~a scene's worth of glue |
| Arcade ladder / Boss Rush | 🎮 | Sequence matches, swap `FighterData` |
| Survival (one health bar, endless opponents) | 🎮 | Skip `reset_for_round()` for the player |
| Time Attack / Score Challenge | 🎮 | `RoundManager` + a stopwatch / score listener |
| Training mode | 🧩 | Pause/frame-step (`FightClock`), dummy record/playback (`InputRecorder`), auto-block (`Fighter2D.auto_block`), infinite time (`round_time = 0`) all built in; menu is yours |
| Watch mode (AI vs AI) | 🎮 | Two AI-driven fighters (LimboAI behavior trees) |
| Team battles: simul (2v2 on screen at once) | 🧩 | `RoundManager` supports N fighters & teams via `team`; assists 🚧 |
| Team battles: turns / tag with red life | 🚧 | Red life already in `HealthComponent` |
| Story mode / cutscenes | 🎮 | That's just Godot |
| Bonus stages (car, barrels) | 🎮 | A `HealthComponent` on a car. Ship it. |
| Challenger interruption ("Here comes a new challenger!") | 🎮 | |

## 7. Camera & stage (IKEMEN: stage zoom, EnvShake, parallax, attached chars)

| Feature | Status | Where |
|---------|--------|-------|
| Two-fighter framing camera | ✅ | `FightCamera2D` |
| Stage zoom in/out with separation (IKEMEN stage zoom) | ✅ | `FightCamera2D.min_zoom`/`max_zoom` |
| Stage bounds | ✅ | Camera2D `limit_*` + walls for fighters |
| Screen shake (IKEMEN EnvShake) | ✅ | `FightCamera2D.shake()`, auto via `HitData.shake_*` |
| Parallax backgrounds | 🎮 | Godot `Parallax2D` does this natively |
| Animated / interactive stage props, attached characters | 🎮 | Godot scenes; stage props can own `HitBox2D`es (hazard stages!) |
| Stage BGM, per-round music | 🎮 | `AudioStreamPlayer` |

## 8. Presentation (IKEMEN: lifebars, movelists, win quotes, storyboards)

| Feature | Status | Where |
|---------|--------|-------|
| Lifebar data feed (health, red life, meter, combo, timer signals) | ✅ | All components emit UI-ready signals |
| Hit sparks & hit sounds per hit | ✅ | `HitData.effect_scene`, `HitData.hit_sound` |
| In-game movelist screens with command notation | 🧩 | `MoveData.notation`/`display_name`; render with any Control |
| Character select / portraits | 🧩 | `FighterData.display_name`/`portrait` |
| Announcer hooks (Round 1 / FIGHT / KO / PERFECT) | ✅ | `RoundManager` signals carry everything needed |
| Win quotes, victory screens, storyboards | 🎮 | |

## 9. Training & debug (IKEMEN: training menu, debug keys, hitbox display)

| Feature | Status | Where |
|---------|--------|-------|
| Hitbox/hurtbox visualization | ✅ | Godot's *Debug → Visible Collision Shapes* (color-coded: red hit, green hurt, yellow push) |
| Pause & frame-step | ✅ | `FightClock.is_paused`, `step_frame()` |
| Slow motion | ✅ | `FightClock.slowdown` |
| Dummy recording / playback / loop | ✅ | `InputRecorder` |
| Dummy auto-block | ✅ | `Fighter2D.auto_block` |
| Save states (snapshot / restore the whole fight) | ✅ | `StateSnapshotter` |
| Frame data display | 🧩 | Data exists on `MoveData`; render with any Control |
| Frame advantage meter | ✅ | `FrameAdvantageTracker` (+/- after every interaction) |

## 10. AI (IKEMEN: AI level, AI scaling, cheap-input AI)

| Feature | Status | Where |
|---------|--------|-------|
| State machines & behavior trees | ✅ | [LimboAI](https://github.com/limbonaut/limboai) ships with the repo |
| AI "presses buttons" like a player | ✅ | Drive an `InputRecorder`/`InputBuffer` playback — AI obeys the same input rules as humans (no IKEMEN-style cheap inputs unless you want them) |
| Difficulty ramping | 🎮 | Scale BT reaction delays / option weights |

## 11. Netplay & replays (IKEMEN: delay-based netplay, replays)

| Feature | Status | Where |
|---------|--------|-------|
| Deterministic-friendly architecture (frame-based, input-driven) | ✅ | Everything keys off `FightClock` frames and `InputBuffer` streams |
| Replay recording / playback / serialization | ✅ | `InputRecorder.to_bytes()`/`from_bytes()` per player |
| Delay-based netplay | 🚧 | Exchange `InputBuffer` frames per tick (the buffer's injection API is the integration point) |
| **Rollback netcode** | 🚧 planned | This is the target netcode — delay-based alternatives are trash. Groundwork shipped: |
| → State save/restore for the whole fight | ✅ | `StateSnapshotter` + `save_state()`/`load_state()` on `Fighter2D` (bundles health/meter/combo/inputs) and `FightClock` |
| → Input-driven, frame-counted simulation | ✅ | Everything advances on `FightClock` frames from `InputBuffer` streams |
| → Re-simulation driver (save, rewind, replay N frames) | 🚧 | Loop `StateSnapshotter.restore()` + injected inputs + manual ticks |
| → Determinism audit | 🚧 | Godot float physics needs auditing per platform; same-platform P2P is the realistic first target. Replacing `move_and_slide` with fixed-point box physics is the nuclear option if cross-platform sync drifts |
| → Projectile pooling (so rolled-back fireballs can respawn) | 🚧 | |

## 12. Content pipeline (IKEMEN: MUGEN compatibility, ZSS, Lua)

| Feature | Status | Where |
|---------|--------|-------|
| Data-driven characters (stats + movelist as resources) | ✅ | `FighterData`, `MoveData`, `HitData`, `MotionInput` — editable in the Inspector, no code per character |
| MUGEN/IKEMEN character compatibility (SFF/AIR/CNS/ZSS) | ❌ | Non-goal; Godot scenes & resources are the format |
| Scripting | ✅ | It's Godot — GDScript *is* the Lua layer |

---

## Kusoge dials 🗑️✨

Every switch that lets you break the game **on purpose**, in one place:

| Dial | Effect | Where |
|------|--------|-------|
| `enable_damage_scaling = false` | Every combo hit does full damage | `ComboTracker` |
| `max_combo_hits = 0` + `enable_juggle_limit = false` | Infinites are legal. Encouraged, even | `ComboTracker` (these are the defaults 😈) |
| `scaling_table = [1.0, 2.0, 4.0, ...]` | **Reverse** damage scaling — combos ramp UP | `ComboTracker` |
| `throws_ignore_state = true` | Air throws, combo throws, wakeup command grab loops | `Fighter2D` |
| `allow_chip_kill = true` | Die to chip. Classic | `HealthComponent` |
| `auto_block = false` everywhere + `guard_height = UNBLOCKABLE` | Nothing is ever safe | `HitData` |
| `socd_mode = RAW` | Hitbox-style SOCD shenanigans | `InputBuffer` |
| `MotionInput.strict = true` + `max_duration = 4` | 1-frame-perfect inputs for a 2-damage jab | `MotionInput` |
| `press_window = 30` | Half-second input buffer; everything comes out always | `CommandInterpreter` |
| `hitstop = 60` | One full second of freeze per hit, Hokuto no Ken style | `HitData` |
| `launch = Vector2(-800, -1200)` | Negative X = vacuum hits that pull the victim **in** | `HitData` |
| `knockback = Vector2(4000, 0)` | Full-screen knockback jabs | `HitData` |
| `gain_multiplier = 50.0` | Super every two hits | `MeterComponent` |
| `slowdown = 3` | The whole match in dramatic slow motion | `FightClock` |
| `rehit_interval = 1` | A single hitbox that hits every frame | `HitBox2D` |
| `juggle_cost = 0` | This move never juggle-protects | `HitData` |
| `enable_bounce_limits = false` | Infinite wall bounce loops. Pong, but it's a person | `ComboTracker` |
| `wall_bounce_factor = 2.0` | Victims come off the wall FASTER than they hit it | `HitData` |
| `untech_frames = 600` | Ten full seconds of untechable airtime | `HitData` |
| `air_tech_enabled = false` | MUGEN rules: juggled until you hit the floor | `Fighter2D` |
| `throws_ignore_state + sliding_knockdown + otg` | The complete oki-from-hell starter kit | mixed |

---

## Roadmap

- [x] Hit & hurt boxes
- [x] Push boxes
- [x] Hit data system (damage, stun, knockback, launch, knockdown, OTG)
- [x] Hitstop, pause, frame-step, slow motion (`FightClock`)
- [x] Input buffer with numpad notation & SOCD cleaning
- [x] Special move detection (motions, charges, negative edge, priorities)
- [x] Frame data on moves (informational)
- [x] Combo system (scaling, juggle points, combo counter signals)
- [x] Health: chip, red life, dizzy, guard break
- [x] Meter & stocks
- [x] Rounds, timer, KO/perfect/time-over/double-KO
- [x] Fight camera (framing, zoom, shake)
- [x] Projectiles with clashing
- [x] Input recording / replay serialization
- [x] Corner push
- [x] Throw teching
- [x] Pushblock / advancing guard
- [x] Armor hit absorption counters
- [x] Training overlay widgets (input display, frame advantage)
- [x] Anime kit: ground/wall bounces, untech time, air tech, sliding knockdowns
- [x] Counter hits, instant block, armor, intangibility windows
- [x] Air dashes, double jumps, invuln backdashes
- [x] Save states / rollback state serialization (`StateSnapshotter`)
- [ ] Tag / turns team modes with red-life handoff + assists
- [ ] Rollback netcode (re-simulation driver, determinism audit, projectile pooling)
- [ ] Delay-based netplay (fallback while rollback bakes)
- [ ] Demo scene updated to use the new systems end-to-end
