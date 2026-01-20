class_name HurtboxComponent
extends Area2D
## Entity's collision radius for range calculations and damage detection
## Passive detection target: monitorable = true, monitoring = false


signal damage_received(amount: float, type: String, source: Node)
signal entered_aoe(aoe_source: Area2D)
signal exited_aoe(aoe_source: Area2D)

@export var radius_tiles: float = 0.25  ## Default: 0.25 tiles = 32 pixels
@export var team: int = 0  ## For friendly fire filtering (0 = player, 1 = enemy, etc.)

var _collision_shape: CollisionShape2D
var _circle_shape: CircleShape2D


func _ready() -> void:
	_setup_collision_shape()
	_setup_area_settings()


func _setup_collision_shape() -> void:
	_circle_shape = CircleShape2D.new()
	_circle_shape.radius = get_radius_pixels()

	_collision_shape = CollisionShape2D.new()
	_collision_shape.shape = _circle_shape
	add_child(_collision_shape)


func _setup_area_settings() -> void:
	# Hurtboxes are passive - they can BE detected but don't detect others
	collision_layer = 0
	collision_mask = 0
	monitorable = true   # Can be detected by hitboxes/AOE areas
	monitoring = false   # Doesn't actively detect


## Get the radius in pixels (for collision shapes)
func get_radius_pixels() -> float:
	return DistanceConverter.tiles_to_pixels(radius_tiles)


## Get the radius in tiles (for game logic)
func get_radius_tiles() -> float:
	return radius_tiles


## Get the center position in world coordinates
func get_center_world() -> Vector2:
	return global_position


## Update radius at runtime (reconfigures collision shape)
func set_radius_tiles(new_radius: float) -> void:
	radius_tiles = new_radius
	if _circle_shape:
		_circle_shape.radius = get_radius_pixels()


## Called by HitboxComponent or damage systems
func receive_damage(amount: float, type: String, source: Node) -> void:
	damage_received.emit(amount, type, source)


## Called when entering a persistent AOE effect
func notify_entered_aoe(aoe_source: Area2D) -> void:
	entered_aoe.emit(aoe_source)


## Called when exiting a persistent AOE effect
func notify_exited_aoe(aoe_source: Area2D) -> void:
	exited_aoe.emit(aoe_source)
