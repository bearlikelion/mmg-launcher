class_name FeedbackSurvey
extends Control

signal finished

const NAME_LIMIT: int = 40
const COMMENT_LIMIT: int = 500
const LABEL_WIDTH: float = 270.0
const KEY_ROWS: Array = [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
	["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
	["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
	["z", "x", "c", "v", "b", "n", "m", ".", ",", "?"],
]

var _game: GameInfo = null
var _accent: Color = Gruvbox.AQUA
var _duration_seconds: int = 0
var _answers: Dictionary = {}
var _choice_buttons: Dictionary = {}
var _text_buttons: Dictionary = {}
var _letter_keys: Array[Button] = []
var _entry_key: String = ""
var _entry_text: String = ""
var _shift_on: bool = false
var _shift_button: Button = null
var _first_osk_key: Button = null
var _saving: bool = false


# Build the on-screen keyboard and wire the footer buttons once
func _ready() -> void:
	_build_keyboard()
	%SkipButton.pressed.connect(_finish)
	%SaveButton.pressed.connect(_on_save_pressed)
	%FeedbackButton.pressed.connect(_show_form)
	%BackButton.pressed.connect(_finish)


# Ask whether the player wants to leave feedback after a finished play session
func open(game: GameInfo, accent: Color, duration_seconds: int) -> void:
	_game = game
	_accent = accent
	_duration_seconds = duration_seconds
	_answers = {}
	_saving = false
	%EntryLayer.visible = false
	%Center.visible = false
	%StatusLine.text = ""
	var slug: String = game.title.to_lower().replace(" ", "-")
	%PromptText.text = "[color=#%s]$[/color] [color=#%s]%s exited after %s[/color]" % [
		Gruvbox.GRAY.to_html(false), Gruvbox.FG2.to_html(false), slug, _format_duration(_duration_seconds)
	]
	_style_footer_buttons()
	%PromptLayer.visible = true
	visible = true
	%Dim.modulate.a = 0.0
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 1.0, 0.2)
	UIAnimator.pop_in(%PromptWindow, 0.3)
	await get_tree().create_timer(0.25).timeout
	while Input.is_action_pressed("ui_accept"):
		await get_tree().process_frame
	if visible and %PromptLayer.visible:
		%FeedbackButton.grab_focus()


# Swap the exit prompt for the full survey form
func _show_form() -> void:
	%PromptLayer.visible = false
	%Center.visible = true
	var slug: String = _game.title.to_lower().replace(" ", "-")
	%PromptLine.text = "[color=#%s]mark@launcher[/color] [color=#%s]~/games[/color] [color=#%s]$[/color] ./feedback --game %s" % [
		Gruvbox.GREEN.to_html(false), Gruvbox.BLUE.to_html(false), Gruvbox.GRAY.to_html(false), slug
	]
	_build_form()
	UIAnimator.pop_in(%Window, 0.25)
	await get_tree().create_timer(0.2).timeout
	if visible and %Center.visible and _text_buttons.has("player_name"):
		(_text_buttons["player_name"] as Button).grab_focus()


# Minutes and seconds spent in the game, for the exit prompt line
func _format_duration(seconds: int) -> String:
	var minutes: int = int(float(seconds) / 60.0)
	var remainder: int = seconds % 60
	if minutes > 0:
		return "%dm %02ds" % [minutes, remainder]
	return "%ds" % remainder


# B backs out one layer: keyboard, then form or prompt back to the launcher
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if %EntryLayer.visible:
			_close_entry()
		else:
			_finish()


# Let a physical keyboard type straight into the entry overlay
func _input(event: InputEvent) -> void:
	if not visible or not %EntryLayer.visible:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed:
		return
	get_viewport().set_input_as_handled()
	if key_event.keycode == KEY_BACKSPACE:
		_entry_backspace()
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_ESCAPE:
		_close_entry()
	elif key_event.unicode >= 32 and key_event.unicode != 127:
		_entry_append(char(key_event.unicode))


# Rebuild the question rows for the current game
func _build_form() -> void:
	_choice_buttons.clear()
	_text_buttons.clear()
	for child: Node in %QuestionList.get_children():
		child.queue_free()
	_add_text_row("player_name", "who_are_you", "optional, press A to type")
	_add_choice_row("enjoyed", "enjoyed_it", ["yes", "no"])
	_add_choice_row("fun_rating", "fun_factor", ["1", "2", "3", "4", "5"])
	_add_choice_row("difficulty", "difficulty", ["too easy", "just right", "too hard"])
	_add_choice_row("play_again", "play_again", ["yes", "no"])
	_add_choice_row("would_purchase", "steam_buy", ["yes", "no"])
	_add_choice_row("price_point", "price", ["< $5", "< $10", "< $15", "$20+"])
	_add_choice_row("hit_bugs", "bugs_found", ["yes", "no"])
	_add_text_row("comments", "comments", "press A to type", true)


# One tree-style label shared by all question rows
func _add_row_label(row: HBoxContainer, key_label: String, last: bool) -> void:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("normal_font_size", 18)
	var branch: String = "└─" if last else "├─"
	label.text = "[color=#%s]%s[/color] [color=#%s]%s:[/color]" % [
		Gruvbox.GRAY.to_html(false), branch, Gruvbox.BLUE.to_html(false), key_label
	]
	row.add_child(label)


# Add a single-choice question answered with toggle buttons
func _add_choice_row(key: String, key_label: String, options: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	%QuestionList.add_child(row)
	_add_row_label(row, key_label, false)
	var buttons: Array = []
	for option: String in options:
		var button: Button = Button.new()
		button.text = option
		button.toggle_mode = true
		_style_choice_button(button)
		button.toggled.connect(_on_choice_toggled.bind(key, option, button))
		row.add_child(button)
		buttons.append(button)
	_choice_buttons[key] = buttons


# Add a free-text question answered through the entry overlay
func _add_text_row(key: String, key_label: String, placeholder: String, last: bool = false) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	%QuestionList.add_child(row)
	_add_row_label(row, key_label, last)
	var button: Button = Button.new()
	button.text = placeholder
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_choice_button(button)
	button.toggle_mode = false
	button.add_theme_color_override("font_color", Gruvbox.GRAY)
	button.set_meta("placeholder", placeholder)
	button.pressed.connect(_open_entry.bind(key))
	row.add_child(button)
	_text_buttons[key] = button


# Radio behavior: selecting one option releases the others in its row
func _on_choice_toggled(pressed_state: bool, key: String, value: String, button: Button) -> void:
	if pressed_state:
		_answers[key] = value
		for other: Button in _choice_buttons[key]:
			if other != button and other.button_pressed:
				other.set_pressed_no_signal(false)
	elif String(_answers.get(key, "")) == value:
		_answers.erase(key)


# Open the text entry overlay for a name or comments field
func _open_entry(key: String) -> void:
	_entry_key = key
	_entry_text = String(_answers.get(key, ""))
	%EntryTitle.text = "who are you?" if key == "player_name" else "any comments?"
	_refresh_entry_display()
	%EntryLayer.visible = true
	if _first_osk_key != null:
		_first_osk_key.grab_focus()


# Store the typed text and return focus to the form
func _close_entry() -> void:
	var trimmed: String = _entry_text.strip_edges()
	if trimmed.is_empty():
		_answers.erase(_entry_key)
	else:
		_answers[_entry_key] = trimmed
	var button: Button = _text_buttons.get(_entry_key) as Button
	if button != null:
		if trimmed.is_empty():
			button.text = String(button.get_meta("placeholder"))
			button.add_theme_color_override("font_color", Gruvbox.GRAY)
		else:
			button.text = trimmed
			button.add_theme_color_override("font_color", Gruvbox.FG)
	%EntryLayer.visible = false
	if button != null:
		button.grab_focus()


# Append one character to the entry, respecting the field's length limit
func _entry_append(character: String) -> void:
	var limit: int = NAME_LIMIT if _entry_key == "player_name" else COMMENT_LIMIT
	if _entry_text.length() >= limit:
		return
	_entry_text += character
	if _shift_on and _shift_button != null:
		_shift_button.button_pressed = false
	_refresh_entry_display()


# Remove the last character of the entry
func _entry_backspace() -> void:
	if _entry_text.is_empty():
		return
	_entry_text = _entry_text.substr(0, _entry_text.length() - 1)
	_refresh_entry_display()


# Show the typed text with a terminal caret
func _refresh_entry_display() -> void:
	%EntryDisplay.text = _entry_text + "▌"


# Build the controller-navigable keyboard grid
func _build_keyboard() -> void:
	_letter_keys.clear()
	for key_row: Array in KEY_ROWS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		%KeyRows.add_child(row)
		for key_char: String in key_row:
			var key_button: Button = _make_key(key_char, Vector2(52.0, 46.0))
			key_button.pressed.connect(_on_key_pressed.bind(key_button))
			row.add_child(key_button)
			if key_char >= "a" and key_char <= "z":
				_letter_keys.append(key_button)
			if _first_osk_key == null and key_char == "q":
				_first_osk_key = key_button
	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	%KeyRows.add_child(bottom_row)
	_shift_button = _make_key("⇧ shift", Vector2(110.0, 46.0))
	_shift_button.toggle_mode = true
	_shift_button.toggled.connect(_set_shift)
	bottom_row.add_child(_shift_button)
	var space_button: Button = _make_key("space", Vector2(240.0, 46.0))
	space_button.pressed.connect(_entry_append.bind(" "))
	bottom_row.add_child(space_button)
	var backspace_button: Button = _make_key("⌫", Vector2(80.0, 46.0))
	backspace_button.pressed.connect(_entry_backspace)
	bottom_row.add_child(backspace_button)
	var done_button: Button = _make_key("done", Vector2(110.0, 46.0))
	done_button.add_theme_color_override("font_color", Gruvbox.GREEN)
	done_button.pressed.connect(_close_entry)
	bottom_row.add_child(done_button)


# One styled keyboard key
func _make_key(label: String, minimum_size: Vector2) -> Button:
	var key_button: Button = Button.new()
	key_button.text = label
	key_button.custom_minimum_size = minimum_size
	key_button.add_theme_stylebox_override("normal", _flat_stylebox(Gruvbox.BG0H, Gruvbox.BG3, 1))
	key_button.add_theme_stylebox_override("hover", _flat_stylebox(Gruvbox.BG1, Gruvbox.GRAY, 1))
	key_button.add_theme_stylebox_override("pressed", _flat_stylebox(Gruvbox.BG2, Gruvbox.FG2, 1))
	key_button.add_theme_stylebox_override("focus", _focus_stylebox())
	key_button.add_theme_color_override("font_color", Gruvbox.FG2)
	return key_button


# Type the pressed key, honoring the shift toggle for letters
func _on_key_pressed(key_button: Button) -> void:
	_entry_append(key_button.text)


# Toggle the keyboard between lowercase and uppercase letters
func _set_shift(enabled: bool) -> void:
	_shift_on = enabled
	for key_button: Button in _letter_keys:
		key_button.text = key_button.text.to_upper() if enabled else key_button.text.to_lower()


# Persist the response and close with a short confirmation
func _on_save_pressed() -> void:
	if _saving:
		return
	_saving = true
	var row: Dictionary = {
		"game_title": _game.title,
		"played_at": Time.get_datetime_string_from_system(false, true),
		"duration_seconds": _duration_seconds,
	}
	if _answers.has("player_name"):
		row["player_name"] = _answers["player_name"]
	if _answers.has("enjoyed"):
		row["enjoyed"] = _answers["enjoyed"]
	if _answers.has("fun_rating"):
		row["fun_rating"] = int(_answers["fun_rating"])
	if _answers.has("difficulty"):
		row["difficulty"] = _answers["difficulty"]
	if _answers.has("play_again"):
		row["play_again"] = _answers["play_again"]
	if _answers.has("would_purchase"):
		row["would_purchase"] = _answers["would_purchase"]
	if _answers.has("price_point"):
		row["price_point"] = _answers["price_point"]
	if _answers.has("hit_bugs"):
		row["hit_bugs"] = _answers["hit_bugs"]
	if _answers.has("comments"):
		row["comments"] = _answers["comments"]
	var saved: bool = FeedbackDB.save_response(row)
	var status: String = "saved, thanks o7" if saved else "save failed, sorry"
	var status_color: Color = Gruvbox.GREEN if saved else Gruvbox.RED
	%StatusLine.text = "[color=#%s]└─[/color] [color=#%s]%s[/color]" % [
		Gruvbox.GRAY.to_html(false), status_color.to_html(false), status
	]
	await get_tree().create_timer(0.9).timeout
	_finish()


# Hide the survey and hand control back to the launcher
func _finish() -> void:
	if not visible:
		return
	visible = false
	finished.emit()


# Accent-aware styles for answer buttons
func _style_choice_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _flat_stylebox(Gruvbox.BG0H, Gruvbox.BG3, 1))
	button.add_theme_stylebox_override("hover", _flat_stylebox(Gruvbox.BG1, _accent, 1))
	button.add_theme_stylebox_override("pressed", _flat_stylebox(Color(_accent, 0.22), _accent, 1))
	button.add_theme_stylebox_override("focus", _focus_stylebox())
	button.add_theme_color_override("font_color", Gruvbox.FG2)
	button.add_theme_color_override("font_pressed_color", _accent)
	button.add_theme_color_override("font_hover_color", Gruvbox.FG)
	button.add_theme_font_size_override("font_size", 17)


# Style the prompt, skip, and save buttons
func _style_footer_buttons() -> void:
	%FeedbackButton.add_theme_stylebox_override("normal", _flat_stylebox(Color(Gruvbox.GREEN, 0.08), Gruvbox.GREEN, 1))
	%FeedbackButton.add_theme_stylebox_override("hover", _flat_stylebox(Color(Gruvbox.GREEN, 0.2), Gruvbox.GREEN, 1))
	%FeedbackButton.add_theme_stylebox_override("focus", _focus_stylebox())
	%FeedbackButton.add_theme_color_override("font_color", Gruvbox.GREEN)
	%BackButton.add_theme_stylebox_override("normal", _flat_stylebox(Gruvbox.BG0H, Gruvbox.BG3, 1))
	%BackButton.add_theme_stylebox_override("hover", _flat_stylebox(Gruvbox.BG1, Gruvbox.GRAY, 1))
	%BackButton.add_theme_stylebox_override("focus", _focus_stylebox())
	%BackButton.add_theme_color_override("font_color", Gruvbox.GRAY)
	%SkipButton.add_theme_stylebox_override("normal", _flat_stylebox(Gruvbox.BG0H, Gruvbox.BG3, 1))
	%SkipButton.add_theme_stylebox_override("hover", _flat_stylebox(Gruvbox.BG1, Gruvbox.GRAY, 1))
	%SkipButton.add_theme_stylebox_override("focus", _focus_stylebox())
	%SkipButton.add_theme_color_override("font_color", Gruvbox.GRAY)
	%SaveButton.add_theme_stylebox_override("normal", _flat_stylebox(Color(Gruvbox.GREEN, 0.08), Gruvbox.GREEN, 1))
	%SaveButton.add_theme_stylebox_override("hover", _flat_stylebox(Color(Gruvbox.GREEN, 0.2), Gruvbox.GREEN, 1))
	%SaveButton.add_theme_stylebox_override("focus", _focus_stylebox())
	%SaveButton.add_theme_color_override("font_color", Gruvbox.GREEN)


# Shared rounded stylebox for buttons and keys
func _flat_stylebox(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


# Yellow outline used for the focused control
func _focus_stylebox() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Gruvbox.YELLOW
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
