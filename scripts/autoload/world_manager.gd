extends Node
## WorldManager - Coordinates chunk loading/unloading and tilemap management

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

const CHUNK_SIZE := 16
const TILE_SIZE := Vector2i(128, 64)
const LOAD_RADIUS := 1
const UNLOAD_RADIUS := 2

var loaded_chunks: Dictionary = {}
var player_chunk: Vector2i = Vector2i.ZERO

var _ground_layer: TileMapLayer
var _obstacles_layer: TileMapLayer
var _decoration_layer: TileMapLayer
var _entities_container: Node2D
var _player: Node2D
var _tileset: TileSet
var _chunk_generator: ChunkGenerator


func _ready() -> void:
	_chunk_generator = ChunkGenerator.new()
	_create_tileset()


func initialize(
	ground: TileMapLayer,
	obstacles: TileMapLayer,
	decoration: TileMapLayer,
	entities: Node2D = null,
	player: Node2D = null
) -> void:
	_ground_layer = ground
	_obstacles_layer = obstacles
	_decoration_layer = decoration
	_entities_container = entities
	_player = player

	_ground_layer.tile_set = _tileset
	_obstacles_layer.tile_set = _tileset
	_decoration_layer.tile_set = _tileset


func _create_tileset() -> void:
	_tileset = TileSet.new()
	_tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	_tileset.tile_size = TILE_SIZE

	# Add physics layer before setting collision data on tiles
	_tileset.add_physics_layer()

	var atlas_texture := TileTextureGenerator.create_tile_atlas(
		ChunkGenerator.get_all_tile_colors()
	)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture
	source.texture_region_size = TILE_SIZE

	# Create tiles first
	for i in range(4):
		var atlas_coords := Vector2i(i, 0)
		source.create_tile(atlas_coords)

	# Add source to tileset BEFORE setting collision data
	_tileset.add_source(source)

	# Now set collision data (source is part of tileset with physics layer)
	for i in range(4):
		if i == ChunkGenerator.TileType.STONE or i == ChunkGenerator.TileType.WATER:
			var atlas_coords := Vector2i(i, 0)
			var tile_data := source.get_tile_data(atlas_coords, 0)
			tile_data.set_collision_polygons_count(0, 1)

			# Isometric diamond collision shape
			var polygon := PackedVector2Array([
				Vector2(64, 0),    # Top
				Vector2(128, 32),  # Right
				Vector2(64, 64),   # Bottom
				Vector2(0, 32)     # Left
			])
			tile_data.set_collision_polygon_points(0, 0, polygon)
			tile_data.set_constant_linear_velocity(0, Vector2.ZERO)
			tile_data.set_constant_angular_velocity(0, 0.0)


func update_chunks(player_pos: Vector2) -> void:
	var new_chunk := get_chunk_coord(player_pos)

	if new_chunk != player_chunk:
		player_chunk = new_chunk
		_load_nearby_chunks()
		_unload_distant_chunks()


func get_chunk_coord(world_pos: Vector2) -> Vector2i:
	if _ground_layer:
		var grid_pos := _ground_layer.local_to_map(world_pos)
		return Vector2i(
			floori(float(grid_pos.x) / CHUNK_SIZE),
			floori(float(grid_pos.y) / CHUNK_SIZE)
		)
	return Vector2i(
		floori(world_pos.x / (CHUNK_SIZE * TILE_SIZE.x * 0.5)),
		floori(world_pos.y / (CHUNK_SIZE * TILE_SIZE.y * 0.5))
	)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	if _ground_layer:
		# Convert global world position to tilemap-local, then to grid
		var local_pos := _ground_layer.to_local(world_pos)
		return _ground_layer.local_to_map(local_pos)
	return Vector2i.ZERO


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	if _ground_layer:
		# Convert grid to tilemap-local, then to global world position
		var local_pos := _ground_layer.map_to_local(grid_pos)
		return _ground_layer.to_global(local_pos)
	return Vector2.ZERO


func _load_nearby_chunks() -> void:
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var chunk_coord := player_chunk + Vector2i(dx, dy)
			if not loaded_chunks.has(chunk_coord):
				_load_chunk(chunk_coord)


func _unload_distant_chunks() -> void:
	var chunks_to_unload: Array[Vector2i] = []

	for coord in loaded_chunks.keys():
		var distance = (coord - player_chunk).abs()
		if distance.x > UNLOAD_RADIUS or distance.y > UNLOAD_RADIUS:
			chunks_to_unload.append(coord)

	for coord in chunks_to_unload:
		_unload_chunk(coord)


func _load_chunk(coord: Vector2i) -> void:
	var chunk_data := _chunk_generator.generate_chunk(coord)
	loaded_chunks[coord] = chunk_data

	_apply_chunk_to_tilemap(chunk_data)
	_update_pathfinding_for_chunk(chunk_data)

	# Spawn enemies in this chunk
	_spawn_enemies_for_chunk(chunk_data)

	chunk_loaded.emit(coord)


func _unload_chunk(coord: Vector2i) -> void:
	if not loaded_chunks.has(coord):
		return

	var chunk_data: ChunkData = loaded_chunks[coord]

	# Clean up enemies before unloading
	chunk_data.clear_enemies()

	_clear_chunk_from_tilemap(chunk_data)
	_clear_pathfinding_for_chunk(chunk_data)

	loaded_chunks.erase(coord)
	chunk_unloaded.emit(coord)


func _apply_chunk_to_tilemap(chunk_data: ChunkData) -> void:
	if not _ground_layer:
		return

	var world_origin := chunk_data.get_world_origin()

	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var grid_pos := world_origin + Vector2i(local_x, local_y)
			var tile_id := chunk_data.get_tile(local_x, local_y)

			match tile_id:
				ChunkGenerator.TileType.GROUND, ChunkGenerator.TileType.GRASS:
					_ground_layer.set_cell(grid_pos, 0, Vector2i(tile_id, 0))
				ChunkGenerator.TileType.STONE, ChunkGenerator.TileType.WATER:
					_ground_layer.set_cell(grid_pos, 0, Vector2i(tile_id, 0))


func _clear_chunk_from_tilemap(chunk_data: ChunkData) -> void:
	if not _ground_layer:
		return

	var world_origin := chunk_data.get_world_origin()

	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var grid_pos := world_origin + Vector2i(local_x, local_y)
			_ground_layer.erase_cell(grid_pos)
			_obstacles_layer.erase_cell(grid_pos)
			_decoration_layer.erase_cell(grid_pos)


func _update_pathfinding_for_chunk(chunk_data: ChunkData) -> void:
	var world_origin := chunk_data.get_world_origin()
	PathfindingManager.update_region(
		world_origin,
		Vector2i(CHUNK_SIZE, CHUNK_SIZE),
		chunk_data.walkable
	)


func _clear_pathfinding_for_chunk(chunk_data: ChunkData) -> void:
	var world_origin := chunk_data.get_world_origin()
	PathfindingManager.clear_region(
		world_origin,
		Vector2i(CHUNK_SIZE, CHUNK_SIZE)
	)


func force_load_initial_chunks(center: Vector2i = Vector2i.ZERO) -> void:
	player_chunk = center
	_load_nearby_chunks()


func _spawn_enemies_for_chunk(chunk_data: ChunkData) -> void:
	if not _entities_container or not _player:
		return

	var spawned := SpawnManager.try_spawn_enemies_for_chunk(
		chunk_data,
		_entities_container,
		_player.global_position
	)

	for enemy in spawned:
		chunk_data.add_enemy(enemy)
		enemy.died.connect(_on_enemy_died.bind(chunk_data, enemy))


func _on_enemy_died(chunk_data: ChunkData, enemy: Node) -> void:
	chunk_data.remove_enemy(enemy)
