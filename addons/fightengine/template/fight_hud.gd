class_name FightHud
extends CanvasLayer

## Template HUD: health bars (P1 left, P2 right), meter bars, round timer,
## round-win pips, combo counters, center announcements (ROUND/FIGHT/KO),
## and a training overlay (input history + debug key hints).
## Built entirely in code; restyle or replace at will.

var _p1: Fighter2D
var _p2: Fighter2D
var _rounds: RoundManager

var _health_bars: Array[ProgressBar] = []
var _meter_bars: Array[ProgressBar] = []
var _timer_label: Label
var _pips: Array[Label] = []
var _combo_labels: Array[Label] = []
var _announce: Label


func setup(p1: Fighter2D, p2: Fighter2D, rounds: RoundManager, training: bool) -> void:
	_p1 = p1
	_p2 = p2
	_rounds = rounds
	_build(training)
	_wire()


func _build(training: bool) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	for i in 2:
		var left := i == 0
		var health := ProgressBar.new()
		health.show_percentage = false
		health.fill_mode = ProgressBar.FILL_END_TO_BEGIN if left else ProgressBar.FILL_BEGIN_TO_END
		health.custom_minimum_size = Vector2(0, 26)
		health.anchor_left = 0.03 if left else 0.55
		health.anchor_right = 0.45 if left else 0.97
		health.anchor_top = 0.04
		health.anchor_bottom = 0.04
		root.add_child(health)
		_health_bars.append(health)

		var meter := ProgressBar.new()
		meter.show_percentage = false
		meter.fill_mode = health.fill_mode
		meter.modulate = Color(0.5, 0.8, 1.0)
		meter.custom_minimum_size = Vector2(0, 12)
		meter.anchor_left = 0.03 if left else 0.69
		meter.anchor_right = 0.31 if left else 0.97
		meter.anchor_top = 0.93
		meter.anchor_bottom = 0.93
		root.add_child(meter)
		_meter_bars.append(meter)

		var pips := Label.new()
		pips.text = ""
		pips.add_theme_font_size_override("font_size", 20)
		pips.anchor_left = 0.4 if left else 0.55
		pips.anchor_right = 0.45 if left else 0.6
		pips.anchor_top = 0.09
		pips.anchor_bottom = 0.09
		pips.horizontal_alignment = \
				HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
		root.add_child(pips)
		_pips.append(pips)

		var combo := Label.new()
		combo.text = ""
		combo.add_theme_font_size_override("font_size", 32)
		combo.anchor_left = 0.05 if left else 0.8
		combo.anchor_right = 0.25 if left else 0.95
		combo.anchor_top = 0.25
		combo.anchor_bottom = 0.25
		root.add_child(combo)
		_combo_labels.append(combo)

	_timer_label = Label.new()
	_timer_label.text = ""
	_timer_label.add_theme_font_size_override("font_size", 44)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.anchor_left = 0.45
	_timer_label.anchor_right = 0.55
	_timer_label.anchor_top = 0.03
	_timer_label.anchor_bottom = 0.03
	add_child(_timer_label)

	_announce = Label.new()
	_announce.text = ""
	_announce.add_theme_font_size_override("font_size", 72)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.anchor_left = 0.2
	_announce.anchor_right = 0.8
	_announce.anchor_top = 0.35
	_announce.anchor_bottom = 0.35
	add_child(_announce)

	if training:
		_build_training_overlay()


func _build_training_overlay() -> void:
	for i in 2:
		var fighter := _p1 if i == 0 else _p2
		if fighter.input_buffer == null:
			continue
		var display := InputHistoryDisplay.new()
		display.input_buffer = fighter.input_buffer
		display.max_rows = 10
		display.anchor_left = 0.01 if i == 0 else 0.93
		display.anchor_top = 0.3
		add_child(display)

	var tracker := FrameAdvantageTracker.new()
	tracker.attacker = _p1
	tracker.defender = _p2
	add_child(tracker)
	var advantage := Label.new()
	advantage.anchor_left = 0.45
	advantage.anchor_right = 0.55
	advantage.anchor_top = 0.12
	advantage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(advantage)
	tracker.measured.connect(func(value: int) -> void:
		advantage.text = ("+%d" % value) if value >= 0 else str(value))

	var hints := Label.new()
	hints.text = "ESC menu · R reset · P pause · O step · F1 rec dummy · F2 play · F3 loop · F5 save · F8 load"
	hints.add_theme_font_size_override("font_size", 13)
	hints.modulate = Color(1, 1, 1, 0.45)
	hints.anchor_left = 0.1
	hints.anchor_right = 0.9
	hints.anchor_top = 0.97
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hints)


func _wire() -> void:
	var fighters := [_p1, _p2]
	for i in 2:
		var fighter: Fighter2D = fighters[i]
		var health_bar := _health_bars[i]
		var meter_bar := _meter_bars[i]
		if fighter.health != null:
			health_bar.max_value = fighter.health.max_health
			health_bar.value = fighter.health.current
			fighter.health.health_changed.connect(
				func(current: int, max_health: int) -> void:
					health_bar.max_value = max_health
					health_bar.value = current)
		if fighter.meter != null:
			meter_bar.max_value = fighter.meter.max_value()
			meter_bar.value = fighter.meter.value
			fighter.meter.meter_changed.connect(
				func(value: int, max_value: int) -> void:
					meter_bar.max_value = max_value
					meter_bar.value = value)
		if fighter.combo_tracker != null:
			# Combos done TO this fighter show on this side.
			var label := _combo_labels[i]
			fighter.combo_tracker.combo_extended.connect(
				func(hits: int, damage: int) -> void:
					if hits >= 2:
						label.text = "%d HITS\n%d dmg" % [hits, damage])
			fighter.combo_tracker.combo_dropped.connect(
				func(_hits: int, _damage: int) -> void: label.text = "")

	_rounds.timer_changed.connect(
		func(seconds: int) -> void:
			_timer_label.text = "∞" if _rounds.round_time <= 0 else str(seconds))
	if _rounds.round_time <= 0:
		_timer_label.text = "∞"
	_rounds.round_started.connect(_on_round_started)
	_rounds.round_ended.connect(_on_round_ended)
	_rounds.match_ended.connect(_on_match_ended)


func _on_round_started(round_number: int) -> void:
	_update_pips()
	_say("ROUND %d" % round_number, 1.0)
	_say_later("FIGHT!", 1.1, 0.7)


func _on_round_ended(winner: int, reason: StringName) -> void:
	match reason:
		&"perfect":
			_say("PERFECT", 1.4)
		&"double_ko":
			_say("DOUBLE KO", 1.4)
		&"time_over":
			_say("TIME OVER", 1.4)
		_:
			_say("KO", 1.4)
	if winner >= 0:
		_say_later("P%d takes the round" % (winner + 1), 1.5, 1.2)
	_update_pips()


func _on_match_ended(winner: int) -> void:
	_say("DRAW" if winner < 0 else "P%d WINS" % (winner + 1), 60.0)


func _update_pips() -> void:
	for i in mini(2, _rounds.wins.size()):
		_pips[i].text = "●".repeat(_rounds.wins[i])


func _say(text: String, seconds: float) -> void:
	_announce.text = text
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(func() -> void:
		if _announce.text == text:
			_announce.text = "")


func _say_later(text: String, seconds: float, delay: float) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(_say.bind(text, seconds))
