
extends CanvasLayer

var total_mice: int = 0
var player_kills: Dictionary = {}
var remaining_time: float = 30.0
var is_game_over: bool = false

@onready var kill_label: Label = $VBoxContainer/LabelKillCount
@onready var timer_label: Label = $VBoxContainer/LabelTimer
@onready var leaderboard: Label = $VBoxContainer/Leaderboard

signal time_up
signal all_mice_killed

func _ready():
	add_to_group("hud")
	_update_labels()
	
	for peer_id in NetworkManager.players:
		player_kills[peer_id] = 0

func _process(delta):
	if not multiplayer.is_server() or is_game_over:
		return
	
	remaining_time -= delta
	
	if remaining_time <= 0:
		remaining_time = 0
		is_game_over = true
		sync_time_up.rpc()

	sync_timer.rpc(remaining_time)

@rpc("authority", "call_local", "reliable")
func sync_timer(time: float):
	remaining_time = time
	_update_labels()

@rpc("authority", "call_local", "reliable")
func sync_time_up():
	is_game_over = true
	emit_signal("time_up")

@rpc("authority", "call_local", "reliable")
func sync_all_mice_killed():
	is_game_over = true
	emit_signal("all_mice_killed")

func set_total_mice(count: int):
	total_mice = count
	if multiplayer.is_server():
		sync_total_mice.rpc(count)
	_update_labels()

@rpc("authority", "call_local", "reliable")
func sync_total_mice(count: int):
	total_mice = count
	_update_labels()

func add_kill(player_id: int):
	if not player_kills.has(player_id):
		player_kills[player_id] = 0
	
	player_kills[player_id] += 1
	
	if multiplayer.is_server():
		sync_kills.rpc(player_kills)

		var total_kills = 0
		for kills in player_kills.values():
			total_kills += kills
		
		if total_kills >= total_mice and not is_game_over:
			is_game_over = true
			sync_all_mice_killed.rpc()
	
	_update_labels()

@rpc("authority", "call_local", "reliable")
func sync_kills(kills_data: Dictionary):
	player_kills = kills_data
	_update_labels()

func _update_labels():
	var total_kills = 0
	for kills in player_kills.values():
		total_kills += kills
	
	if kill_label:
		kill_label.text = "Мышей убито: %d / %d" % [total_kills, total_mice]
	
	if timer_label:
		timer_label.text = "Время: %.1f сек" % remaining_time

	if leaderboard:
		var text = "=== Игроки ===\n"

		var sorted_players = player_kills.keys()
		sorted_players.sort_custom(func(a, b): return player_kills[a] > player_kills[b])
		
		for peer_id in sorted_players:
			var player_name = "Player %d" % peer_id
			if NetworkManager.players.has(peer_id):
				player_name = NetworkManager.players[peer_id].name
			
			text += "%s: %d\n" % [player_name, player_kills[peer_id]]
		
		leaderboard.text = text
