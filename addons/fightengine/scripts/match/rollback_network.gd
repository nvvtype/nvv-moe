class_name RollbackNetwork
extends Node

## Pure-GDScript P2P rollback netcode, adopting the GekkoNet / GGPO strategy:
##
## - Local inputs are delayed by [member input_delay] frames and sent every
##   frame with [member redundancy] frames of history (packet loss tolerant).
## - The remote player's missing inputs are PREDICTED (repeat last confirmed
##   input) so the game never waits, up to [member prediction_window] frames.
## - When a confirmed remote input contradicts a prediction, the session
##   rolls back: load the snapshot at the mispredicted frame, re-simulate to
##   the present with corrected inputs. FightEngine's [RollbackSession] +
##   [StateSnapshotter] do the save/load/re-simulate.
## - Time sync: the peer that runs ahead stalls every other frame until even.
## - Desync detection: peers exchange state digests for frames old enough to
##   be final and compare (GekkoNet's desync_detection).
##
## It implements the same backend contract as the GekkoNet GDExtension
## wrapper (integrations/gekkonet) — set_callbacks / add_local_input /
## run_frame — so [method RollbackSession.use_backend] drives either one,
## and you can swap in the C++ backend later without touching game code.
##
## Two-player only (it's a 1v1 game). Transport is UDP via PacketPeerUDP;
## packets are var_to_bytes dictionaries — simple over optimal, plenty for
## 3-byte inputs at 60 Hz.

signal connected
signal disconnected
signal desync_detected(frame: int)

enum NetState { IDLE, CONNECTING, RUNNING }

const NEUTRAL_INPUT := [5, 0, 0]

@export var local_port: int = 7770
## "ip:port" of the other player.
@export var remote_address: String = "127.0.0.1:7771"
## Exactly one peer must be host; the host is player 0 (left side).
@export var is_host: bool = true
## Frames of local input delay (lower = more rollbacks, higher = laggier).
@export var input_delay: int = 2
## Max frames simulated on predicted inputs before stalling.
@export var prediction_window: int = 8
## Bytes per player per frame (3 = direction + 16 button bits).
@export var input_size: int = 3
## Frames of input history per packet (loss tolerance).
@export var redundancy: int = 12
## How often to exchange state digests, in frames. 0 = off.
@export var checksum_interval: int = 30
## Frames without any packet before declaring the peer gone.
@export var timeout_frames: int = 600

var state: NetState = NetState.IDLE
var current_frame: int = 0
var last_ping_ms: int = 0

var _udp := PacketPeerUDP.new()
var _on_advance: Callable
var _on_save: Callable
var _on_load: Callable

var _local: Dictionary = {}        # frame -> PackedByteArray (delay-scheduled)
var _remote: Dictionary = {}       # frame -> PackedByteArray (confirmed)
var _used_remote: Dictionary = {}  # frame -> PackedByteArray (what the sim used)
var _digests: Dictionary = {}      # frame -> PackedByteArray (state hash)
var _remote_confirmed: int = -1    # newest confirmed remote input frame
var _remote_sim_frame: int = 0     # remote's reported simulation frame
var _frames_since_packet: int = 0
var _stall_parity: bool = false
var _remote_ts: int = 0            # last timestamp received, echoed back


func set_callbacks(advance: Callable, save: Callable, load_cb: Callable) -> void:
	_on_advance = advance
	_on_save = save
	_on_load = load_cb


## Binds the socket and starts the handshake. Both peers call this; the
## session begins once they hear each other ([signal connected]).
func start() -> bool:
	var parts := remote_address.split(":")
	if parts.size() != 2:
		push_error("RollbackNetwork: remote_address must be \"ip:port\".")
		return false
	if _udp.bind(local_port) != OK:
		push_error("RollbackNetwork: couldn't bind UDP port %d." % local_port)
		return false
	_udp.set_dest_address(parts[0], int(parts[1]))
	state = NetState.CONNECTING
	return true


func stop() -> void:
	_udp.close()
	state = NetState.IDLE


## Backend contract: schedule this frame's local input (handle is ignored —
## one local player per peer).
func add_local_input(_handle: int, input: PackedByteArray) -> void:
	var target := current_frame + input_delay
	if not _local.has(target):
		_local[target] = input


## Backend contract: one network pump + zero or more save/load/advance
## callbacks. Call exactly once per physics frame (RollbackSession does).
func run_frame() -> void:
	_poll()
	if state == NetState.IDLE:
		return
	if state == NetState.CONNECTING:
		_send({"t": "hi"})
		return

	_frames_since_packet += 1
	if _frames_since_packet > timeout_frames:
		stop()
		disconnected.emit()
		return

	_check_rollback()

	var can_advance := true
	# Prediction limit: never outrun confirmed remote inputs by more than
	# the window, or rollbacks couldn't reach back far enough.
	if current_frame - (_remote_confirmed + 1) >= prediction_window:
		can_advance = false
	# Time sync: if we're ahead of the remote sim, advance every other frame.
	elif current_frame > _remote_sim_frame + 1:
		_stall_parity = not _stall_parity
		if _stall_parity:
			can_advance = false

	if can_advance:
		_advance_frame()
		_maybe_send_checksum()
	_send_inputs()
	_trim()


# --- Simulation driving --------------------------------------------------------

func _advance_frame() -> void:
	_digests[current_frame] = _on_save.call(current_frame)

	var local_in: PackedByteArray = _local.get(
			current_frame, PackedByteArray(NEUTRAL_INPUT))
	var remote_in: PackedByteArray
	if _remote.has(current_frame):
		remote_in = _remote[current_frame]
	elif _remote_confirmed >= 0:
		remote_in = _remote[_remote_confirmed]  # predict: repeat last input
	else:
		remote_in = PackedByteArray(NEUTRAL_INPUT)
	_used_remote[current_frame] = remote_in

	var all := (local_in + remote_in) if is_host else (remote_in + local_in)
	_on_advance.call(current_frame, all)
	current_frame += 1


func _check_rollback() -> void:
	var first_wrong := -1
	for f in range(maxi(current_frame - prediction_window, 0), current_frame):
		if _remote.has(f) and _used_remote.has(f) \
				and _remote[f] != _used_remote[f]:
			first_wrong = f
			break
	if first_wrong < 0:
		return

	var target := current_frame
	_on_load.call(first_wrong)
	current_frame = first_wrong
	while current_frame < target:
		_advance_frame()


# --- Wire ----------------------------------------------------------------------

func _send(msg: Dictionary) -> void:
	_udp.put_packet(var_to_bytes(msg))


func _send_inputs() -> void:
	var newest := current_frame + input_delay - 1
	var start := maxi(newest - redundancy + 1, 0)
	var blob := PackedByteArray()
	for f in range(start, newest + 1):
		blob += _local.get(f, PackedByteArray(NEUTRAL_INPUT))
	_send({
		"t": "in", "s": start, "i": blob, "f": current_frame,
		"ts": Time.get_ticks_msec(), "ets": _remote_ts,
	})


func _maybe_send_checksum() -> void:
	if checksum_interval <= 0:
		return
	# Only frames too old to ever roll back are comparable.
	var f := current_frame - prediction_window - 1
	if f >= 0 and f % checksum_interval == 0 and _digests.has(f):
		_send({"t": "ck", "f": f, "h": _digests[f]})


func _poll() -> void:
	while _udp.get_available_packet_count() > 0:
		var msg = bytes_to_var(_udp.get_packet())
		if msg is not Dictionary:
			continue
		_frames_since_packet = 0
		match msg.get("t"):
			"hi":
				if state == NetState.CONNECTING:
					state = NetState.RUNNING
					connected.emit()
				_send({"t": "hi2"})
			"hi2":
				if state == NetState.CONNECTING:
					state = NetState.RUNNING
					connected.emit()
			"in":
				_receive_inputs(msg)
			"ck":
				_receive_checksum(msg)


func _receive_inputs(msg: Dictionary) -> void:
	var start := int(msg.get("s", 0))
	var blob: PackedByteArray = msg.get("i", PackedByteArray())
	var count := blob.size() / input_size
	for k in count:
		var f := start + k
		if not _remote.has(f):
			_remote[f] = blob.slice(k * input_size, (k + 1) * input_size)
			_remote_confirmed = maxi(_remote_confirmed, f)
	_remote_sim_frame = maxi(_remote_sim_frame, int(msg.get("f", 0)))
	_remote_ts = int(msg.get("ts", 0))
	var echoed := int(msg.get("ets", 0))
	if echoed > 0:
		last_ping_ms = maxi(Time.get_ticks_msec() - echoed, 0)


func _receive_checksum(msg: Dictionary) -> void:
	var f := int(msg.get("f", -1))
	if f < 0 or f > current_frame - prediction_window - 1:
		return
	if _digests.has(f) and _digests[f] != msg.get("h"):
		desync_detected.emit(f)
		push_warning("RollbackNetwork: DESYNC at frame %d." % f)


func _trim() -> void:
	var horizon := current_frame - maxi(prediction_window * 2 + redundancy, 60)
	for dict in [_local, _remote, _used_remote, _digests]:
		for f in dict.keys():
			if int(f) < horizon:
				dict.erase(f)


## Network stats, GekkoNet style.
func network_stats() -> Dictionary:
	return {
		"ping_ms": last_ping_ms,
		"frames_ahead": current_frame - _remote_sim_frame,
		"confirmed_remote_frame": _remote_confirmed,
		"current_frame": current_frame,
	}
