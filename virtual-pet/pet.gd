extends Node2D

const DRAG_THRESHOLD = 6.0
const JUMP_COOLDOWN = .6
const OBSTACLE_START_X = 800.0
const CAT_GROUND_Y = 388.0
const HAPPINESS_INTERVAL = 30.0
const HAPPINESS_DECAY = 2
const HUNGER_INTERVAL = 20.0
const HUNGER_DECAY = 2
const ENERGY_INTERVAL = 40.0
const ENERGY_DECAY = 2
const TREE_START_X = 555
const COLLISION_EPSILON = 1.0
const WALL_BOUNCE = 0.5
const CEILING_BOUNCE = 0.3
const ENERGY_SLEEP_THRESHOLD = 10
const ENERGY_WAKE_LEVEL = 30
const ENERGY_SLEEP_RECOVERY = 4.0
const LAND_BOUNCE = 0.5
const BOUNCE_MIN_SPEED = 700.0


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
var statsCurrentlyOpened = false
var settingsCurrentlyOpened = false


var gameRunning = false
var is_jumping = false
var jump_cooldown_timer = 0.0
var score = 0

var usable = DisplayServer.screen_get_usable_rect()
var taskbar_y = usable.end.y

var last_mouse = Vector2()
var velocity = Vector2()

var happiness = 100
var happiness_timer = 0.0
var energy = 100
var energy_timer = 0.0
var hunger = 100
var hunger_timer = 0.0
var is_forced_sleeping = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var gameCat = $GameWindow/GameCat
@onready var gameArea = $GameWindow/GameCat/Area2D
@onready var area = $Area2D
@onready var menu = $PopupMenu
@onready var window = $Window
@onready var meowSound = $MeowSound
@onready var meowTwoSound = $MeowTwoSound
@onready var particles = $Particles
@onready var windowTitle = $Window/Title
@onready var windowSubtext = $Window/Subline
@onready var aboutButton = $Window/Button
@onready var pictureButton = $Window/Button2
@onready var beanPic = $Window/BeanPicture
@onready var homeButton = $Window/Button3
@onready var gameWindow = $GameWindow
@onready var obstacle = $GameWindow/Obstacle
@onready var readyText = $GameWindow/Text2
@onready var gameOverText = $GameWindow/Text3
@onready var scoreText = $GameWindow/Score
@onready var happinessText = $StatsWindow/Happiness
@onready var statsWindow = $StatsWindow
@onready var energyText = $StatsWindow/Energy
@onready var hungerText = $StatsWindow/Hunger
@onready var deathSound = $DeathSound
@onready var jumpSound = $JumpSound
@onready var purrSound = $PurrSound
@onready var eatingSound = $NomSound
@onready var pointSound = $PointSound

@onready var treeOne = $GameWindow/Tree1
@onready var treeTwo = $GameWindow/Tree2
@onready var treeThree = $GameWindow/Tree3
@onready var treeFour = $GameWindow/Tree4
@onready var treeFive = $GameWindow/Tree5

@onready var spadeOne = $StatsWindow/Spade1
@onready var spadeTwo = $StatsWindow/Spade2
@onready var spadeThree = $StatsWindow/Spade3
@onready var spadeFour = $StatsWindow/Spade4
@onready var spadeFive = $StatsWindow/Spade5
@onready var clubsOne = $StatsWindow/Club1
@onready var clubsTwo = $StatsWindow/Club2
@onready var clubsThree = $StatsWindow/Club3
@onready var clubsFour = $StatsWindow/Club4
@onready var clubsFive = $StatsWindow/Club5
@onready var heartOne = $StatsWindow/Heart1
@onready var heartTwo = $StatsWindow/Heart2
@onready var heartThree = $StatsWindow/Heart3
@onready var heartFour = $StatsWindow/Heart4
@onready var heartFive = $StatsWindow/Heart5

@onready var statsCollision = $StatsWindow/Area2D
@onready var infoCollision = $Window/Area2D
@onready var gameCollision = $GameWindow/Area2D
@onready var settingsCollision = $SettingsWindow/Area2D

@onready var settingsWindow = $SettingsWindow

func save_stats():
	var config = ConfigFile.new()
	config.set_value("pet", "happiness", happiness)
	config.set_value("pet", "energy", energy)
	config.set_value("pet", "hunger", hunger)
	config.save("user://pet.cfg")

func load_stats():
	var config = ConfigFile.new()
	if config.load("user://pet.cfg") == OK:
		happiness = clamp(config.get_value("pet", "happiness", 100), 0, 100)
		energy = clamp(config.get_value("pet", "energy", 100), 0, 100)
		hunger = clamp(config.get_value("pet", "hunger", 100), 0, 100)


func get_blocking_rects() -> Array:
	var rects = []
	for w in [window, gameWindow, statsWindow]:
		if w.visible:
			rects.append(Rect2(Vector2(w.get_position_with_decorations()), Vector2(w.get_size_with_decorations())))
	return rects

func get_ground_y(pos: Vector2) -> float:
	var ground = taskbar_y - window_size.y
	for r in get_blocking_rects():
		var overlaps_x = pos.x + window_size.x > r.position.x and pos.x < r.end.x
		if overlaps_x and pos.y + window_size.y <= r.position.y + COLLISION_EPSILON:
			ground = min(ground, r.position.y - window_size.y)
	return ground

func face(dir_x: float):
	if abs(dir_x) > 1.0:
		direction.x = sign(dir_x)
		animated_sprite.flip_h = direction.x < 0


func _ready():
	load_stats()
	screen_size = Vector2(DisplayServer.screen_get_size())
	animated_sprite.play("Run")
	area.input_event.connect(_on_area_input)
	menu.add_item("Sleep", 0)
	menu.id_pressed.connect(_on_menu_pressed)
	menu.add_item("Feed", 1)
	menu.add_item("Play", 2)
	menu.add_item("Stats", 3)
	menu.add_item("Settings", 4)
	gameCat.animation_finished.connect(_on_game_cat_animation_finished)
	gameArea.area_entered.connect(_on_game_cat_hit)
	window.close_requested.connect(_on_window_close_requested)
	gameWindow.close_requested.connect(_on_game_window_close_requested)
	statsWindow.close_requested.connect(_on_stats_window_close_requested)
	settingsWindow.close_requested.connect(_on_stats_window_close_requested)



func _on_window_close_requested():
	menuCurrentlyOpened = false
	window.hide()
func _on_stats_window_close_requested():
	statsCurrentlyOpened = false
	statsWindow.hide()

func _on_game_window_close_requested():
	gameCurrentlyOpened = false
	gameWindow.hide()
	gameRunning = false
	is_jumping = false
	jump_cooldown_timer = 0.0
	obstacle.position.x = OBSTACLE_START_X
	gameCat.position.y = CAT_GROUND_Y
	gameCat.play("Sit")

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
	deathSound.play()

func _on_menu_pressed(id):
	if id == 0:
		is_idling = true
		idle_timer = 7.0
		speed = 0
		animated_sprite.play("Sleep")
		purrSound.play()
		energy = min(energy + 10, 100)
		save_stats()
	if id == 1:
		is_idling = true
		idle_timer = .8
		speed = 0
		animated_sprite.play("Feed")
		eatingSound.play()
		hunger = min(hunger + 10, 100)
		save_stats()
	if id == 2:
		gameCurrentlyOpened = !gameCurrentlyOpened
		if gameCurrentlyOpened:
			save_stats()
			gameWindow.show()
			readyText.show()
			gameOverText.hide()
			gameCat.play("Sit")
		else:
			gameWindow.hide()
			gameRunning = false
			is_jumping = false
			obstacle.position.x = OBSTACLE_START_X
			gameCat.position.y = CAT_GROUND_Y
			gameCat.play("Sit")
	if id == 3:
		statsCurrentlyOpened = !statsCurrentlyOpened
		if statsCurrentlyOpened:
			statsWindow.show()
		else:
			statsWindow.hide()
	if id == 4:
		settingsCurrentlyOpened = !settingsCurrentlyOpened
		if settingsCurrentlyOpened:
			settingsWindow.show()
		else:
			settingsWindow.hide()

func _on_clicked():
	particles.restart()
	if happiness < 99.5:
		happiness = happiness + .5
		save_stats()
	else:
		happiness = 100
		save_stats()
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
	if happiness > 80 && hunger > 80:
		speed = 500
	elif happiness > 60 && hunger > 60:
		speed = 400
	else:
		speed = 300
	happiness_timer += delta
	#happinessText.text = "MOOD: " + str(happiness)
	energy_timer += delta
	#energyText.text = "ENERGY: " + str(energy)
	hunger_timer += delta
	#hungerText.text = "HUNGER: " + str(hunger)
	
	if happiness >= 80:
		clubsOne.show()
		clubsTwo.show()
		clubsThree.show()
		clubsFour.show()
		clubsFive.show()
	elif happiness >= 60:
		clubsOne.show()
		clubsTwo.show()
		clubsThree.show()
		clubsFour.show()
		clubsFive.hide()
	elif happiness >= 40:
		clubsOne.show()
		clubsTwo.show()
		clubsThree.show()
		clubsFour.hide()
		clubsFive.hide()
	elif happiness >= 20:
		clubsOne.show()
		clubsTwo.show()
		clubsThree.hide()
		clubsFour.hide()
		clubsFive.hide()
	elif happiness >= 10:
		clubsOne.show()
		clubsTwo.hide()
		clubsThree.hide()
		clubsFour.hide()
		clubsFive.hide()
	else:
		clubsOne.hide()
		clubsTwo.hide()
		clubsThree.hide()
		clubsFour.hide()
		clubsFive.hide()	
	
	if energy >= 80:
		heartOne.show()
		heartTwo.show()
		heartThree.show()
		heartFour.show()
		heartFive.show()
	elif energy >= 60:
		heartOne.show()
		heartTwo.show()
		heartThree.show()
		heartFour.show()
		heartFive.hide()
	elif energy >= 40:
		heartOne.show()
		heartTwo.show()
		heartThree.show()
		heartFour.hide()
		heartFive.hide()
	elif energy >= 20:
		heartOne.show()
		heartTwo.show()
		heartThree.hide()
		heartFour.hide()
		heartFive.hide()
	elif energy >= 10:
		heartOne.show()
		heartTwo.hide()
		heartThree.hide()
		heartFour.hide()
		heartFive.hide()
	else:
		heartOne.hide()
		heartTwo.hide()
		heartThree.hide()
		heartFour.hide()
		heartFive.hide()	
	
	if hunger >= 80:
		spadeOne.show()
		spadeTwo.show()
		spadeThree.show()
		spadeFour.show()
		spadeFive.show()
	elif hunger >= 60:
		spadeOne.show()
		spadeTwo.show()
		spadeThree.show()
		spadeFour.show()
		spadeFive.hide()
	elif hunger >= 40:
		spadeOne.show()
		spadeTwo.show()
		spadeThree.show()
		spadeFour.hide()
		spadeFive.hide()
	elif hunger >= 20:
		spadeOne.show()
		spadeTwo.show()
		spadeThree.hide()
		spadeFour.hide()
		spadeFive.hide()
	elif hunger >= 10:
		spadeOne.show()
		spadeTwo.hide()
		spadeThree.hide()
		spadeFour.hide()
		spadeFive.hide()
	else:
		spadeOne.hide()
		spadeTwo.hide()
		spadeThree.hide()
		spadeFour.hide()
		spadeFive.hide()	
		
	if happiness_timer >= HAPPINESS_INTERVAL:
		happiness_timer -= HAPPINESS_INTERVAL
		happiness = max(happiness - HAPPINESS_DECAY, 0)
		save_stats()
		
	if energy_timer >= ENERGY_INTERVAL:
		energy_timer -= ENERGY_INTERVAL
		energy = max(energy - ENERGY_DECAY, 0)
		save_stats()
		
	if hunger_timer >= HUNGER_INTERVAL:
		hunger_timer -= HUNGER_INTERVAL
		hunger = max(hunger - HUNGER_DECAY, 0)
		save_stats()
		
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	
	if gameRunning:
		obstacle.position.x += -500 * delta
		treeOne.position.x += -350 * delta
		treeTwo.position.x += -350 * delta
		treeThree.position.x += -350 * delta
		treeFour.position.x += -350 * delta
		treeFive.position.x += -350 * delta
		scoreText.text = "SCORE: " + str(score)
		if obstacle.position.x < -50:
			obstacle.position.x = OBSTACLE_START_X + randi_range(0, 300)
			score += 1
			happiness = min(happiness + 5, 100)
			if score % 5 == 0:
				pointSound.play()
		if treeOne.position.x < -120:
			treeOne.position.x = TREE_START_X
		if treeTwo.position.x < -120:
			treeTwo.position.x = TREE_START_X
		if treeThree.position.x < -120:
			treeThree.position.x = TREE_START_X
		if treeFour.position.x < -120:
			treeFour.position.x = TREE_START_X
		if treeFive.position.x < -120:
			treeFive.position.x = TREE_START_X
			
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
				animated_sprite.play("Pounce")
				face(velocity.x)
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
			animated_sprite.play("Crouch")
			last_mouse = mouse_pos

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

	if Input.is_action_just_pressed("jump") && gameCurrentlyOpened && gameRunning:
		if not is_jumping and jump_cooldown_timer <= 0:
			is_jumping = true
			gameCat.play("Jump")
			jumpSound.play()

	if is_thrown:
		is_forced_sleeping = false
	elif energy < ENERGY_SLEEP_THRESHOLD and not is_forced_sleeping:
		is_forced_sleeping = true
		purrSound.play()

	if is_forced_sleeping:
		energy = min(energy + ENERGY_SLEEP_RECOVERY * delta, 100)
		is_idling = true
		idle_timer = 1.0
		speed = 0
		if animated_sprite.animation != "Sleep":
			animated_sprite.play("Sleep")
		if energy >= ENERGY_WAKE_LEVEL:
			is_forced_sleeping = false
			idle_timer = 0.0
			save_stats()

	var window_position = Vector2(DisplayServer.window_get_position())

	if is_thrown:
		var rects = get_blocking_rects()
		var old_pos = window_position
		var new_pos = old_pos
		var vx = velocity.x
		velocity.y += 1500 * delta
		var vy = velocity.y

		new_pos.x += vx * delta
		var max_x = screen_size.x - window_size.x
		if new_pos.x < 0:
			new_pos.x = 0
			velocity.x = abs(vx) * WALL_BOUNCE
			face(velocity.x)
		elif new_pos.x > max_x:
			new_pos.x = max_x
			velocity.x = -abs(vx) * WALL_BOUNCE
			face(velocity.x)
		for r in rects:
			var overlaps_y = old_pos.y + window_size.y > r.position.y + COLLISION_EPSILON and old_pos.y < r.end.y - COLLISION_EPSILON
			if not overlaps_y:
				continue
			if vx > 0 and old_pos.x + window_size.x <= r.position.x + COLLISION_EPSILON and new_pos.x + window_size.x > r.position.x:
				new_pos.x = r.position.x - window_size.x
				velocity.x = -abs(vx) * WALL_BOUNCE
				face(-1.0 * 2.0)
			elif vx < 0 and old_pos.x >= r.end.x - COLLISION_EPSILON and new_pos.x < r.end.x:
				new_pos.x = r.end.x
				velocity.x = abs(vx) * WALL_BOUNCE
				face(1.0 * 2.0)

		var landed = false
		new_pos.y += vy * delta
		for r in rects:
			var overlaps_x = new_pos.x + window_size.x > r.position.x and new_pos.x < r.end.x
			if not overlaps_x:
				continue
			if vy > 0 and old_pos.y + window_size.y <= r.position.y + COLLISION_EPSILON and new_pos.y + window_size.y > r.position.y:
				new_pos.y = r.position.y - window_size.y
				if vy > BOUNCE_MIN_SPEED:
					velocity.y = -vy * LAND_BOUNCE
				else:
					landed = true
			elif vy < 0 and old_pos.y >= r.end.y - COLLISION_EPSILON and new_pos.y < r.end.y:
				new_pos.y = r.end.y
				velocity.y = abs(vy) * CEILING_BOUNCE

		if new_pos.y < 0:
			new_pos.y = 0
			velocity.y = abs(velocity.y) * WALL_BOUNCE

		var thrown_ground_y = taskbar_y - window_size.y
		if new_pos.y >= thrown_ground_y and vy > 0:
			new_pos.y = thrown_ground_y
			if vy > BOUNCE_MIN_SPEED:
				velocity.y = -vy * LAND_BOUNCE
			else:
				landed = true

		if landed:
			is_thrown = false
			velocity = Vector2()

		DisplayServer.window_set_position(Vector2i(new_pos))
		return

	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = 300
			animated_sprite.play("Run")

	var ground_y = get_ground_y(window_position)

	if window_position.y < ground_y:
		animated_sprite.play("Idle")
		window_position.y += 600 * delta
		if window_position.y > ground_y:
			window_position.y = ground_y
	else:
		window_position.y = ground_y
		if not is_idling:
			animated_sprite.play("Run")
			var new_x = window_position.x + direction.x * speed * delta
			new_x = clamp(new_x, 0, screen_size.x - window_size.x)
			var hit_window = false
			for r in get_blocking_rects():
				var overlaps_y = window_position.y + window_size.y > r.position.y + COLLISION_EPSILON and window_position.y < r.end.y - COLLISION_EPSILON
				if not overlaps_y:
					continue
				if direction.x > 0 and window_position.x + window_size.x <= r.position.x + COLLISION_EPSILON and new_x + window_size.x > r.position.x:
					new_x = r.position.x - window_size.x
					hit_window = true
				elif direction.x < 0 and window_position.x >= r.end.x - COLLISION_EPSILON and new_x < r.end.x:
					new_x = r.end.x
					hit_window = true
			window_position.x = new_x
			if hit_window or window_position.x <= 0 or window_position.x >= screen_size.x - window_size.x:
				direction.x *= -1
				animated_sprite.flip_h = direction.x < 0
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
	windowTitle.hide()
	beanPic.hide()
	windowSubtext.show()
	windowSubtext.text = "Bean is our beloved robotics shop cat who used to be a stray on the property. The mentor took her in, and now she roams around as we build the robot!"


func _on_button_2_pressed() -> void:
	beanPic.show()
	windowTitle.hide()
	windowSubtext.hide()


func _on_button_3_pressed() -> void:
	beanPic.hide()
	windowTitle.show()
	windowSubtext.show()
	windowTitle.text = "Thanks for using BeanPet!"
	windowSubtext.text = "
Bean is the name of the cat you see running around on your screen. Give her a click!"


func _on_close_button_pressed() -> void:
	window.hide()
	menuOpened = false
	menuCurrentlyOpened = false


func _on_close_two_button_pressed() -> void:
	statsWindow.hide()
	statsCurrentlyOpened = false


func _on_close_three_button_pressed() -> void:
	gameWindow.hide()
	gameCurrentlyOpened = false


func _on_close_four_pressed() -> void:
	settingsWindow.hide()
	settingsCurrentlyOpened = false
