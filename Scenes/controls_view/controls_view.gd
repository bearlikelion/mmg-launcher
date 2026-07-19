class_name ControlsView
extends Control

signal closed

const LEFT_INPUTS: Array = ["lt", "lb", "left_stick", "dpad", "l3", "back"]
const RIGHT_INPUTS: Array = ["rt", "rb", "y", "b", "a", "x", "right_stick", "r3", "start"]


# Fill the columns for a game and take over input until closed
func open(game: GameInfo, accent: Color) -> void:
	var slug: String = game.title.to_lower().replace(" ", "-")
	%PromptLine.text = "[color=#%s]mark@launcher[/color] [color=#%s]~/games[/color] [color=#%s]$[/color] cat %s/controls.cfg" % [
		Gruvbox.GREEN.to_html(false), Gruvbox.BLUE.to_html(false), Gruvbox.GRAY.to_html(false), slug
	]
	%ControlsTitle.text = "CONTROLS: %s" % game.title.to_upper()
	%ControlsTitle.add_theme_color_override("font_color", accent)
	_populate_column(%LeftColumn, LEFT_INPUTS, game.controls)
	_populate_column(%RightColumn, RIGHT_INPUTS, game.controls)
	visible = true
	%Dim.modulate.a = 0.0
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 1.0, 0.15)
	UIAnimator.pop_in(%Window, 0.25)
	get_viewport().gui_release_focus()
	grab_focus.call_deferred()


# Hide the overlay and hand focus back to the detail view
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# B closes, and A is swallowed so it cannot reach the view underneath
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()


# Build the glyph rows for one side of the controller
func _populate_column(column: VBoxContainer, inputs: Array, controls: Dictionary) -> void:
	for child: Node in column.get_children():
		child.queue_free()
	for input_id: String in inputs:
		if not controls.has(input_id):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_make_glyph(input_id))
		var action: Label = Label.new()
		action.text = String(controls[input_id])
		action.add_theme_color_override("font_color", Gruvbox.FG)
		action.add_theme_font_size_override("font_size", 18)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(action)
		column.add_child(row)


# One controller glyph in the gruvbox style
func _make_glyph(input_id: String) -> Label:
	var text: String = ""
	var color: Color = Gruvbox.FG2
	var glyph_size: Vector2 = Vector2(40.0, 40.0)
	var radius: int = 20
	match input_id:
		"a":
			text = "A"
			color = Gruvbox.GREEN
		"b":
			text = "B"
			color = Gruvbox.RED
		"x":
			text = "X"
			color = Gruvbox.BLUE
		"y":
			text = "Y"
			color = Gruvbox.YELLOW
		"lb", "rb", "lt", "rt":
			text = input_id.to_upper()
			glyph_size = Vector2(54.0, 36.0)
			radius = 12
		"left_stick":
			text = "L"
			color = Gruvbox.AQUA
		"right_stick":
			text = "R"
			color = Gruvbox.AQUA
		"l3", "r3":
			text = input_id.to_upper()
			color = Gruvbox.AQUA
		"dpad":
			text = "✚"
			glyph_size = Vector2(40.0, 40.0)
			radius = 8
		"back":
			text = "BACK"
			glyph_size = Vector2(70.0, 36.0)
			radius = 12
		"start":
			text = "START"
			glyph_size = Vector2(80.0, 36.0)
			radius = 12
	var glyph: Label = Label.new()
	glyph.text = text
	glyph.custom_minimum_size = glyph_size
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.add_theme_color_override("font_color", color)
	glyph.add_theme_font_size_override("font_size", 15 if text.length() > 2 else 18)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Gruvbox.BG0H
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	glyph.add_theme_stylebox_override("normal", style)
	return glyph
