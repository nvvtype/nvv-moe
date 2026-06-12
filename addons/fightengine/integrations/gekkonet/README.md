# GekkoNet integration (rollback netcode backend)

## State of the world (researched 2026-06)

- [GekkoNet](https://github.com/HeatXD/GekkoNet) is a C/C++ P2P rollback
  networking SDK (BSD-2-Clause) by HeatXD, inspired by GGPO/GGRS, with C
  bindings and a built-in ASIO UDP adapter. It's proven in the wild
  (3rd Strike ports, bsnes-netplay).
- **There is no official Godot addon.** The GekkoNet roadmap lists game
  engine plugins under "Maybe Later", and the only engine wrapper that
  exists is [GekkoNetUE](https://github.com/koenjicode/GekkoNetUE) — for
  **Unreal**, not Godot.

So this folder is that missing Godot wrapper: a GDExtension scaffold that
binds the GekkoNet C API to one Godot class (`GekkoRollbackSession`) shaped
exactly for FightEngine's `RollbackSession` driver. The GDScript side is
fully implemented; the C++ side needs a compile pass on a machine with a
toolchain (this scaffold was written against the documented C API and has
not been compiled — expect small fixes, e.g. struct field names).

## How the pieces fit

```
RollbackSession (GDScript, ships with FightEngine, works today)
 ├── LOCAL    : offline tick driver + input recording
 ├── SYNCTEST : save → rewind → re-simulate → compare (desync hunting,
 │              no network or extension needed — run this FIRST)
 └── ONLINE   : drives `backend` =
        GekkoRollbackSession (this GDExtension)
         └── GekkoNet C library (UDP, prediction, rollback scheduling)
```

GekkoNet decides *when* to save/load/advance; FightEngine's
`StateSnapshotter` does the actual saving/loading (snapshots stay on the
Godot side, only an 8-byte state hash crosses the C boundary, which also
powers GekkoNet's desync detection).

## Building

1. Install SCons and a C++17 compiler.
2. ```
   git clone --recursive https://github.com/godotengine/godot-cpp -b 4.5
   git clone https://github.com/HeatXD/GekkoNet
   cmake -S GekkoNet/GekkoLib -B GekkoNet/build -DBUILD_SHARED_LIBS=OFF && cmake --build GekkoNet/build
   ```
3. From this folder: `scons platform=<windows|linux|macos> target=template_release \
   godot_cpp_path=../path/to/godot-cpp gekkonet_path=../path/to/GekkoNet`
4. Binaries land in `bin/`; `gekkonet.gdextension` picks them up. Restart
   the editor.

## Wiring it up (ONLINE mode)

```gdscript
var gekko := GekkoRollbackSession.new()
gekko.set_callbacks(rollback_session._net_advance,
        rollback_session._net_save, rollback_session._net_load)
gekko.start(2, 3, 8, 7770, true)        # players, input bytes, prediction, port, desync detection
rollback_session.local_handle = gekko.add_local_player()
gekko.add_remote_player("203.0.113.7:7770")
rollback_session.backend = gekko
rollback_session.mode = RollbackSession.Mode.ONLINE
```

## Before going online

Run `RollbackSession.Mode.SYNCTEST` locally until `desync_detected` never
fires. Known current limitation (also flagged in FEATURES.md): projectiles
spawned mid-rollback-window aren't resurrected on load — pool them or keep
prediction windows short until projectile pooling lands.
