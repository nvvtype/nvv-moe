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
