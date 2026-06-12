class_name ChainRules
extends Resource

## Magic series / chain combo routing (Marvel chains, Melty reverse beat).
##
## Defines which moves can cancel into which, by button weight and move
## category, for a whole character (assign to [member FighterData.chain_rules]).
## [method Fighter2D.can_cancel_into] consults this automatically, so your
## attack state only has to ask the fighter.
##
## Default setup is a 4-button L → M → H → S magic series:
## any normal chains into any heavier normal on contact, lights self-chain,
## normals cancel into specials/EX/supers, specials cancel into supers.
## Explicit [member MoveData.cancels_into] entries always win, so unique
## routes and exceptions stay per-move.

## Button names from lightest to heaviest. A move's weight is the position
## of its first button in this list.
@export var button_order: PackedStringArray = PackedStringArray(["l", "m", "h", "s"])
## Buttons whose normals can chain into themselves (rapid-fire lights, 5L 5L 5L).
@export var self_chain_buttons: PackedStringArray = PackedStringArray(["l"])
## Reverse beat (Melty Blood): normals chain in ANY direction, heavier into
## lighter included.
@export var allow_reverse_beat: bool = false
## Chains require the move to have touched the opponent (hit or block).
## Off = whiff-cancel everything. Melty players know. Kusoge dial.
@export var require_contact: bool = true

@export_group("Category cancels")
@export var normals_to_specials: bool = true
@export var normals_to_supers: bool = true
@export var specials_to_supers: bool = true
## DHC (Marvel delayed hyper combo): supers cancel into other supers.
@export var supers_to_supers: bool = false
## EX moves count as specials for routing (normals → EX, EX → super).
@export var ex_counts_as_special: bool = true


## Weight of a move's first button in the magic series. -1 = not a series
## button (the move only chains via explicit cancels_into).
func weight(move: MoveData) -> int:
	if move == null or move.buttons.is_empty():
		return -1
	return button_order.find(move.buttons[0])


func _category(move: MoveData) -> int:
	match move.move_type:
		MoveData.MoveType.NORMAL, MoveData.MoveType.COMMAND_NORMAL:
			return 0
		MoveData.MoveType.SPECIAL:
			return 1
		MoveData.MoveType.EX_SPECIAL:
			return 1 if ex_counts_as_special else -1
		MoveData.MoveType.SUPER:
			return 2
	return -1


## Whether [param from] may cancel into [param to]. [param connected] is
## whether [param from] has hit or been blocked.
func can_chain(from: MoveData, to: MoveData, connected: bool) -> bool:
	if from == null or to == null:
		return false

	# Explicit per-move routes always win (and still respect contact).
	var explicit := _explicitly_allowed(from, to)
	if require_contact and not connected:
		return false
	if explicit:
		return true

	var cat_from := _category(from)
	var cat_to := _category(to)
	if cat_from < 0 or cat_to < 0:
		return false

	if cat_from == 0 and cat_to == 0:
		var weight_from := weight(from)
		var weight_to := weight(to)
		if weight_from < 0 or weight_to < 0:
			return false
		if weight_to == weight_from:
			return to.buttons[0] in self_chain_buttons
		if allow_reverse_beat:
			return true
		return weight_to > weight_from

	if cat_from == 0 and cat_to == 1:
		return normals_to_specials
	if cat_from == 0 and cat_to == 2:
		return normals_to_supers
	if cat_from == 1 and cat_to == 2:
		return specials_to_supers
	if cat_from == 2 and cat_to == 2:
		return supers_to_supers
	return false


func _explicitly_allowed(from: MoveData, to: MoveData) -> bool:
	if to.id != &"" and from.cancels_into.has(to.id):
		return true
	for tag in to.tags:
		if from.cancels_into.has(tag):
			return true
	return false
