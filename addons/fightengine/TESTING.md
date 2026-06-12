# First-Run Testing Checklist

Handoff notes for the first in-Godot pass. Everything in this addon was
written and syntax-validated outside the engine (gdparse/gdlint clean) but
has **never executed in Godot**. This file is the shakedown plan, ordered by
"what breaks first".

**Stack**: pure GDScript + scenes. No C#/Mono, no third-party runtime
dependencies. The only C++ is the *optional* GekkoNet GDExtension scaffold
in `integrations/gekkonet/` (its `.gdextension` ships renamed to `.example`
so the editor won't complain about missing binaries — ignore it entirely
until/unless you compile it).

## 0. Expected first failures (check these on any error)

- **Parse/typing errors in less-exercised paths** — every file parses, but
  the Godot type checker is stricter than gdparse (Variant inference,
  signal arg counts). Errors will name the exact line; fixes should be
  one-liners.
- `FighterStateMachine._find_child_of()` relies on
  `Script.get_global_name()` (Godot 4.3+). If auto-detection misbehaves,
  assign `anim_player` / `interpreter` exports manually.
- The upstream `addons/fgi` plugin and the LimboAI demo are untouched —
  errors from those folders are pre-existing, not from this work.

## 1. Boot smoke test (5 min)

1. Enable the plugin (Project Settings → Plugins). Output should be clean.
2. Set `addons/fightengine/template/main_menu.tscn` as the main scene, play.
3. Menu renders → VERSUS → two box-men on a gray stage, HUD bars, "ROUND 1
   … FIGHT!". P1 = WASD + U/I/O/P, P2 = arrows + numpad 4/5/6/+.

## 2. Core combat checklist (box-men, Versus)

- [ ] Walk f/b, crouch, jump, double jump, superjump (tap 2 then 8)
- [ ] Dash 66 / backdash 44 (backdash has invuln), air dash 66 in air
- [ ] L/M/H/S normals; magic series L→M→H→S chains on hit/block
- [ ] 2L hits low (must crouch-block); j.H hits overhead (must stand-block)
- [ ] 5S launches; press up on hit = jump cancel into air chain
- [ ] 623M DP, 236H lunge; lunge vs AIRBORNE opponent wall-bounces them
- [ ] Air 214H dive kick; on CLEAN hit press H again = followup; blocked =
      no followup; grounded 214H = command overhead instead
- [ ] L+M throw (hard knockdown); mash L within 8f of being thrown = tech
- [ ] 236236S super with full meter; meterless input gives 236H instead
- [ ] Hitting someone mid-move = counter hit (extra damage/hitstun)
- [ ] Corner: victim against wall transfers pushback to attacker
- [ ] KO → round end → pips → best of 3 → match end → ESC to menu

## 3. Training mode checklist

- [ ] Infinite timer (∞), health refills after combos end
- [ ] P pause, O frame-step, R reset positions
- [ ] F1 record P2 dummy → F1 stop → F2 play once / F3 loop
- [ ] F5 save state → F8 load state (mid-combo!)
- [ ] Input history displays both sides; frame advantage readout after
      each interaction

## 4. Determinism / rollback (after core is stable)

1. Add a `RollbackSession` under the fight scene root, assign both
   `InputBuffer`s, `mode = SYNCTEST`. Play. Every `desync_detected`
   warning is a real nondeterminism bug — chase until silent.
   (Expected first finding: projectiles, which aren't snapshot-restored yet.)
2. Netplay: two instances on one machine. Host: `RollbackNetwork`
   `local_port 7770, remote 127.0.0.1:7771, is_host true`; client mirrors
   with `is_host false`. `session.use_backend(network)`; `network.start()`
   both sides. Walk around, then fight; watch for desync warnings.

## 5. Tag mode (optional, when curious)

Add two fighters per side + one `TagTeam` node per side (`fighters`,
`opponent_team` cross-assigned). `tag()` raw tags, `call_assist(&"dp")`
fields the bench character and auto-performs the move if it runs the
built-in state machine. For round flow, listen to `team_defeated` instead
of giving `RoundManager` all four fighters.

## 6. Known limitations (documented, not bugs)

- Projectiles spawned mid-rollback-window can't be resurrected on load
  (pooling planned). Keep SYNCTEST windows short around fireballs.
- Anim-driven moves (frame data = 0) use the AnimationPlayer as timeline —
  fine offline, not rollback-safe.
- Same-frame trade resolution order isn't deterministic-guaranteed yet
  (deterministic hit queue is the next hardening item).
- `RollbackSession` collects its tick list once at `_ready`; nodes spawned
  later (projectiles) tick via the engine instead.
