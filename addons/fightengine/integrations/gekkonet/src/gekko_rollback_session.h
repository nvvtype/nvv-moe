// GekkoNet -> Godot GDExtension wrapper for FightEngine.
// Scaffold written against the documented GekkoNet C API (gekkonet.h);
// verify struct field names against your checkout when compiling.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include "gekkonet.h"

namespace godot {

class GekkoRollbackSession : public RefCounted {
	GDCLASS(GekkoRollbackSession, RefCounted)

	GekkoSession *session = nullptr;
	GekkoNetAdapter *adapter = nullptr;
	GekkoConfig config = {};
	Callable on_advance; // (frame: int, inputs: PackedByteArray)
	Callable on_save;    // (frame: int) -> PackedByteArray (state hash bytes)
	Callable on_load;    // (frame: int)
	bool started = false;

protected:
	static void _bind_methods();

public:
	// players: total actor count; input_size: bytes per player per frame;
	// prediction: max rollback window; port: local UDP port (default adapter);
	// desync_detection: exchange state checksums.
	bool start(int players, int input_size, int prediction, int port, bool desync_detection);
	void stop();

	int add_local_player();
	int add_remote_player(const String &address); // "ip:port"
	int add_spectator(const String &address);
	void set_local_delay(int handle, int delay);
	void set_callbacks(const Callable &advance, const Callable &save, const Callable &load);

	void add_local_input(int handle, const PackedByteArray &input);
	// Polls the network and pumps GekkoNet's event loop; dispatches
	// save/load/advance to the callbacks (multiple advances per call while
	// catching up, save+load pairs while rolling back).
	void run_frame();

	float frames_ahead() const;
	Dictionary network_stats(int handle) const;

	~GekkoRollbackSession() override;
};

} // namespace godot
