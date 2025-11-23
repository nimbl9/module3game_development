extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 7777
const MAX_PLAYERS = 4

var players = {}
var player_info = {"name": "Player"}

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_server(player_name: String):
	player_info.name = player_name
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Ошибка создания сервера: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	players[1] = player_info
	print("Сервер создан на порту ", PORT)
	return OK

func join_server(address: String, player_name: String):
	player_info.name = player_name
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	
	if error != OK:
		print("Ошибка подключения к серверу: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Подключение к серверу ", address)
	return OK

func _on_player_connected(id):
	print("Игрок подключен: ", id)
	_register_player.rpc_id(id, player_info)

func _on_player_disconnected(id):
	print("Игрок отключен: ", id)
	players.erase(id)
	emit_signal("player_disconnected", id)

func _on_connected_to_server():
	print("Успешно подключен к серверу")
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info

func _on_connection_failed():
	print("Не удалось подключиться к серверу")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("Отключен от сервера")
	multiplayer.multiplayer_peer = null
	players.clear()
	emit_signal("server_disconnected")

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	emit_signal("player_connected", new_player_id, new_player_info)

	if multiplayer.is_server():
		for peer_id in players:
			_register_player.rpc_id(new_player_id, players[peer_id])
