# cat.gd - Обновленная версия с мультиплеером

extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var attack_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 0.5

@onready var camera = $Camera3D if has_node("Camera3D") else null
@onready var attack_timer: float = 0.0
@onready var name_label = $NameLabel3D if has_node("NameLabel3D") else null
@onready var mesh_instance = $MeshInstance3D if has_node("MeshInstance3D") else null

var hud: CanvasLayer
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_id: int = 1
var kills: int = 0

func _ready():
	print("Кот готов! Authority: %d, Мой ID: %d" % [get_multiplayer_authority(), multiplayer.get_unique_id()])
	
	# Настройка камеры только для локального игрока
	if is_multiplayer_authority():
		print("✅ Это МОЙ кот! Включаю управление.")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera:
			camera.current = true
		# Скрываем свою модель для локального игрока (опционально)
		if mesh_instance:
			mesh_instance.visible = false
	else:
		print("👥 Это удаленный игрок")
		# Удаляем камеру для удаленных игроков
		if camera:
			camera.queue_free()
			camera = null
	
	add_to_group("player")
	
	# Установка имени игрока
	if name_label:
		player_id = get_multiplayer_authority()
		if NetworkManager.players.has(player_id):
			name_label.text = NetworkManager.players[player_id].name
		else:
			name_label.text = "Player %d" % player_id
	
	await get_tree().process_frame
	
	# HUD только для локального игрока
	if is_multiplayer_authority():
		hud = get_tree().get_first_node_in_group("hud")
		if hud:
			var mice = get_tree().get_nodes_in_group("mouse")
			hud.set_total_mice(mice.size())
			hud.connect("time_up", Callable(self, "_on_time_up"))
			hud.connect("all_mice_killed", Callable(self, "_on_all_mice_killed"))

func _input(event):
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	
	# ДЕБАГ: проверка что функция вызывается
	if Engine.get_frames_drawn() % 60 == 0: # каждую секунду
		print("Кот %d обрабатывает физику. Позиция: %s" % [get_multiplayer_authority(), global_position])
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		print("Прыжок!")
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()
	
	attack_timer -= delta
	if Input.is_action_just_pressed("attack") and attack_timer <= 0:
		attack()
		attack_timer = attack_cooldown

func attack():
	print("Кот атакует!")
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = attack_range
	query.shape = shape
	query.transform = global_transform
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		if collider != self and collider.is_in_group("mouse"):
			# Отправляем запрос на урон на сервер
			if multiplayer.is_server():
				if collider.has_method("take_damage"):
					collider.take_damage(attack_damage, player_id)
			else:
				request_damage.rpc_id(1, collider.get_path(), attack_damage, player_id)
			print("Попадание!")

@rpc("any_peer", "call_local", "reliable")
func request_damage(mouse_path: NodePath, damage: int, attacker_id: int):
	if not multiplayer.is_server():
		return
	
	var mouse = get_node_or_null(mouse_path)
	if mouse and mouse.has_method("take_damage"):
		mouse.take_damage(damage, attacker_id)

func on_mouse_killed():
	kills += 1
	if hud:
		hud.add_kill(player_id)

func _on_time_up():
	if is_multiplayer_authority():
		print("Время вышло! Поражение!")
		get_tree().change_scene_to_file("res://scenes/LoseScreen.tscn")

func _on_all_mice_killed():
	if is_multiplayer_authority():
		print("Все мыши уничтожены! Победа!")
		get_tree().change_scene_to_file("res://scenes/WinScreen.tscn")
