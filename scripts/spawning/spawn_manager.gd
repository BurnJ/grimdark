class_name SpawnManager
extends RefCounted
## Handles enemy spawning logic - designed for future expansion


const ENEMY_SCENE_PATH := "res://scenes/enemies/enemy.tscn"
const CHUNK_SIZE := 16

## Spawn configuration - easily adjustable
var spawn_chance: float = 0.3  # 30% chance per chunk
var max_enemies_per_chunk: int = 1
var min_distance_from_player_tiles: float = 3.0


## Try to spawn enemies for a chunk. Returns array of spawned enemies.
static func try_spawn_enemies_for_chunk(
	chunk_data: ChunkData,
	entities_container: Node2D,
	player_pos: Vector2
) -> Array[EnemyController]:
	var spawned: Array[EnemyController] = []
	var instance := SpawnManager.new()

	# Roll for spawn
	if randf() > instance.spawn_chance:
		return spawned

	# Find walkable positions
	var walkable_positions := instance._get_walkable_positions(chunk_data)
	if walkable_positions.is_empty():
		return spawned

	# Filter positions too close to player
	var valid_positions := instance._filter_by_player_distance(
		walkable_positions,
		player_pos,
		instance.min_distance_from_player_tiles
	)

	if valid_positions.is_empty():
		return spawned

	# Spawn enemies (currently 0-1, expandable)
	var spawn_count := mini(instance.max_enemies_per_chunk, valid_positions.size())

	for i in range(spawn_count):
		var pos_index := randi() % valid_positions.size()
		var pos := valid_positions[pos_index]
		var enemy := instance._spawn_enemy_at(pos, entities_container)
		if enemy:
			spawned.append(enemy)
			valid_positions.remove_at(pos_index)

	return spawned


func _get_walkable_positions(chunk_data: ChunkData) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var world_origin := chunk_data.get_world_origin()

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			if chunk_data.is_tile_walkable(x, y):
				var grid_pos := world_origin + Vector2i(x, y)
				var world_pos := WorldManager.grid_to_world(grid_pos)
				positions.append(world_pos)

	return positions


func _filter_by_player_distance(
	positions: Array[Vector2],
	player_pos: Vector2,
	min_distance: float
) -> Array[Vector2]:
	var filtered: Array[Vector2] = []

	for pos in positions:
		var distance := DistanceConverter.world_distance_in_tiles(pos, player_pos)
		if distance >= min_distance:
			filtered.append(pos)

	return filtered


func _spawn_enemy_at(world_pos: Vector2, container: Node2D) -> EnemyController:
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	if not scene:
		push_error("Failed to load enemy scene: " + ENEMY_SCENE_PATH)
		return null

	var enemy := scene.instantiate() as EnemyController
	if not enemy:
		push_error("Enemy scene root is not EnemyController")
		return null

	enemy.global_position = world_pos
	container.add_child(enemy)

	return enemy
