extends Node2D

var speed = 300
var direction = Vector2(1,0)
var screen_size = Vector2()
var window_size = Vector2(150,150)

var idle_timer = 0.0
var is_idling = false

var is_dragging = false
var drag_offset = Vector2()

var usable = DisplayServer.screen_get_usable_rect()
var taskbar_y = usable.end.y

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $Area2D
@onready var menu = $PopupMenu

func _ready():
	screen_size = Vector2(DisplayServer.screen_get_size())
	animated_sprite.play("Run")
	area.input_event.connect(_on_area_input)
	menu.add_item("Sleep", 0)
	menu.id_pressed.connect(_on_menu_pressed)
	menu.add_item("Feed", 1)

func _on_menu_pressed(id):
	if id == 0:
		is_idling = true
		idle_timer = 7.0
		speed = 0
		animated_sprite.play("Sleep")
	if id == 1:
		is_idling = true
		idle_timer = 4.0
		speed = 0
		animated_sprite.play("Feed")
		
func _physics_process(delta: float) -> void:
	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var new_win_pos = mouse_pos - drag_offset
		DisplayServer.window_set_position(Vector2i(new_win_pos))
		return
	
	var window_position = Vector2(DisplayServer.window_get_position())
	var ground_y = taskbar_y - window_size.y
	
	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 300 
			animated_sprite.play("Run")
	
	if window_position.y < ground_y:
		animated_sprite.play("Idle")
		window_position.y += 600 * delta
		if window_position.y > ground_y:
			window_position.y = ground_y
	else:
		window_position.y = ground_y
		if not is_idling:
			animated_sprite.play("Run")
			window_position.x += direction.x * speed * delta
			window_position.x = clamp(window_position.x, 0, screen_size.x - window_size.x)
			if window_position.x <= 0 or window_position.x >= screen_size.x - window_size.x:
				direction.x *= -1
				animated_sprite.flip_h = !animated_sprite.flip_h
				maybe_idle()
		
	DisplayServer.window_set_position(Vector2i(window_position))

func maybe_idle():
	if randf() < 0.3:
		is_idling = true
		idle_timer = randf_range(1.0, 3.0)
		var r = randi() % 3
		if r == 0:
			animated_sprite.play("Idle")
			speed = 0
		elif r == 1:
			animated_sprite.play("Sit")
			speed = 0
		else:
			animated_sprite.play("Meow")
			speed = 0

func _on_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			if not is_idling:
				animated_sprite.play("Idle")
			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
			var win_pos = Vector2(DisplayServer.window_get_position())
			drag_offset = mouse_pos - win_pos
		else:
			is_dragging = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		menu.popup_on_parent(Rect2i(Vector2i(event.position.x, event.position.y - 150), Vector2i.ZERO))
		is_idling = true
		speed = 0
		idle_timer = 3.0
		animated_sprite.play("Idle")
		await get_tree().create_timer(3.0).timeout
		speed = 300
		
