extends Control

var dragging = false
var drag_offset = Vector2i.ZERO

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = Vector2i(get_viewport().get_mouse_position())
		else:
			dragging = false
			
	elif event is InputEventMouseMotion and dragging:
		get_window().position += Vector2i(event.relative)
