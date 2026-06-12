class_name RollbackSession
extends Node

## Rollback netcode driver: the re-simulation half of rollback, built on
## [StateSnapshotter] (the save/load half) and the [InputBuffer] playback API.
##
## It takes over physics ticking for everything under [member fight_root]
## (nodes are ticked manually, in process_physics_priority order), records
## per-player inputs every frame, and can save, rewind, and re-simulate —
## which is rollback's core loop.
##
## Modes:
## - LOCAL: offline play, ticks normally. (Default; zero overhead beyond
##   input recording.)
## - SYNCTEST: every [member synctest_interval] frames, snapshots, rewinds
##   [member synctest_rollback_frames] frames, re-simulates with the recorded
##   inputs, and compares the result against the original — GGPO-style desync
##   hunting for nondeterminism (unsaved state, wall-clock logic, stray
##   randf). Run this in CI-of-the-couch before going online.
## - ONLINE: drives a rollback network backend through [member backend] —
##   designed for the GekkoNet GDExtension wrapper in
##   integrations/gekkonet/ (any object with the same contract works).
##
## Limitations (documented honestly): transient nodes spawned mid-sim
## (projectiles in flight, hit sparks) are not yet rolled back — projectile
## pooling is the planned fix. Keep synctest_rollback_frames within your
## projectile-free windows or expect false positives when fireballs fly.

signal sync_verified(frame: int)
signal desync_detected(frame: int)

enum Mode { LOCAL, SYNCTEST, ONLINE }

const INPUT_HISTORY := 600

@export var mode: Mode = Mode.LOCAL
## Root of the fight scene; every scripted node under it is ticked by this
## session. Defaults to the parent.
@export var fight_root: Node
@export var snapshotter: StateSnapshotter
## Input buffers driven by the session, one per player, in player order.
@export var input_buffers: Array[InputBuffer] = []

@export_group("Synctest")
## How often to run a rewind + re-simulate check, in frames.
@export var synctest_interval: int = 30
@export var synctest_rollback_frames: int = 8

## Network backend (GekkoRollbackSession from integrations/gekkonet, or
## anything with add_local_input(handle, bytes) / run_frame()). Untyped on
## purpose: no compile-time dependency on the extension.
var backend: Object = null
## Backend player handle for the local player (ONLINE mode).
var local_handle: int = 0

var frame: int = 0

var _ticked: Array[Node] = []
var _feeders: Array[RefCounted] = []
var _snapshots: Dictionary = {}  # frame -> snapshot
var _resimulating: bool = false


class _InputFeeder:
	extends RefCounted
	# Per-buffer recorded input stream; feeds the buffer through its
	# playback hook so live play, re-simulation, and online play all go
	# through one deterministic path.
	var buffer: InputBuffer
	var history: Array[Vector2i] = []
	var cursor: int = 0

	func record_live() -> void:
		history.append(Vector2i(buffer._read_direction(), buffer._read_buttons()))
		if history.size() > INPUT_HISTORY:
			history.pop_front()
			cursor -= 1

	func record_remote(dir: int, held: int) -> void:
		history.append(Vector2i(dir, held))
		if history.size() > INPUT_HISTORY:
			history.pop_front()
			cursor -= 1

	func next_playback_frame() -> Vector2i:
		if cursor < 0 or cursor >= history.size():
			return Vector2i(5, 0)
		var result := history[cursor]
		cursor += 1
		return result


func _ready() -> void:
	if fight_root == null:
		fight_root = get_parent()
	if snapshotter == null:
		snapshotter = StateSnapshotter.new()
		snapshotter.root = fight_root
		add_child(snapshotter)

	for buffer in input_buffers:
		var feeder := _InputFeeder.new()
		feeder.buffer = buffer
		buffer.playback = feeder
		_feeders.append(feeder)

	_collect_ticked(fight_root)
	_ticked.sort_custom(
		func(a: Node, b: Node) -> bool:
			return a.process_physics_priority < b.process_physics_priority
	)
	for node in _ticked:
		node.set_physics_process(false)


func _collect_ticked(node: Node) -> void:
	if node != self and node != snapshotter and node.get_script() != null \
			and node.has_method("_physics_process"):
		_ticked.append(node)
	for child in node.get_children():
		_collect_ticked(child)


func _physics_process(delta: float) -> void:
	match mode:
		Mode.LOCAL:
			_record_local_inputs()
			_tick(delta)
		Mode.SYNCTEST:
			_record_local_inputs()
			_tick(delta)
			_store_snapshot()
			if frame % maxi(synctest_interval, 1) == 0 \
					and frame > synctest_rollback_frames:
				_run_synctest(delta)
		Mode.ONLINE:
			_run_online(delta)


## Advances the whole fight by exactly one deterministic frame.
func _tick(delta: float) -> void:
	frame += 1
	for node in _ticked:
		if is_instance_valid(node) and node.can_process():
			node._physics_process(delta)


func _record_local_inputs() -> void:
	for feeder in _feeders:
		(feeder as _InputFeeder).record_live()


func _store_snapshot() -> void:
	_snapshots[frame] = snapshotter.snapshot()
	_snapshots.erase(frame - INPUT_HISTORY)


func _restore_to(target_frame: int) -> bool:
	if not _snapshots.has(target_frame):
		return false
	snapshotter.restore(_snapshots[target_frame])
	# Rewind every feeder cursor to replay the same inputs.
	var rewind := frame - target_frame
	for feeder in _feeders:
		(feeder as _InputFeeder).cursor -= rewind
	frame = target_frame
	return true


func _run_synctest(delta: float) -> void:
	var checked_frame := frame
	var before := _state_hash(snapshotter.snapshot())
	if not _restore_to(frame - synctest_rollback_frames):
		return
	_resimulating = true
	while frame < checked_frame:
		_tick(delta)
	_resimulating = false
	var after := _state_hash(snapshotter.snapshot())
	if before == after:
		sync_verified.emit(checked_frame)
	else:
		desync_detected.emit(checked_frame)
		push_warning("RollbackSession: desync at frame %d — something in the sim isn't saved or isn't deterministic." % checked_frame)


func _state_hash(snapshot: Dictionary) -> int:
	# var_to_bytes (objects disallowed) gives a machine-independent encoding:
	# shared Resource references (HitData etc.) encode as null on BOTH peers,
	# so cross-peer digests stay comparable — hashing the Dictionary directly
	# would mix in Object instance IDs and desync-flag every frame.
	return hash(var_to_bytes(snapshot))


# --- Online (GekkoNet backend) -------------------------------------------------

## Encodes one player's current device input for the wire: byte 0 = numpad
## direction (facing-INDEPENDENT: as if facing right), byte 1+ = button mask.
func encode_local_input(buffer: InputBuffer) -> PackedByteArray:
	var was_flipped := not buffer.facing_right
	if was_flipped:
		buffer.facing_right = true
	var dir := buffer._read_direction()
	if was_flipped:
		buffer.facing_right = false
	var held := buffer._read_buttons()
	return PackedByteArray([dir, held & 0xFF, (held >> 8) & 0xFF])


func _run_online(delta: float) -> void:
	if backend == null:
		return
	if input_buffers.size() > local_handle:
		backend.add_local_input(local_handle,
				encode_local_input(input_buffers[local_handle]))
	# The backend calls back into _net_advance/_net_save/_net_load below
	# (the GekkoNet wrapper takes them as Callables at setup).
	backend.run_frame()


## Backend callback: synchronized inputs for all players this frame.
## [param all_inputs] = concatenated per-player encodings (3 bytes each).
func _net_advance(_net_frame: int, all_inputs: PackedByteArray) -> void:
	for i in _feeders.size():
		var base := i * 3
		if base + 2 < all_inputs.size():
			var raw_dir := int(all_inputs[base])
			var held := int(all_inputs[base + 1]) | (int(all_inputs[base + 2]) << 8)
			var feeder := _feeders[i] as _InputFeeder
			feeder.record_remote(_mirror_dir(raw_dir, feeder.buffer.facing_right), held)
	_tick(1.0 / 60.0)


func _mirror_dir(dir_facing_right: int, facing_right: bool) -> int:
	if facing_right:
		return dir_facing_right
	var x := ((dir_facing_right - 1) % 3) - 1
	var y := (dir_facing_right - 1) / 3
	return 1 + (1 - x) + y * 3


## Backend callback: store a snapshot for [param net_frame]; the returned
## bytes are GekkoNet's desync-detection checksum payload.
func _net_save(net_frame: int) -> PackedByteArray:
	var snap := snapshotter.snapshot()
	_snapshots[net_frame] = snap
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, _state_hash(snap))
	return bytes


## Backend callback: rollback to [param net_frame]. Unlike the synctest
## rewind, feeder cursors are NOT rewound: the backend re-advances with
## corrected inputs, which get appended as new feeder entries.
func _net_load(net_frame: int) -> void:
	if _snapshots.has(net_frame):
		snapshotter.restore(_snapshots[net_frame])
		frame = net_frame


## Convenience: wires a backend (RollbackNetwork or the GekkoNet extension)
## to this session's callbacks and switches to ONLINE mode.
func use_backend(net_backend: Object, player_handle: int = 0) -> void:
	net_backend.set_callbacks(_net_advance, _net_save, _net_load)
	backend = net_backend
	local_handle = player_handle
	mode = Mode.ONLINE
