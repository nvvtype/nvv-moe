@tool
extends EditorPlugin

## FightEngine editor plugin.
##
## All runtime classes register themselves via class_name, so there is no
## setup to do here yet. Scene-level services (FightClock, FightCamera2D,
## RoundManager) are plain nodes you add to your fight scene rather than
## autoloads, so every match owns its own clock and camera — which is also
## what keeps training-mode pause and frame-stepping scoped to the fight.


func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	pass
