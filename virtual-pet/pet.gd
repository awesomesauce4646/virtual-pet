extends Node2D

const DRAG_THRESHOLD = 6.0

var speed = 300
var direction = Vector2(1,0)
var screen_size = Vector2()
var window_size = Vector2(150,150)

var idle_timer = 0.0
var is_idling = false

var is_dragging = false
var is_thrown = false
var drag_offset = Vector2()
var press_pos = Vector2()
var drag_moved = false

var menuOpened = false
var menuCurrentlyOpened = false

var usable = DisplayServer.screen_get_usable_rect()
var taskbar_y = usable.end.y

var last_mouse = Vector2()
var velocity = Vector2()

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $Area2D
@onready var menu = $PopupMenu
@onready var window = $Window
@onready var meowSound = $MeowSound
@onready var meowTwoSound = $MeowTwoSound

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

func _on_clicked():
	is_idling = true
	idle_timer = 1.5
	speed = 0
	animated_sprite.play("Meow")
	var r = randi() % 2
	if r == 0:
		meowSound.play()
	else:
		meowTwoSound.play()

func _physics_process(delta: float) -> void:
	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging = false
			if not drag_moved:
				_on_clicked()
			elif velocity.length() > 50:
				is_thrown = true
				var r = randi() % 2
				if r == 0:
					meowSound.play()
				else:
					meowTwoSound.play()
				velocity.y = min(velocity.y, -200)
			else:
				velocity = Vector2()
			return

		if not drag_moved:
			if mouse_pos.distance_to(press_pos) < DRAG_THRESHOLD:
				return
			drag_moved = true
			last_mouse = mouse_pos
			if not is_idling:
				animated_sprite.play("Idle")

		velocity = velocity.lerp((mouse_pos - last_mouse) / delta, 0.5)
		last_mouse = mouse_pos
		DisplayServer.window_set_position(Vector2i(mouse_pos - drag_offset))
		return

	if menu.visible:
		return

	if Input.is_action_just_pressed("openMenu"):
		menuCurrentlyOpened = !menuCurrentlyOpened
	if menuCurrentlyOpened:
		window.show()
	else:
		window.hide()

	var window_position = Vector2(DisplayServer.window_get_position())
	var ground_y = taskbar_y - window_size.y

	if is_thrown:
		velocity.y += 1500 * delta
		window_position += velocity * delta
		window_position.x = clamp(window_position.x, 0, screen_size.x - window_size.x)
		if window_position.y < 0:
			window_position.y = 0
			velocity.y = 0
		if window_position.y >= ground_y and velocity.y > 0:
			window_position.y = ground_y
			is_thrown = false
			velocity = Vector2()
		DisplayServer.window_set_position(Vector2i(window_position))
		return

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
			is_thrown = false
			drag_moved = false
			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
			press_pos = mouse_pos
			velocity = Vector2()
			last_mouse = mouse_pos
			var win_pos = Vector2(DisplayServer.window_get_position())
			drag_offset = mouse_pos - win_pos

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		menu.popup_on_parent(Rect2i(Vector2i(event.position.x, event.position.y - 150), Vector2i.ZERO))
		is_idling = true
		speed = 0
		idle_timer = 3.0
		animated_sprite.play("Idle")
