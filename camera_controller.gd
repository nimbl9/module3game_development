# camera_controller.gd
# Альтернативный вариант: отдельная камера, следующая за игроком
# Добавьте этот скрипт к узлу Camera3D в главной сцене (main.tscn)

extends Camera3D

@export var offset: Vector3 = Vector3(0, 3, 5)
@export var mouse_sensitivity: float = 0.003
@export var follow_speed: float = 10.0

var target: CharacterBody3D = null
var camera_rotation: Vector2 = Vector2.ZERO

func _ready():
	# Ждем, пока заспавнится локальный игрок
	await get_tree().create_timer(0.5).timeout
	_find_local_player()

func _find_local_player():
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.is_multiplayer_authority():
			target = player
			current = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			print("Камера нашла локального игрока")
			break

func _input(event):
	if not target:
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, -PI / 2, PI / 2)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not target:
		return
	
	# Поворачиваем игрока по Y
	target.rotation.y = camera_rotation.y
	
	# Вычисляем позицию камеры
	var target_pos = target.global_position
	var rotated_offset = offset.rotated(Vector3.UP, camera_rotation.y)
	var desired_position = target_pos + rotated_offset
	
	# Плавно следуем за игроком
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	
	# Применяем вертикальный поворот камеры
	rotation.x = camera_rotation.x
	rotation.y = camera_rotation.y
	
	# Смотрим на игрока
	look_at(target_pos + Vector3.UP * 1.5, Vector3.UP)
