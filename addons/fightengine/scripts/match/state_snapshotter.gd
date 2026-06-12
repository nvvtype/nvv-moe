class_name StateSnapshotter
extends Node

## Captures and restores the gameplay state of an entire fight scene.
##
## Two jobs:
## 1. Training-mode save states — call [method snapshot] and [method restore]
##    from a couple of debug keys and you can rehearse a setup forever.
## 2. Rollback netcode groundwork — rollback is "save state, re-simulate N
##    frames with corrected inputs"; this node is the save/load half.
##    The re-simulation half (and a determinism audit) still needs doing;
##    see FEATURES.md.
##
## Any node in the scene that implements save_state()/load_state() is
## included automatically: Fighter2D (which bundles its health, meter, combo
## and input buffer), FightClock, or your own scripts.
##
## Limitations (today): transient spawned nodes (projectiles already fired,
## hit effects) are not resurrected on restore — for save states this rarely
## matters; for rollback, projectile pooling support is planned.

signal snapshot_taken
signal restored

## Root searched for stateful nodes. Defaults to this node's parent.
@export var root: Node

var _last_snapshot: Dictionary = {}


func _ready() -> void:
	if root == null:
		root = get_parent()


## Captures the current state of every stateful node under [member root].
func snapshot() -> Dictionary:
	var snap := {}
	_collect(root, snap)
	_last_snapshot = snap
	snapshot_taken.emit()
	return snap


## Restores a snapshot taken with [method snapshot]. With no argument,
## restores the most recent one.
func restore(snap: Dictionary = {}) -> void:
	if snap.is_empty():
		snap = _last_snapshot
	if snap.is_empty():
		return
	for path in snap:
		var node := get_node_or_null(path)
		if node != null:
			node.load_state(snap[path])
	restored.emit()


func has_snapshot() -> bool:
	return not _last_snapshot.is_empty()


func _collect(node: Node, snap: Dictionary) -> void:
	if node == null:
		return
	if node != self and node.has_method("save_state") \
			and node.has_method("load_state"):
		snap[node.get_path()] = node.save_state()
		# Fighter2D bundles its own components; don't double-collect them.
		if node is Fighter2D:
			return
	for child in node.get_children():
		_collect(child, snap)
