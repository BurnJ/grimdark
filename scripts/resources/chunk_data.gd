class_name ChunkData
extends Resource
## Holds tile data for a single chunk

const CHUNK_SIZE := 16
const TOTAL_TILES := CHUNK_SIZE * CHUNK_SIZE

var coord: Vector2i = Vector2i.ZERO
var tiles: Array[int] = []
var walkable: Array[bool] = []
var is_generated: bool = false

## Spawned enemies in this chunk (for cleanup on unload)
var enemies: Array[Node] = []


func _init(chunk_coord: Vector2i = Vector2i.ZERO) -> void:
	coord = chunk_coord
	tiles.resize(TOTAL_TILES)
	walkable.resize(TOTAL_TILES)
	tiles.fill(0)
	walkable.fill(true)


func set_tile(local_x: int, local_y: int, tile_id: int, is_walkable: bool = true) -> void:
	var index := local_y * CHUNK_SIZE + local_x
	if index >= 0 and index < TOTAL_TILES:
		tiles[index] = tile_id
		walkable[index] = is_walkable


func get_tile(local_x: int, local_y: int) -> int:
	var index := local_y * CHUNK_SIZE + local_x
	if index >= 0 and index < TOTAL_TILES:
		return tiles[index]
	return 0


func is_tile_walkable(local_x: int, local_y: int) -> bool:
	var index := local_y * CHUNK_SIZE + local_x
	if index >= 0 and index < TOTAL_TILES:
		return walkable[index]
	return true


func get_world_origin() -> Vector2i:
	return coord * CHUNK_SIZE


## Add an enemy to this chunk's tracking list
func add_enemy(enemy: Node) -> void:
	if enemy and not enemies.has(enemy):
		enemies.append(enemy)


## Remove an enemy from this chunk's tracking list
func remove_enemy(enemy: Node) -> void:
	enemies.erase(enemy)


## Clean up all enemies when chunk unloads
func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()


## Get count of living enemies in this chunk
func get_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			count += 1
	return count
