extends Node2D
## Main game scene - coordinates world, player, and camera

@onready var world_tilemap: Node2D = $WorldTileMap
@onready var ground_layer: TileMapLayer = $WorldTileMap/GroundLayer
@onready var obstacles_layer: TileMapLayer = $WorldTileMap/ObstaclesLayer
@onready var decoration_layer: TileMapLayer = $WorldTileMap/DecorationLayer
@onready var entities: Node2D = $Entities
@onready var player: Node2D = $Entities/Player
@onready var camera: Camera2D = $Camera2D
@onready var hp_bar: HPBarUI = $UILayer/HPBar


func _ready() -> void:
	_setup_world()
	_setup_camera()
	_connect_signals()

	WorldManager.force_load_initial_chunks(Vector2i.ZERO)


func _setup_world() -> void:
	WorldManager.initialize(ground_layer, obstacles_layer, decoration_layer, entities, player)


func _setup_camera() -> void:
	# Set explicit zoom for proper viewport scaling
	camera.zoom = Vector2(1.0, 1.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.make_current()
	# Add to group for debug overlay access
	camera.add_to_group("camera")


func _connect_signals() -> void:
	WorldManager.chunk_loaded.connect(_on_chunk_loaded)
	WorldManager.chunk_unloaded.connect(_on_chunk_unloaded)

	if player.has_signal("path_completed"):
		player.path_completed.connect(_on_player_path_completed)

	# Connect HP bar to player health
	var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
	if player_health and hp_bar:
		hp_bar.connect_to_health(player_health)

	# Connect player death/respawn signals
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	if player.has_signal("player_respawned"):
		player.player_respawned.connect(_on_player_respawned)


func _process(_delta: float) -> void:
	_update_camera()
	WorldManager.update_chunks(player.global_position)


func _update_camera() -> void:
	camera.global_position = player.global_position


func _on_chunk_loaded(_coord: Vector2i) -> void:
	pass


func _on_chunk_unloaded(_coord: Vector2i) -> void:
	pass


func _on_player_path_completed() -> void:
	pass


func _on_player_died() -> void:
	# Could add death screen or effects here
	pass


func _on_player_respawned() -> void:
	# Reload chunks around respawn point
	WorldManager.force_load_initial_chunks(Vector2i.ZERO)
