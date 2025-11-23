extends CharacterBody3D

@export var hp: int = 30
@export var walk_speed: float = 2.0
@export var run_speed: float = 5.0
@export var detection_range: float = 10.0
@export var vision_angle: float = 120.0

var current_speed: float = walk_speed
var wander_timer: float = 0.0
var wander_direction: Vector3 = Vector3.ZERO
var is_fleeing: bool = false
var hp_label: Label3D = null
var hit_sound: AudioStreamPlayer3D
var death_sound: AudioStreamPlayer3D
var is_dead: bool = false

enum State { WANDER, FLEE }
var current_state: State = State.WANDER

func _ready():
	add_to_group("mouse")
	_set_new_wander_direction()
	
	hp_label = get_node_or_null("HPLabel")
	if hp_label:
		_update_hp_label()
	
	hit_sound = get_node_or_null("HitSound")
	death_sound = get_node_or_null("DeathSound")

func _physics_process(delta):
	if not multiplayer.is_server():
		return
	
	if is_dead:
		return
	
	if hp <= 0:
		die()
		return
	
	var nearest_player = _find_nearest_player()
	
	if nearest_player and can_see_player(nearest_player):
		current_state = State.FLEE
		is_fleeing = true
	else:
		is_fleeing = false
		if current_state == State.FLEE:
			current_state = State.WANDER
			_set_new_wander_direction()
	
	match current_state:
		State.WANDER:
			wander(delta)
		State.FLEE:
			flee_from_player(delta, nearest_player)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
	
	if velocity.length() > 0.1:
		look_at(global_position + velocity.normalized(), Vector3.UP)

func _find_nearest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	var nearest: Node3D = null
	var nearest_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = player
	
	return nearest

func wander(delta):
	current_speed = walk_speed
	wander_timer -= delta
	
	if wander_timer <= 0:
		_set_new_wander_direction()
	
	velocity.x = wander_direction.x * current_speed
	velocity.z = wander_direction.z * current_speed

func flee_from_player(delta, player: Node3D):
	current_speed = run_speed
	
	if player:
		var direction = (global_position - player.global_position).normalized()
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

func can_see_player(player: Node3D) -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var forward = -global_transform.basis.z.normalized()
	var angle = rad_to_deg(acos(forward.dot(direction_to_player)))
	
	if angle > vision_angle / 2:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.5,
		player.global_position + Vector3.UP * 0.5
	)
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		return true
	elif not result:
		return true
	
	return false

func _set_new_wander_direction():
	wander_direction = Vector3(
		randf_range(-1, 1),
		0,
		randf_range(-1, 1)
	).normalized()
	wander_timer = randf_range(2.0, 5.0)

func take_damage(damage: int, attacker_id: int = 0):
	if not multiplayer.is_server():
		return
	
	if is_dead:
		return
	
	hp -= damage
	
	if attacker_id > 0:
		print("Мышь получила урон от игрока %d, осталось хп: %d" % [attacker_id, hp])
	else:
		print("Мышь получила урон, осталось хп: %d" % hp)
	
	sync_hp.rpc(hp)
	
	if hp > 0:
		if hit_sound:
			play_hit_sound.rpc()
	else:
		die(attacker_id)

@rpc("authority", "call_local", "reliable")
func sync_hp(new_hp: int):
	hp = new_hp
	_update_hp_label()

@rpc("authority", "call_local", "reliable")
func play_hit_sound():
	if hit_sound:
		hit_sound.play()

@rpc("authority", "call_local", "reliable")
func play_death_sound():
	if death_sound:
		death_sound.play()

func die(attacker_id: int = 0):
	if is_dead:
		return
	
	is_dead = true
	print("Мышь умерла, убил игрок: ", attacker_id)

	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.get_multiplayer_authority() == attacker_id:
			if player.has_method("on_mouse_killed"):
				player.on_mouse_killed()
			break
	
	play_death_sound.rpc()
	
	if death_sound:
		await get_tree().create_timer(death_sound.stream.get_length()).timeout
	else:
		await get_tree().create_timer(0.5).timeout
	
	queue_free()

func _update_hp_label():
	if hp_label:
		hp_label.text = str(hp) + " HP"
		if hp > 20:
			hp_label.modulate = Color.GREEN
		elif hp > 10:
			hp_label.modulate = Color.YELLOW
		else:
			hp_label.modulate = Color.RED
