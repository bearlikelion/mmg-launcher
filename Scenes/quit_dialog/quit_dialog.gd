class_name QuitDialog
extends Control

signal confirmed
signal cancelled


# Style the two choices and wire their presses once
func _ready() -> void:
	_style_buttons()
	%QuitButton.pressed.connect(_on_quit_pressed)
	%StayButton.pressed.connect(_on_stay_pressed)


# Pop the confirmation window and focus the safe option
func open() -> void:
	visible = true
	%Dim.modulate.a = 0.0
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 1.0, 0.15)
	UIAnimator.pop_in(%Window, 0.25)
	%StayButton.grab_focus()


# B or Esc backs out without quitting
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_stay_pressed()


# Confirm: hide and hand the actual quit back to the launcher
func _on_quit_pressed() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()


# Cancel: hide and let the launcher restore focus
func _on_stay_pressed() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()


# Red danger styling for quitting, green safe styling for staying
func _style_buttons() -> void:
	%QuitButton.add_theme_stylebox_override("normal", _flat_stylebox(Color(Gruvbox.RED, 0.08), Gruvbox.RED, 1))
	%QuitButton.add_theme_stylebox_override("hover", _flat_stylebox(Color(Gruvbox.RED, 0.2), Gruvbox.RED, 1))
	%QuitButton.add_theme_stylebox_override("focus", _focus_stylebox())
	%QuitButton.add_theme_color_override("font_color", Gruvbox.RED)
	%QuitButton.add_theme_color_override("font_hover_color", Gruvbox.FG)
	%StayButton.add_theme_stylebox_override("normal", _flat_stylebox(Color(Gruvbox.GREEN, 0.08), Gruvbox.GREEN, 1))
	%StayButton.add_theme_stylebox_override("hover", _flat_stylebox(Color(Gruvbox.GREEN, 0.2), Gruvbox.GREEN, 1))
	%StayButton.add_theme_stylebox_override("focus", _focus_stylebox())
	%StayButton.add_theme_color_override("font_color", Gruvbox.GREEN)
	%StayButton.add_theme_color_override("font_hover_color", Gruvbox.FG)


# Shared rounded stylebox for the dialog buttons
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
