extends EntityController
class_name PlayerController
## Point-and-click player movement with continuous physics-based movement and combat

signal path_completed
signal direction_changed(new_direction: Direction)
signal movement_started
signal movement_stopped
signal player_died
signal player_respawned

enum Direction { N, NE, E, SE, S, SW, W, NW }

# Movement constants
const ARRIVAL_THRESHOLD := 10.0  # pixels - 8% of tile width for precise stopping
const DIRECTION_HYSTERESIS := deg_to_rad(5.0)
const ACCELERATION_TIME := 0.1  # seconds to reach full speed (adds weight)

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var ability_system: AbilitySystem = $AbilitySystem

var _move_speed_pixels: float  # Cached pixel speed
var _current_speed_factor := 0.0  # For acceleration easing
var _is_running: bool = false
var current_path: Array[Vector2] = []  # World coordinates (continuous)
var current_target: Vector2 = Vector2.ZERO
var final_destination: Vector2 = Vector2.ZERO  # Exact click target for freemove
var current_direction: Direction = Direction.S
var _direction_angle_cache: float = PI / 2
var _is_moving: bool = false

# Combat state - Action Combat (Diablo-style)
var _right_mouse_held: bool = false
var _attack_requested: bool = false
var _last_cursor_world: Vector2 = Vector2.ZERO


func _ready() -> void:
	_move_speed_pixels = DistanceConverter.speed_tiles_to_pixels(GameConstants.PLAYER_WALK_SPEED)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # For top-down
	_update_sprite_color()

	# Add to player group for enemy AI targeting
	add_to_group("player")

	# Connect health signals
	if health:
		health.died.connect(_on_died)
		health.damage_taken.connect(_on_damage_taken)

	# Connect hurtbox to health
	if hurtbox:
		hurtbox.damage_received.connect(_on_hurtbox_damage_received)


func _physics_process(delta: float) -> void:
	if _is_moving:
		_process_movement(delta)

	# EntityController will handle push velocity and call move_and_slide()
	super._physics_process(delta)

	# Update facing direction based on actual velocity
	if velocity.length_squared() > 1.0:
		_update_direction(velocity.normalized())

	# Execute pending attack after movement
	if _attack_requested:
		_execute_immediate_attack()
		_attack_requested = false


func _process(_delta: float) -> void:
	# Continuous fire support - hold right-click to attack repeatedly
	if _right_mouse_held:
		var basic_strike := ability_system.get_ability("basic_strike") as BasicStrike
		if basic_strike and basic_strike.can_use():
			_attack_requested = true


func _input(event: InputEvent) -> void:
	if health and health.is_dead:
		return  # No input while dead

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_click(get_global_mouse_position())
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			# Track held state for continuous fire
			if mouse_event.pressed:
				_right_mouse_held = true
				_last_cursor_world = get_global_mouse_position()
				_attack_requested = true  # Immediate first attack
			else:
				_right_mouse_held = false

	# Run/walk toggle (R key)
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_R:
			_toggle_run()


func _toggle_run() -> void:
	_is_running = not _is_running
	if _is_running:
		_move_speed_pixels = DistanceConverter.speed_tiles_to_pixels(GameConstants.PLAYER_RUN_SPEED)
	else:
		_move_speed_pixels = DistanceConverter.speed_tiles_to_pixels(GameConstants.PLAYER_WALK_SPEED)


func _handle_click(click_pos: Vector2) -> void:
	var from_grid := WorldManager.world_to_grid(global_position)
	var to_grid := WorldManager.world_to_grid(click_pos)

	# Store exact click position as final destination
	final_destination = click_pos

	# Show click marker for visual feedback
	_spawn_click_marker(click_pos)

	# Special case: Same grid cell - move directly to exact position
	# Add distance checks to prevent rounding errors from triggering this incorrectly
	var grid_distance_sq := (to_grid - from_grid).length_squared()
	var world_distance := global_position.distance_to(click_pos)

	if from_grid == to_grid and grid_distance_sq == 0:
		# True same-tile click
		current_path.clear()
		current_path.append(final_destination)
		_start_movement()
		return

	# Also handle very short clicks (< 10 pixels) directly
	if world_distance < 10.0:
		current_path.clear()
		current_path.append(final_destination)
		_start_movement()
		return

	# DIRECT MOVEMENT: Check if we can move directly to destination
	# For short distances (< 3 tiles), just check if destination is walkable
	# For longer distances, also verify line-of-sight
	var tile_distance := DistanceConverter.world_distance_in_tiles(global_position, click_pos)
	var dest_is_walkable := not PathfindingManager.astar.is_point_solid(to_grid)

	if dest_is_walkable:
		# Short distance: trust it (avoids false positives from LOS sampling near obstacles)
		# Long distance: verify no obstacles block the path
		if tile_distance < 3.0 or _has_clear_path(global_position, click_pos):
			current_path.clear()
			current_path.append(final_destination)
			_start_movement()
			return

	# Get grid path for obstacle avoidance (only needed when obstacles block direct path)
	var grid_path := PathfindingManager.request_path(from_grid, to_grid)

	if grid_path.size() > 0:
		current_path.clear()

		# Convert grid waypoints to world coords (tile centers for guidance)
		for grid_pos in grid_path:
			current_path.append(WorldManager.grid_to_world(grid_pos))

		# Remove starting position
		if current_path.size() > 0:
			current_path.remove_at(0)

		# SMOOTH PATH: Remove unnecessary intermediate waypoints
		current_path = _smooth_path(current_path)

		# CRITICAL: Replace last waypoint with exact click position
		if current_path.size() > 0:
			current_path[current_path.size() - 1] = final_destination
		else:
			current_path.append(final_destination)

		_start_movement()


func _start_movement() -> void:
	if not _is_moving:
		_is_moving = true
		_current_speed_factor = 0.0  # Reset acceleration
		movement_started.emit()


func _spawn_click_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.set_script(load("res://scripts/effects/click_marker.gd"))
	marker.global_position = pos
	get_tree().current_scene.add_child(marker)


## Removes unnecessary waypoints by checking line-of-sight between points
func _smooth_path(path: Array[Vector2]) -> Array[Vector2]:
	if path.size() <= 2:
		return path

	var smoothed: Array[Vector2] = []
	smoothed.append(path[0])

	var current_idx := 0
	while current_idx < path.size() - 1:
		# Find the farthest point we can reach directly without hitting obstacles
		var farthest_reachable := current_idx + 1

		for check_idx in range(current_idx + 2, path.size()):
			if _has_clear_path(path[current_idx], path[check_idx]):
				farthest_reachable = check_idx

		smoothed.append(path[farthest_reachable])
		current_idx = farthest_reachable

	return smoothed


## Checks if there's a clear path between two world positions (no obstacles)
func _has_clear_path(from_pos: Vector2, to_pos: Vector2) -> bool:
	var direction := (to_pos - from_pos).normalized()
	var distance := from_pos.distance_to(to_pos)
	var step_size := 32.0  # Check every 32 pixels along the line

	var steps := int(distance / step_size)
	for i in range(1, steps):
		var check_pos := from_pos + direction * (i * step_size)
		var check_grid := WorldManager.world_to_grid(check_pos)

		if PathfindingManager.astar.is_point_solid(check_grid):
			return false

	return true


func _process_movement(delta: float) -> void:
	if current_path.is_empty():
		velocity = Vector2.ZERO
		_is_moving = false
		_current_speed_factor = 0.0
		path_completed.emit()
		movement_stopped.emit()
		return

	# Get current target waypoint
	current_target = current_path[0]

	# Check if reached waypoint
	var distance_to_target := global_position.distance_to(current_target)
	if distance_to_target < ARRIVAL_THRESHOLD:
		current_path.remove_at(0)
		if current_path.is_empty():
			velocity = Vector2.ZERO
			_is_moving = false
			_current_speed_factor = 0.0
			path_completed.emit()
			movement_stopped.emit()
			return
		current_target = current_path[0]

	# Smooth acceleration (adds weight to movement)
	_current_speed_factor = minf(_current_speed_factor + delta / ACCELERATION_TIME, 1.0)

	# Calculate steering direction
	var desired_direction := (current_target - global_position).normalized()

	# Set velocity with acceleration easing
	velocity = desired_direction * _move_speed_pixels * _current_speed_factor


func stop_movement() -> void:
	velocity = Vector2.ZERO
	current_path.clear()
	_is_moving = false
	_current_speed_factor = 0.0
	movement_stopped.emit()


func is_moving() -> bool:
	return _is_moving


func is_running() -> bool:
	return _is_running


func _update_direction(move_dir: Vector2) -> void:
	if move_dir.length_squared() < 0.001:
		return

	var new_angle := move_dir.angle()

	if absf(angle_difference(new_angle, _direction_angle_cache)) > DIRECTION_HYSTERESIS:
		_direction_angle_cache = new_angle
		var new_direction := _angle_to_direction(new_angle)

		if new_direction != current_direction:
			current_direction = new_direction
			direction_changed.emit(current_direction)
			_update_sprite_color()


func _angle_to_direction(angle: float) -> Direction:
	var normalized := fposmod(angle + PI, TAU) - PI

	if normalized >= -PI/8 and normalized < PI/8:
		return Direction.E
	elif normalized >= PI/8 and normalized < 3*PI/8:
		return Direction.SE
	elif normalized >= 3*PI/8 and normalized < 5*PI/8:
		return Direction.S
	elif normalized >= 5*PI/8 and normalized < 7*PI/8:
		return Direction.SW
	elif normalized >= 7*PI/8 or normalized < -7*PI/8:
		return Direction.W
	elif normalized >= -7*PI/8 and normalized < -5*PI/8:
		return Direction.NW
	elif normalized >= -5*PI/8 and normalized < -3*PI/8:
		return Direction.N
	else:
		return Direction.NE


func _update_sprite_color() -> void:
	if not sprite:
		return

	var base_color := Color(0.8, 0.2, 0.2)
	match current_direction:
		Direction.N, Direction.NE, Direction.NW:
			sprite.modulate = base_color.darkened(0.2)
		Direction.S, Direction.SE, Direction.SW:
			sprite.modulate = base_color
		_:
			sprite.modulate = base_color.darkened(0.1)


# =============================================================================
# COMBAT METHODS - Action Combat (Diablo-style)
# =============================================================================

func _execute_immediate_attack() -> void:
	if not ability_system:
		return

	var basic_strike := ability_system.get_ability("basic_strike") as BasicStrike
	if not basic_strike or not basic_strike.can_use():
		return

	# Stop any ongoing movement
	stop_movement()

	# Update facing direction toward cursor
	var attack_direction := (_last_cursor_world - global_position).normalized()
	if attack_direction.length_squared() > 0.001:
		_update_direction(attack_direction)

	# Pass null target and cursor position for Smart Hit targeting
	ability_system.use_ability("basic_strike", null, _last_cursor_world)


## Debug / query helpers used by visualization tools
func get_attack_range() -> float:
	var basic_strike := ability_system.get_ability("basic_strike") as BasicStrike
	if basic_strike:
		return basic_strike.reach_tiles
	return 0.0


func get_attack_target() -> Node2D:
	return _attack_target


# =============================================================================
# HEALTH & DAMAGE METHODS
# =============================================================================

func _on_hurtbox_damage_received(amount: float, _type: String, source: Node) -> void:
	if health:
		health.take_damage(int(amount), source)


func _on_damage_taken(_amount: int, _source: Node) -> void:
	# Visual feedback - flash red
	if sprite:
		sprite.modulate = Color.RED
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.8, 0.2, 0.2), 0.2)


func _on_died() -> void:
	player_died.emit()
	stop_movement()

	# Brief death pause then respawn
	await get_tree().create_timer(1.0).timeout
	_respawn()


func _respawn() -> void:
	global_position = Vector2.ZERO
	if health:
		health.reset()
	player_respawned.emit()
