extends CanvasLayer

@onready var host_button = $Panel/VBoxContainer/HostButton
@onready var join_button = $Panel/VBoxContainer/JoinButton
@onready var ip_input = $Panel/VBoxContainer/IPInput
@onready var name_input = $Panel/VBoxContainer/NameInput
@onready var start_button = $Panel/VBoxContainer/StartButton
@onready var players_list = $Panel/VBoxContainer/PlayersList
@onready var status_label = $Panel/VBoxContainer/StatusLabel

var game_scene_path = "res://main.tscn"

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	start_button.visible = false
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	_update_players_list()

func _on_host_button_pressed():
	var player_name = name_input.text if name_input.text != "" else "Host"
	var error = NetworkManager.create_server(player_name)
	
	if error == OK:
		status_label.text = "Сервер создан! Ожидание игроков..."
		host_button.disabled = true
		join_button.disabled = true
		start_button.visible = true
		_update_players_list()
	else:
		status_label.text = "Ошибка создания сервера!"

func _on_join_button_pressed():
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var player_name = name_input.text if name_input.text != "" else "Player"
	var error = NetworkManager.join_server(ip, player_name)
	
	if error == OK:
		status_label.text = "Подключение к серверу..."
		host_button.disabled = true
		join_button.disabled = true
	else:
		status_label.text = "Ошибка подключения!"

func _on_start_button_pressed():
	if multiplayer.is_server():
		_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game():
	get_tree().change_scene_to_file(game_scene_path)

func _on_player_connected(peer_id, player_info):
	status_label.text = "Игрок %s подключился!" % player_info.name
	_update_players_list()

func _on_player_disconnected(peer_id):
	status_label.text = "Игрок отключился"
	_update_players_list()

func _on_server_disconnected():
	status_label.text = "Сервер отключен"
	host_button.disabled = false
	join_button.disabled = false
	start_button.visible = false
	_update_players_list()

func _update_players_list():
	players_list.clear()
	for peer_id in NetworkManager.players:
		var player_info = NetworkManager.players[peer_id]
		players_list.add_item("%s (ID: %d)" % [player_info.name, peer_id])
