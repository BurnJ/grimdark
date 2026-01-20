extends EntityController
class_name EnemyController
## Base enemy entity with health, AI, and combat capabilities


signal died(enemy: EnemyController)

@export var enemy_name: String = "Enemy"
@export var move_speed_tiles: float = 1.2

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health: HealthComponent = $HealthComponent
@onready var ai: EnemyAI = $EnemyAI
@onready var attack: EnemyAttack = $EnemyAttack

var _move_speed_pixels: float
var _is_moving: bool = false
var _current_path: Array[Vector2] = []


func _ready() -> void:
	_move_speed_pixels = DistanceConverter.speed_tiles_to_pixels(move_speed_tiles)

	# Add to enemies group for debug overlay
	add_to_group("enemies")

	# Setup AI
	if ai:
		ai.set_enemy(self)

	# Setup attack
	if attack:
		attack.set_enemy(self)
		if ai:
			attack.set_ai(ai)

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

	super._physics_process(delta)


func _process_movement(_delta: float) -> void:
	if _current_path.is_empty():
		velocity = Vector2.ZERO
		_is_moving = false
		return

	var target := _current_path[0]
	var distance := global_position.distance_to(target)

	if distance < 10.0:  # Arrival threshold
		_current_path.remove_at(0)
		if _current_path.is_empty():
			velocity = Vector2.ZERO
			_is_moving = false
			return
		target = _current_path[0]

	var direction := (target - global_position).normalized()
	velocity = direction * _move_speed_pixels


func move_to_position(target_pos: Vector2) -> void:
	var from_grid := WorldManager.world_to_grid(global_position)
	var to_grid := WorldManager.world_to_grid(target_pos)

	var grid_path := PathfindingManager.request_path(from_grid, to_grid)
	if grid_path.size() > 0:
		_current_path.clear()
		for grid_pos in grid_path:
			_current_path.append(WorldManager.grid_to_world(grid_pos))
		if _current_path.size() > 0:
			_current_path.remove_at(0)  # Remove starting position
		_is_moving = true


func stop_movement() -> void:
	_current_path.clear()
	velocity = Vector2.ZERO
	_is_moving = false


func is_moving() -> bool:
	return _is_moving


func _on_hurtbox_damage_received(amount: float, _type: String, source: Node) -> void:
	if health:
		health.take_damage(int(amount), source)


func _on_damage_taken(_amount: int, _source: Node) -> void:
	# Flash red or play hit effect
	if sprite:
		sprite.modulate = Color.RED
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.4, 0.6, 0.4), 0.2)


func _on_died() -> void:
	# Notify AI
	if ai:
		ai.set_dead()

	died.emit(self)

	# Play death animation, then queue_free
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
