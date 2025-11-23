# player_spawner.gd
# Добавьте этот скрипт к узлу в главной сцене (main.tscn)

extends Node3D

@export var player_scene: PackedScene
@export var spawn_points: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(5, 1, 0),
	Vector3(0, 1, 5),
	Vector3(5, 1, 5)
]

var spawned_players = {}

func _ready():
	# Ждем пока сеть инициализируется
	await get_tree().create_timer(0.1).timeout
	
	# Подключаем сигналы
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Если мы в мультиплеере
	if multiplayer.has_multiplayer_peer():
		# Спавним всех существующих игроков
		for peer_id in NetworkManager.players:
			_spawn_player(peer_id)
	else:
		# Одиночная игра - спавним только себя
		print("ВНИМАНИЕ: Мультиплеер не активен! Запускайте через лобби.")
		_spawn_player(1)

func _on_player_connected(peer_id, player_info):
	# Спавним нового игрока
	print("PlayerSpawner: спавним игрока %d" % peer_id)
	_spawn_player(peer_id)

func _on_player_disconnected(peer_id):
	# Удаляем отключившегося игрока
	if spawned_players.has(peer_id):
		spawned_players[peer_id].queue_free()
		spawned_players.erase(peer_id)
		print("Игрок %d удален" % peer_id)

func _spawn_player(peer_id: int):
	if not player_scene:
		push_error("Ошибка: не задана сцена игрока в PlayerSpawner!")
		return
	
	if spawned_players.has(peer_id):
		print("Игрок %d уже заспавнен" % peer_id)
		return
	
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	
	# КРИТИЧЕСКИ ВАЖНО: устанавливаем authority ДО добавления в сцену
	player.set_multiplayer_authority(peer_id)
	
	# Выбираем позицию спавна
	var spawn_index = spawned_players.size() % spawn_points.size()
	player.global_position = spawn_points[spawn_index]
	
	add_child(player, true) # true = force_readable_name
	spawned_players[peer_id] = player
	
	print("Игрок %d заспавнен в позиции %s (authority: %d)" % [peer_id, player.global_position, player.get_multiplayer_authority()])
	
	# Проверка: может ли этот клиент управлять игроком
	if player.is_multiplayer_authority():
		print("✅ Игрок %d - ЭТО ВЫ! Управление должно работать." % peer_id)
	else:
		print("👥 Игрок %d - удаленный игрок" % peer_id)
