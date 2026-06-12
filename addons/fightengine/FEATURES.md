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
| Projectile durability (beams survive N clashes), delayed shots, traps | ✅ | `Projectile2D.durability`/`delay_frames` |
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
| Superjump (Marvel: tap down, then up) | ✅ | `FighterData.superjump_enabled`/`superjump_velocity` |
| Step dash vs hold-to-run per character | ✅ | `FighterData.run_mode`/`dash_frames` |
| Guts (damage scaling at low health, per character) | ✅ | `HealthComponent.guts` Curve |
| Wakeup invuln (okizeme dial) | ✅ | `Fighter2D.wakeup_invuln_frames` |
| Dizzy state with mash-out, guard crush state, taunts (with meter gift) | ✅ | `FighterStateMachine` |
| Lunging moves / slides / dive kick movement | ✅ | `MoveData.self_velocity` |
| Crumple (collapse into hard knockdown, hittable) | ✅ | `HitData.crumple_frames` |
| Wall splat (stick to wall, then collapse) | ✅ | `HitData.wall_splat_frames` |
| Restand (forced back to standing hitstun mid-combo) | ✅ | `HitData.restand` |
| Jump cancel / superjump cancel (launchers) | ✅ | `MoveData.jump_cancelable` |
| Dash cancel pressure | ✅ | `MoveData.dash_cancelable` |
| 8-way air dash (UMvC3) per character | ✅ | `FighterData.eight_way_airdash` |
| Fastfall per character | ✅ | `FighterData.fastfall_speed` |
| Landing recovery per character | ✅ | `FighterData.landing_recovery_frames` |
| Quick rise / back rise, reversal input buffer | ✅ | `FighterStateMachine` wakeup exports |
| Status effects: magnetism marks, curse build-up, poison ticks, stacks | ✅ | `StatusEffect` + `StatusComponent` + `HitData.applies_status` |
| Puppet / trap / setplay objects | 🧩 | `Projectile2D` (delay + zero speed + long lifetime = trap); full puppets = a second rig with `combatant`-owned boxes driven by your states |
| Counter hits (CH damage + bonus hitstun, GGXX style) | ✅ | `Fighter2D.counter_hit_*`, `counter_hit` signal |
| Instant block (GGXX: less blockstun + meter) | ✅ | `Fighter2D.instant_block_window`/`instant_block_advantage` |
| Pushblock / advancing guard (Marvel) | ✅ | `Fighter2D.pushblock_*` |
| Command grabs / air throws | ✅ | `THROW` class + `MotionInput`; air throws via `throws_ignore_state` or custom states |
| Chain / gatling combos (magic series, L→M→H→S) | ✅ | `ChainRules` + `Fighter2D.can_cancel_into()`, enforced by `FighterStateMachine` |
| EX / ES moves (two-button enhanced specials, Melty/Vampire) | ✅ | `MoveData.MoveType.EX_SPECIAL` + `require_all_buttons` + `meter_cost` |
| Supers with meter costs & super flash | ✅ | `MoveData.meter_cost`, `FightClock.hitstop()` |
| Roman cancel / rapid cancel (red RC contact rule, freeze pop) | ✅ | `Fighter2D.try_roman_cancel()` / `roman_cancel_*` exports |
| Parry / shield (3S/Melty: tap window, whiff lockout, stance rules, the clink) | ✅ | `Fighter2D.parry_*`, `parried`/`got_parried`/`parry_whiffed` signals |
| Snapback (Marvel: force the victim's team to switch) | ✅ | `HitData.snapback` + `TagTeam` handling |
| DHC (delayed hyper combo: super cancels into super) | ✅ | `ChainRules.supers_to_supers` |
| Astral Heat / Instant Kill hits | ✅ | `HitData.instant_kill` |
| Alpha counter / Dead Angle / Counter Assault (guard cancel) | ✅ | `Fighter2D.alpha_counter_*`, `alpha_countered` signal |
| Barrier / Faultless Defense (own gauge, no chip, mega pushback, air-blocks anything) | ✅ | `BarrierComponent` + danger state on depletion |
| Burst with gauge, gold burst in neutral (BB/GGXX) | ✅ | `BurstSystem` (gauge fills passively + from damage taken) |
| Overdrive / install activation (BB: low-health duration scaling, opponent freeze, buff multipliers) | ✅ | `OverdriveComponent`; character gimmicks hook `overdrive_started`/`is_active` |
| Vampire Savior round flow (no round resets, carry health) | 🎮 | Skip `reset_for_round()`, keep fighting |
| Assists / strikers (Marvel) | ✅ | `TagTeam.call_assist()` + `assist_called` signal |
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
| Macros (throw macro, burst macro, any-button-combo macro) | ✅ | `InputBuffer.macros` |
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
| Burst / combo breakers | ✅ | `BurstSystem` |
| Barrier / Faultless Defense | ✅ | `BarrierComponent` |
| Alpha counters (guard cancel attacks) | ✅ | `Fighter2D.alpha_counter_*` |

## 5. Resources & supers (IKEMEN: power bar, stocks)

| Feature | Status | Where |
|---------|--------|-------|
| Super meter with stocks (1000/stock, IKEMEN-style) | ✅ | `MeterComponent` |
| Passive meter charge / drain over time (Melty MAX, install drain) | ✅ | `MeterComponent.passive_per_frame` |
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
| Complete character controller (all universal states, data-driven attacks) | ✅ | `FighterStateMachine` + [AUTHORING.md](AUTHORING.md) |
| Watch mode (AI vs AI) | 🎮 | Two AI-driven fighters (LimboAI behavior trees) |
| Team battles: simul (2v2 on screen at once) | 🧩 | `RoundManager` supports N fighters & teams via `team` |
| Team battles: tag with invuln entry, KO fallthrough, benched red-life regen | ✅ | `TagTeam` |
| Team battles: turns mode | ✅ | `TagTeam.turns_mode` |
| Assist call-ins (Marvel style, assists can be hit — happy birthday) | ✅ | `TagTeam.call_assist()`; your states perform the move via `assist_called` |
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
| **Rollback netcode (GekkoNet/GGPO strategy, pure GDScript)** | ✅ | `RollbackNetwork` + `RollbackSession` — input prediction, save/rollback/re-simulate, input delay, redundant UDP input packets, time sync, checksum desync detection |
| → State save/restore for the whole fight | ✅ | `StateSnapshotter` + `save_state()`/`load_state()` everywhere |
| → Re-simulation driver (save, rewind, replay N frames) | ✅ | `RollbackSession` tick driver (takes over physics ticking, replays via `InputBuffer` playback) |
| → Synctest mode (rewind + re-sim + compare every N frames, GGPO-style desync hunting) | ✅ | `RollbackSession.Mode.SYNCTEST` |
| → Deterministic gameplay RNG (seeded, state in snapshots) | ✅ | `FightClock.rng`/`rng_seed` |
| → GekkoNet C++ backend (same contract, swap-in) | 🧩 | `integrations/gekkonet/` GDExtension scaffold — no official Godot addon exists (only an Unreal wrapper), so compile this at home |
| → Determinism audit in-engine | 🚧 | Run SYNCTEST first, then cross-machine; same-platform P2P is the realistic first target. Anim-driven moves (frame data = 0) are not rollback-safe — use frame data |
| → Projectile pooling (so rolled-back fireballs can respawn) | 🚧 | Until then keep prediction windows short or pool projectiles yourself |
| Delay-based netplay | ❌ superseded | Rollback shipped first; set `prediction_window = 0` if you really want to feel the lag |

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
| `require_contact = false` | Whiff-cancel everything into everything | `ChainRules` |
| `allow_reverse_beat = true` + `self_chain_buttons = ["l","m","h","s"]` | Every normal chains into every normal, forever | `ChainRules` |
| `burst_cost_fraction = 0.1` | Ten bursts per gauge. Combos are a suggestion | `BurstSystem` |
| Burst hitbox with real damage | The defensive mechanic is also your best move | `BurstSystem` + `HitData` |
| `base_duration = 99999` | Permanent overdrive. Install: the character | `OverdriveComponent` |
| `roman_cancel_requires_contact = false` + cost 0 | FRC literally everything for free | `Fighter2D` |
| `parry_whiff_recovery = 0` + `parry_window = 30` | Mash parry with zero risk, become Daigo | `Fighter2D` |
| `instant_kill = true` on a 5L | The jab of legend | `HitData` |

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
- [x] Tag / turns team modes with assists and benched red-life regen (`TagTeam`)
- [x] Burst, Barrier/FD, Overdrive, alpha counters
- [x] Magic series chain routing (`ChainRules`, LMHS, reverse beat), EX move type
- [x] Roman cancels, parry/shield, snapbacks, DHCs, instant-kill hits
- [x] FighterStateMachine: full character controller, frame-data-driven attacks
- [x] Superjumps, run dashes, guts, wakeup invuln, dizzy/guard-crush states, taunts
- [x] AUTHORING.md character creation guide
- [x] Gap pass vs full-genre checklist: macros, status effects, crumple/wall
      splat/restand, jump & dash cancels, 8-way airdash, fastfall, landing
      recovery, reversal buffer, quick/back rise, projectile traps &
      durability, passive meter, deterministic seeded RNG
- [x] Rollback netcode: `RollbackNetwork` (GekkoNet-strategy, pure GDScript UDP)
      + `RollbackSession` re-simulation driver + SYNCTEST + GekkoNet
      GDExtension scaffold as alternative backend
- [ ] Rollback hardening: in-engine synctest run, projectile pooling,
      cross-machine determinism audit
- [ ] Demo scene updated to use the new systems end-to-end
