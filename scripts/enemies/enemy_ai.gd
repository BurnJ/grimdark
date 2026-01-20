class_name EnemyAI
extends Node
## Simple state-based AI for enemy behavior


enum State { IDLE, CHASE, ATTACK, DEAD }

signal state_changed(new_state: State)
signal attack_requested

@export var aggro_range_tiles: float = 6.0
@export var attack_range_tiles: float = 1.0
@export var attack_cooldown: float = 1.5
@export var lose_aggro_range_tiles: float = 10.0

var current_state: State = State.IDLE
var target: Node2D = null
var _attack_timer: float = 0.0

var _owner_enemy: Node2D  # Set by parent


func _ready() -> void:
	# Wait a frame then find player
	await get_tree().process_frame
	_find_player()


func set_enemy(enemy: Node2D) -> void:
	_owner_enemy = enemy


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]


func _process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if not _owner_enemy:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack()


func _process_idle() -> void:
	if not target or not is_instance_valid(target):
		_find_player()
		return

	var distance := _get_distance_to_target()
	if distance <= aggro_range_tiles:
		_change_state(State.CHASE)


func _process_chase() -> void:
	if not target or not is_instance_valid(target):
		_change_state(State.IDLE)
		return

	var distance := _get_distance_to_target()

	# Check if lost aggro
	if distance > lose_aggro_range_tiles:
		if _owner_enemy.has_method("stop_movement"):
			_owner_enemy.stop_movement()
		_change_state(State.IDLE)
		return

	# Check if in attack range
	if distance <= attack_range_tiles:
		if _owner_enemy.has_method("stop_movement"):
			_owner_enemy.stop_movement()
		_change_state(State.ATTACK)
		return

	# Move toward target
	if _owner_enemy.has_method("move_to_position"):
		_owner_enemy.move_to_position(target.global_position)


func _process_attack() -> void:
	if not target or not is_instance_valid(target):
		_change_state(State.IDLE)
		return

	var distance := _get_distance_to_target()

	# Check if target moved out of range
	if distance > attack_range_tiles * 1.2:  # Small buffer
		_change_state(State.CHASE)
		return

	# Attack if cooldown ready
	if _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = attack_cooldown


func _perform_attack() -> void:
	attack_requested.emit()


func _get_distance_to_target() -> float:
	if not target or not _owner_enemy:
		return INF
	return DistanceConverter.world_distance_in_tiles(
		_owner_enemy.global_position,
		target.global_position
	)


func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


func set_dead() -> void:
	_change_state(State.DEAD)
	if _owner_enemy and _owner_enemy.has_method("stop_movement"):
		_owner_enemy.stop_movement()


func get_target() -> Node2D:
	return target
