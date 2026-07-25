class_name QuitDialog
extends Control

signal confirmed
signal cancelled


func _ready() -> void:
	_style_buttons()
	_trap_focus()
	%QuitButton.pressed.connect(_on_quit_pressed)
	%StayButton.pressed.connect(_on_stay_pressed)


func open() -> void:
	visible = true
	%Dim.modulate.a = 0.0
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 1.0, 0.15)
	UIAnimator.pop_in(%Window, 0.25)
	# Deferred so the press that opened the dialog cannot land on a button
	%StayButton.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_stay_pressed()


# Keep directional navigation bouncing between the two buttons
func _trap_focus() -> void:
	var quit_path: NodePath = %QuitButton.get_path()
	var stay_path: NodePath = %StayButton.get_path()
	%QuitButton.focus_neighbor_left = stay_path
	%QuitButton.focus_neighbor_right = stay_path
	%QuitButton.focus_neighbor_top = quit_path
	%QuitButton.focus_neighbor_bottom = quit_path
	%QuitButton.focus_next = stay_path
	%QuitButton.focus_previous = stay_path
	%StayButton.focus_neighbor_left = quit_path
	%StayButton.focus_neighbor_right = quit_path
	%StayButton.focus_neighbor_top = stay_path
	%StayButton.focus_neighbor_bottom = stay_path
	%StayButton.focus_next = quit_path
	%StayButton.focus_previous = quit_path


func _on_quit_pressed() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()


func _on_stay_pressed() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()


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


func _focus_stylebox() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Gruvbox.YELLOW
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
