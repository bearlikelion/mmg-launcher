class_name Launcher
extends Control

enum State { GRID, DETAIL, PLAYING }

const GAMES_FILE: String = "res://games.json"
const CARD_SCENE: PackedScene = preload("res://scenes/game_card.tscn")
const GRID_HINTS: String = "D-Pad / Stick: Browse      A / Enter: Details      Start / Esc: Quit"
const DETAIL_HINTS: String = "A / Enter: Play      B / Esc: Back"

var _state: State = State.GRID
var _selected_card: GameCard = null
var _running_pid: int = -1


# Build the grid, bind controller buttons, and play the entrance animation
func _ready() -> void:
	_setup_controller_bindings()
	%DetailView.launch_requested.connect(_on_launch_requested)
	%DetailView.closed.connect(_on_detail_closed)
	%ProcessTimer.timeout.connect(_on_process_timer_timeout)
	var games: Array = _load_games()
	for i in range(games.size()):
		var entry: Variant = games[i]
		if not entry is Dictionary:
			continue
		var card: GameCard = CARD_SCENE.instantiate() as GameCard
		%CardGrid.add_child(card)
		card.setup(entry as Dictionary, i)
		card.selected.connect(_on_card_selected)
		card.play_entrance(0.05 + float(i) * 0.05)
	var card_count: int = %CardGrid.get_child_count()
	%SubHeader.text = "%d games installed" % card_count
	%HintBar.text = GRID_HINTS
	if card_count > 0:
		await get_tree().create_timer(0.6).timeout
		var first_card: GameCard = %CardGrid.get_child(0) as GameCard
		first_card.grab_focus()
	else:
		_show_status("No games found in games.json")


# Handle back navigation and quitting depending on the current state
func _unhandled_input(event: InputEvent) -> void:
	if _state == State.DETAIL:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			%DetailView.close()
	elif _state == State.GRID:
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.pressed and key_event.keycode == KEY_ESCAPE:
				get_tree().quit()
		elif event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.pressed and joy_event.button_index == JOY_BUTTON_START:
				get_tree().quit()


# Restore fullscreen when the launcher regains focus while no game is running
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _state != State.PLAYING:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# Bind the controller A and B buttons to the built-in UI actions
func _setup_controller_bindings() -> void:
	var accept_event: InputEventJoypadButton = InputEventJoypadButton.new()
	accept_event.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", accept_event):
		InputMap.action_add_event("ui_accept", accept_event)
	var cancel_event: InputEventJoypadButton = InputEventJoypadButton.new()
	cancel_event.button_index = JOY_BUTTON_B
	if not InputMap.action_has_event("ui_cancel", cancel_event):
		InputMap.action_add_event("ui_cancel", cancel_event)


# Read and parse the list of games from games.json
func _load_games() -> Array:
	var file: FileAccess = FileAccess.open(GAMES_FILE, FileAccess.READ)
	if file == null:
		_show_status("Could not open %s" % GAMES_FILE)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		_show_status("games.json is not valid JSON")
		return []
	var games: Variant = (parsed as Dictionary).get("games", [])
	if not games is Array:
		return []
	return games as Array


# Open the detail view for the chosen game
func _on_card_selected(card: GameCard) -> void:
	if _state != State.GRID:
		return
	_state = State.DETAIL
	_selected_card = card
	%HintBar.text = DETAIL_HINTS
	_hide_grid()
	%DetailView.open(card)


# Return to the grid once the detail view has finished closing
func _on_detail_closed() -> void:
	_state = State.GRID
	%HintBar.text = GRID_HINTS
	_show_grid(_selected_card)


# Start the selected game, watch its process, and minimize the launcher
func _on_launch_requested() -> void:
	if _state != State.DETAIL or _selected_card == null:
		return
	if not FileAccess.file_exists(_selected_card.exec_path):
		_show_status("Executable not found: %s" % _selected_card.exec_path)
		%DetailView.play_error_feedback()
		return
	var pid: int = OS.create_process(_selected_card.exec_path, [])
	if pid <= 0:
		_show_status("Failed to launch %s" % _selected_card.game_title)
		%DetailView.play_error_feedback()
		return
	_state = State.PLAYING
	_running_pid = pid
	%DetailView.set_running(true)
	%ProcessTimer.start()
	_show_status("Now playing %s" % _selected_card.game_title)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


# Poll the running game and return to the menu once it exits
func _on_process_timer_timeout() -> void:
	if _running_pid > 0 and OS.is_process_running(_running_pid):
		return
	%ProcessTimer.stop()
	_running_pid = -1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_move_to_foreground()
	%DetailView.set_running(false)
	_state = State.DETAIL
	%DetailView.close()
	if _selected_card != null:
		_show_status("Finished playing %s" % _selected_card.game_title)


# Fade the card grid out while the detail view is open
func _hide_grid() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(%CardScroll, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void: %CardScroll.visible = false)


# Bring the card grid back and restore focus to the last played game
func _show_grid(focus_card: GameCard) -> void:
	%CardScroll.visible = true
	UIAnimator.slide_in(%CardScroll, Vector2(0.0, 20.0), 0.22)
	if focus_card != null:
		focus_card.grab_focus.call_deferred()


# Show a short status message under the grid
func _show_status(message: String) -> void:
	%StatusLabel.text = message
