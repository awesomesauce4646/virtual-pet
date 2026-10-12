extends Node2D

$PopupMenu.add_item("Sleep", 0)
$PopupMenu.popup_on_parent(Rect2i(Vector2i(event.position), Vector2i..ZERO))
$PopupMenu.id_pressed.connect(_on_menu_pressed)

func _on_menu_pressed(id):
	if id == 0
		print("SLEEP")
