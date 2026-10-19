extends Node2D

const DRAG_THRESHOLD = 6.0
const JUMP_COOLDOWN = .6
const OBSTACLE_START_X = 800.0
const CAT_GROUND_Y = 323.0

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
var gameOpened = false
var gameCurrentlyOpened = false

var gameRunning = false
var is_jumping = false
var jump_cooldown_timer = 0.0
var score = 0

var usable = DisplayServer.screen_get_usable_rect()
var taskbar_y = usable.end.y

var last_mouse = Vector2()
var velocity = Vector2()

@onready var animated_sprite = $AnimatedSprite2D
@onready var gameCat = $GameWindow/GameCat
@onready var gameArea = $GameWindow/GameCat/Area2D
@onready var area = $Area2D
@onready var menu = $PopupMenu
@onready var window = $Window
@onready var meowSound = $MeowSound
@onready var meowTwoSound = $MeowTwoSound
@onready var particles = $Particles
@onready var windowText = $Window/Text
@onready var aboutButton = $Window/Button
@onready var pictureButton = $Window/Button2
@onready var beanPic = $Window/BeanPicture
@onready var homeButton = $Window/Button3
@onready var gameWindow = $GameWindow
@onready var obstacle = $GameWindow/Obstacle
@onready var readyText = $GameWindow/Text2
@onready var gameOverText = $GameWindow/Text3
@onready var scoreText = $GameWindow/Score


func _ready():
	screen_size = Vector2(DisplayServer.screen_get_size())
	animated_sprite.play("Run")
	area.input_event.connect(_on_area_input)
	menu.add_item("Sleep", 0)
	menu.id_pressed.connect(_on_menu_pressed)
	menu.add_item("Feed", 1)
	menu.add_item("Play", 2)
	gameCat.animation_finished.connect(_on_game_cat_animation_finished)
	gameArea.area_entered.connect(_on_game_cat_hit)

func _on_game_cat_animation_finished():
	if gameCat.animation == "Jump":
		is_jumping = false
		jump_cooldown_timer = JUMP_COOLDOWN
		gameCat.play("Run")

func _on_game_cat_hit(other_area):
	if not gameRunning:
		return
	if other_area == obstacle or other_area.get_parent() == obstacle:
		game_over()

func game_over():
	gameOverText.show()
	gameRunning = false
	is_jumping = false
	jump_cooldown_timer = 0.0
	obstacle.position.x = OBSTACLE_START_X
	gameCat.position.y = CAT_GROUND_Y
	gameCat.play("Death") 

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
	if id == 2:
		gameCurrentlyOpened = !gameCurrentlyOpened
		if gameCurrentlyOpened:
			gameWindow.show()
			readyText.show()
			gameCat.play("Sit")
		else:
			gameWindow.hide()
			gameRunning = false
			is_jumping = false
			obstacle.position.x = OBSTACLE_START_X
			gameCat.position.y = CAT_GROUND_Y
			gameCat.play("Sit")

func _on_clicked():
	particles.restart()
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
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta

	if gameRunning:
		obstacle.position.x += -500 * delta
		scoreText.text = "SCORE: " + str(score)
		if obstacle.position.x < -70:
			obstacle.position.x = OBSTACLE_START_X
			score = score + 1

	if is_jumping:
		gameCat.position.y += -300 * delta
		if gameCat.position.y < 225.0:
			gameCat.position.y = 225
			is_jumping = false
	else:
		gameCat.position.y = min(gameCat.position.y + 300 * delta, CAT_GROUND_Y)

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

	if Input.is_action_just_pressed("startGame") && gameCurrentlyOpened:
		score = 0
		scoreText.show()
		readyText.hide()
		gameOverText.hide()
		if not is_jumping and not gameRunning:
			obstacle.position.x = OBSTACLE_START_X
			gameCat.play("Run")
			gameRunning = true

	if Input.is_action_just_pressed("jump") && gameCurrentlyOpened:
		if not is_jumping and jump_cooldown_timer <= 0:
			is_jumping = true
			gameCat.play("Jump")

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


func _on_button_pressed() -> void:
	windowText.show()
	beanPic.hide()
	windowText.text = "Bean is our beloved robotics shop cat who used to be a stray on the property. The mentor took her in, and now she roams around as we build the robot!"


func _on_button_2_pressed() -> void:
	beanPic.show()
	windowText.hide()


func _on_button_3_pressed() -> void:
	beanPic.hide()
	windowText.show()
	windowText.text = "Thanks for using BeanPet!
Bean is the name of the cat you see running around on your screen."
