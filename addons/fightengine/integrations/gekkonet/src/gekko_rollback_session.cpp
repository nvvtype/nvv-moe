#include "gekko_rollback_session.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>
#include <string>

using namespace godot;

void GekkoRollbackSession::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start", "players", "input_size", "prediction", "port", "desync_detection"), &GekkoRollbackSession::start);
	ClassDB::bind_method(D_METHOD("stop"), &GekkoRollbackSession::stop);
	ClassDB::bind_method(D_METHOD("add_local_player"), &GekkoRollbackSession::add_local_player);
	ClassDB::bind_method(D_METHOD("add_remote_player", "address"), &GekkoRollbackSession::add_remote_player);
	ClassDB::bind_method(D_METHOD("add_spectator", "address"), &GekkoRollbackSession::add_spectator);
	ClassDB::bind_method(D_METHOD("set_local_delay", "handle", "delay"), &GekkoRollbackSession::set_local_delay);
	ClassDB::bind_method(D_METHOD("set_callbacks", "advance", "save", "load"), &GekkoRollbackSession::set_callbacks);
	ClassDB::bind_method(D_METHOD("add_local_input", "handle", "input"), &GekkoRollbackSession::add_local_input);
	ClassDB::bind_method(D_METHOD("run_frame"), &GekkoRollbackSession::run_frame);
	ClassDB::bind_method(D_METHOD("frames_ahead"), &GekkoRollbackSession::frames_ahead);
	ClassDB::bind_method(D_METHOD("network_stats", "handle"), &GekkoRollbackSession::network_stats);
}

bool GekkoRollbackSession::start(int players, int input_size, int prediction, int port, bool desync_detection) {
	if (started) {
		return false;
	}
	gekko_create(&session);

	std::memset(&config, 0, sizeof(config));
	config.num_players = static_cast<unsigned char>(players);
	config.max_spectators = 2;
	config.input_prediction_window = static_cast<unsigned char>(prediction);
	config.input_size = static_cast<unsigned int>(input_size);
	// Snapshots live on the Godot side; only an 8-byte state hash crosses
	// the boundary (it doubles as the desync-detection checksum source).
	config.state_size = 8;
	config.limited_saving = false;
	config.desync_detection = desync_detection;

	gekko_start(session, &config);
	if (port > 0) {
		adapter = gekko_default_adapter(static_cast<unsigned short>(port));
		gekko_net_adapter_set(session, adapter);
	}
	started = true;
	return true;
}

void GekkoRollbackSession::stop() {
	if (session != nullptr) {
		gekko_destroy(session);
		session = nullptr;
	}
	if (adapter != nullptr) {
		gekko_default_adapter_destroy(adapter);
		adapter = nullptr;
	}
	started = false;
}

int GekkoRollbackSession::add_local_player() {
	ERR_FAIL_NULL_V(session, -1);
	return gekko_add_actor(session, LocalPlayer, nullptr);
}

int GekkoRollbackSession::add_remote_player(const String &address) {
	ERR_FAIL_NULL_V(session, -1);
	const CharString utf8 = address.utf8();
	GekkoNetAddress addr;
	addr.data = (void *)utf8.get_data();
	addr.size = (unsigned int)utf8.length();
	return gekko_add_actor(session, RemotePlayer, &addr);
}

int GekkoRollbackSession::add_spectator(const String &address) {
	ERR_FAIL_NULL_V(session, -1);
	const CharString utf8 = address.utf8();
	GekkoNetAddress addr;
	addr.data = (void *)utf8.get_data();
	addr.size = (unsigned int)utf8.length();
	return gekko_add_actor(session, Spectator, &addr);
}

void GekkoRollbackSession::set_local_delay(int handle, int delay) {
	ERR_FAIL_NULL(session);
	gekko_set_local_delay(session, handle, static_cast<unsigned char>(delay));
}

void GekkoRollbackSession::set_callbacks(const Callable &advance, const Callable &save, const Callable &load) {
	on_advance = advance;
	on_save = save;
	on_load = load;
}

void GekkoRollbackSession::add_local_input(int handle, const PackedByteArray &input) {
	ERR_FAIL_NULL(session);
	gekko_add_local_input(session, handle, (void *)input.ptr());
}

void GekkoRollbackSession::run_frame() {
	ERR_FAIL_NULL(session);
	gekko_network_poll(session);

	int event_count = 0;
	GekkoGameEvent **events = gekko_update_session(session, &event_count);
	for (int i = 0; i < event_count; i++) {
		GekkoGameEvent *ev = events[i];
		switch (ev->type) {
			case SaveEvent: {
				// Ask Godot for the state hash; GekkoNet stores/checksums it.
				PackedByteArray digest = on_save.call(ev->data.save.frame);
				const unsigned int len = MIN((unsigned int)digest.size(), config.state_size);
				std::memcpy(ev->data.save.state, digest.ptr(), len);
				*ev->data.save.state_len = len;
				// Fletcher-style checksum over the digest for desync checks.
				unsigned int sum = 0;
				for (unsigned int b = 0; b < len; b++) {
					sum = (sum * 31u) + digest[b];
				}
				*ev->data.save.checksum = sum;
				break;
			}
			case LoadEvent:
				on_load.call(ev->data.load.frame);
				break;
			case AdvanceEvent: {
				PackedByteArray inputs;
				inputs.resize(ev->data.adv.input_len);
				std::memcpy(inputs.ptrw(), ev->data.adv.inputs, ev->data.adv.input_len);
				on_advance.call(ev->data.adv.frame, inputs);
				break;
			}
			default:
				break;
		}
	}

	int session_event_count = 0;
	GekkoSessionEvent **session_events = gekko_session_events(session, &session_event_count);
	for (int i = 0; i < session_event_count; i++) {
		if (session_events[i]->type == DesyncDetected) {
			UtilityFunctions::push_warning("GekkoNet: desync detected.");
		}
	}
}

float GekkoRollbackSession::frames_ahead() const {
	ERR_FAIL_NULL_V(session, 0.0f);
	return gekko_frames_ahead(session);
}

Dictionary GekkoRollbackSession::network_stats(int handle) const {
	Dictionary out;
	ERR_FAIL_NULL_V(session, out);
	GekkoNetworkStats stats = {};
	gekko_network_stats(session, handle, &stats);
	out["kb_sent"] = stats.kb_sent;
	out["kb_received"] = stats.kb_received;
	out["last_ping"] = stats.last_ping;
	out["avg_ping"] = stats.avg_ping;
	out["jitter"] = stats.jitter;
	return out;
}

GekkoRollbackSession::~GekkoRollbackSession() {
	stop();
}
