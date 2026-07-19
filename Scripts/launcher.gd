class_name Launcher
extends Control

enum State { ROW, DETAIL, PLAYING, SURVEY, QUIT_CONFIRM }

const CARD_SCENE: PackedScene = preload("res://Scenes/game_card/game_card.tscn")
const LIBRARY_PATH: String = "res://Resources/game_library.tres"
const ROW_HINTS: String = "D-Pad / Stick: Browse      A / Enter: Details      Start / Esc: Quit"
const DETAIL_HINTS: String = "A / Enter: Play      B / Esc: Back"
const VIDEO_DETAIL_HINTS: String = "A / Enter: Watch      B / Esc: Back"
const STEAM_RETURN_GRACE_MSEC: int = 3000
const CATEGORY_ORDER: Array[GameInfo.Category] = [
	GameInfo.Category.STEAM,
	GameInfo.Category.OPEN_SOURCE,
	GameInfo.Category.PROTOTYPE,
	GameInfo.Category.GAME_JAM,
	GameInfo.Category.VIDEO,
]
const CATEGORY_TITLES: Dictionary = {
	GameInfo.Category.STEAM: "STEAM GAMES",
	GameInfo.Category.OPEN_SOURCE: "OPEN SOURCE",
	GameInfo.Category.PROTOTYPE: "PROTOTYPES",
	GameInfo.Category.GAME_JAM: "GAME JAMS",
	GameInfo.Category.VIDEO: "VIDEOS",
}
const CATEGORY_COLORS: Dictionary = {
	GameInfo.Category.STEAM: Gruvbox.GREEN,
	GameInfo.Category.OPEN_SOURCE: Gruvbox.YELLOW,
	GameInfo.Category.PROTOTYPE: Gruvbox.AQUA,
	GameInfo.Category.GAME_JAM: Gruvbox.ORANGE,
	GameInfo.Category.VIDEO: Gruvbox.PURPLE,
}

var _library: GameLibrary = null
var _state: State = State.ROW
var _selected_card: GameCard = null
var _running_pid: int = -1
var _steam_started_msec: int = 0
var _session_started_msec: int = 0
var _cards: Array[GameCard] = []
var _quit_return_focus: Control = null


# Build the row of cards, bind controller buttons, and play the entrance animation
func _ready() -> void:
	_setup_controller_bindings()
	%DetailView.launch_requested.connect(_on_launch_requested)
	%DetailView.closed.connect(_on_detail_closed)
	%FeedbackSurvey.finished.connect(_on_survey_finished)
	%QuitDialog.confirmed.connect(_on_quit_confirmed)
	%QuitDialog.cancelled.connect(_on_quit_cancelled)
	%ProcessTimer.timeout.connect(_on_process_timer_timeout)
	_library = load(LIBRARY_PATH) as GameLibrary
	if _library != null:
		for category: GameInfo.Category in CATEGORY_ORDER:
			var category_games: Array[GameInfo] = []
			for game: GameInfo in _library.games_in_category(category):
				if game.is_available():
					category_games.append(game)
			if not category_games.is_empty():
				_build_section(category, category_games)
	%SubHeader.text = _subheader_bbcode()
	%HintBar.text = ROW_HINTS
	if _cards.size() > 0:
		await get_tree().create_timer(0.6).timeout
		_cards[0].grab_focus()
	else:
		_show_status("No games enabled in the library")


# Handle back navigation and quitting depending on the current state
func _unhandled_input(event: InputEvent) -> void:
	if _state == State.DETAIL:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			%DetailView.close()
	elif _state == State.ROW:
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.pressed and key_event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_prompt_quit()
		elif event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.pressed and joy_event.button_index == JOY_BUTTON_START:
				get_viewport().set_input_as_handled()
				_prompt_quit()


# Ask for confirmation before closing the launcher
func _prompt_quit() -> void:
	_state = State.QUIT_CONFIRM
	_quit_return_focus = get_viewport().gui_get_focus_owner()
	%QuitDialog.open()


# Close the launcher once the player confirms
func _on_quit_confirmed() -> void:
	get_tree().quit()


# Return to browsing when quitting is cancelled
func _on_quit_cancelled() -> void:
	_state = State.ROW
	if _quit_return_focus != null and is_instance_valid(_quit_return_focus):
		_quit_return_focus.grab_focus.call_deferred()
	elif _cards.size() > 0:
		_cards[0].grab_focus.call_deferred()
	_quit_return_focus = null


# Restore fullscreen on refocus, and treat a refocus during a Steam session as the game ending
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if _state == State.PLAYING:
		var steam_session: bool = _running_pid <= 0
		if steam_session and Time.get_ticks_msec() - _steam_started_msec > STEAM_RETURN_GRACE_MSEC:
			_end_steam_session()
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# Bind the controller A and B buttons to the built-in UI actions
func _setup_controller_bindings() -> void:
	var accept_button: InputEventJoypadButton = InputEventJoypadButton.new()
	accept_button.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", accept_button):
		InputMap.action_add_event("ui_accept", accept_button)
	var cancel_button: InputEventJoypadButton = InputEventJoypadButton.new()
	cancel_button.button_index = JOY_BUTTON_B
	if not InputMap.action_has_event("ui_cancel", cancel_button):
		InputMap.action_add_event("ui_cancel", cancel_button)


# Add one category header and its horizontal row of cards
func _build_section(category: GameInfo.Category, category_games: Array[GameInfo]) -> void:
	var accent: Color = CATEGORY_COLORS[category]
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 14)
	%CategoryList.add_child(section)
	var header: RichTextLabel = RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("normal_font_size", 24)
	header.add_theme_font_size_override("bold_font_size", 36)
	header.text = "[color=#%s]##[/color] [b][color=#%s]%s[/color][/b] [color=#%s]:: %d[/color]" % [
		Gruvbox.BG3.to_html(false), accent.to_html(false), CATEGORY_TITLES[category],
		Gruvbox.BG3.to_html(false), category_games.size()
	]
	section.add_child(header)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.clip_contents = false
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
	section.add_child(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	scroll.add_child(row)
	for game: GameInfo in category_games:
		var card: GameCard = CARD_SCENE.instantiate() as GameCard
		row.add_child(card)
		card.setup(game, _cards.size())
		card.selected.connect(_on_card_selected)
		card.focus_entered.connect(_on_card_focus_entered.bind(section))
		card.play_entrance(0.05 + float(_cards.size()) * 0.05)
		_cards.append(card)


# Defer the section scroll so it runs after the scroll container's own focus handling
func _on_card_focus_entered(section: Control) -> void:
	_scroll_section_into_view.call_deferred(section)


# Keep the focused card's whole section, including its header, inside the scroll view
func _scroll_section_into_view(section: Control) -> void:
	var scroll: ScrollContainer = %CategoryScroll
	var panel: StyleBox = scroll.get_theme_stylebox("panel")
	var view_height: float = scroll.size.y - panel.get_margin(SIDE_TOP) - panel.get_margin(SIDE_BOTTOM)
	var section_top: float = section.position.y
	var section_bottom: float = section_top + section.size.y
	if section.size.y <= view_height:
		scroll.scroll_vertical = int(clampf(float(scroll.scroll_vertical), section_bottom - view_height, section_top))
	else:
		scroll.scroll_vertical = int(section_bottom - view_height)


# Tree-style summary line under the header listing category counts
func _subheader_bbcode() -> String:
	# var total: int = 0 if _library == null else _library.enabled_games().size()
	var separator: String = " [color=#%s]::[/color] " % Gruvbox.BG3.to_html(false)
	var parts: Array[String] = []
	for category: GameInfo.Category in CATEGORY_ORDER:
		var count: int = 0 if _library == null else _library.games_in_category(category).size()
		if count > 0:
			var title: String = (CATEGORY_TITLES[category] as String).to_lower()
			parts.append("[color=#%s]%d %s[/color]" % [CATEGORY_COLORS[category].to_html(false), count, title])
	# var summary: String = "[color=#%s]└─[/color] %d projects" % [Gruvbox.GRAY.to_html(false), total]
	var summary: String = "[color=#%s]└─[/color] " % [Gruvbox.GRAY.to_html(false)]
	if not parts.is_empty():
		summary += separator + separator.join(parts)
	return summary


# Open the detail view for the chosen game
func _on_card_selected(card: GameCard) -> void:
	if _state != State.ROW:
		return
	_state = State.DETAIL
	_selected_card = card
	%HintBar.text = VIDEO_DETAIL_HINTS if card.game.is_video() else DETAIL_HINTS
	_hide_row()
	%DetailView.open(card.game, card.accent)


# Return to the row once the detail view has finished closing
func _on_detail_closed() -> void:
	_state = State.ROW
	%HintBar.text = ROW_HINTS
	_show_row(_selected_card)


# Route the launch to Steam or a local executable
func _on_launch_requested() -> void:
	if _state != State.DETAIL or _selected_card == null:
		return
	var game: GameInfo = _selected_card.game
	if game.is_steam():
		_launch_steam(game)
	else:
		_launch_local(game)


# Hand the game over to Steam and block the launcher until the player comes back
func _launch_steam(game: GameInfo) -> void:
	var err: Error = OS.shell_open("steam://rungameid/%s" % game.steam_id)
	if err != OK:
		_show_status("Could not reach Steam for %s" % game.title)
		%DetailView.play_error_feedback()
		return
	_state = State.PLAYING
	_running_pid = -1
	_steam_started_msec = Time.get_ticks_msec()
	_session_started_msec = _steam_started_msec
	%DetailView.set_running(true)
	%PlayingOverlay.open(game, _selected_card.accent)
	_show_status("Launching %s through Steam" % game.title)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


# Return from a Steam game once the player comes back to the launcher
func _end_steam_session() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_end_game_session()


# Start a local executable, watch its process, and minimize the launcher
func _launch_local(game: GameInfo) -> void:
	var path: String = game.resolved_executable_path()
	if not FileAccess.file_exists(path):
		_show_status("Executable not found: %s" % path)
		%DetailView.play_error_feedback()
		return
	var pid: int = OS.create_process(path, [])
	if pid <= 0:
		_show_status("Failed to launch %s" % game.title)
		%DetailView.play_error_feedback()
		return
	_state = State.PLAYING
	_running_pid = pid
	_session_started_msec = Time.get_ticks_msec()
	%DetailView.set_running(true)
	%PlayingOverlay.open(game, _selected_card.accent)
	%ProcessTimer.start()
	_show_status("Now playing %s" % game.title)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


# Poll the running game and return to the menu once it exits
func _on_process_timer_timeout() -> void:
	if _running_pid > 0 and OS.is_process_running(_running_pid):
		return
	%ProcessTimer.stop()
	_running_pid = -1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_move_to_foreground()
	_end_game_session()


# Close the playing overlay and ask for feedback before returning to the menu
func _end_game_session() -> void:
	%PlayingOverlay.close()
	%DetailView.set_running(false)
	var duration_seconds: int = maxi(0, int(float(Time.get_ticks_msec() - _session_started_msec) / 1000.0))
	if _selected_card != null and _feedback_enabled():
		_state = State.SURVEY
		%FeedbackSurvey.open(_selected_card.game, _selected_card.accent, duration_seconds)
	else:
		_finish_session()


# Feedback surveys only run on kiosk builds and in the editor
func _feedback_enabled() -> bool:
	return OS.has_feature("kiosk") or OS.has_feature("editor")


# Return to the detail view once the survey is answered or skipped
func _on_survey_finished() -> void:
	if _state == State.SURVEY:
		_finish_session()


# Shared tail of a play session: back to the detail view with a status line
func _finish_session() -> void:
	_state = State.DETAIL
	%DetailView.close()
	if _selected_card != null:
		_show_status("Finished playing %s" % _selected_card.game.title)


# Fade the category rows out while the detail view is open
func _hide_row() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(%CategoryScroll, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void: %CategoryScroll.visible = false)


# Bring the category rows back and restore focus to the last played game
func _show_row(focus_card: GameCard) -> void:
	%CategoryScroll.visible = true
	UIAnimator.slide_in(%CategoryScroll, Vector2(0.0, 20.0), 0.22)
	if focus_card != null:
		focus_card.grab_focus.call_deferred()


# Show a short status message under the row
func _show_status
(message: String) -> void:
	%StatusLabel.text = message
