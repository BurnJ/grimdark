class_name ChunkGenerator
extends RefCounted
## Procedural terrain generation using noise

enum TileType {
	GROUND = 0,
	GRASS = 1,
	STONE = 2,
	WATER = 3
}

const CHUNK_SIZE := 16

var noise: FastNoiseLite
var _seed: int


func _init(world_seed: int = 0) -> void:
	_seed = world_seed if world_seed != 0 else randi()
	_setup_noise()


func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = _seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5


func generate_chunk(coord: Vector2i) -> ChunkData:
	var chunk_data := ChunkData.new(coord)
	var world_origin := coord * CHUNK_SIZE

	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var world_x := world_origin.x + local_x
			var world_y := world_origin.y + local_y

			var noise_value := noise.get_noise_2d(world_x, world_y)
			var tile_type := _noise_to_tile_type(noise_value)
			var is_walkable := _is_tile_walkable(tile_type)

			chunk_data.set_tile(local_x, local_y, tile_type, is_walkable)

	chunk_data.is_generated = true
	return chunk_data


func _noise_to_tile_type(noise_value: float) -> int:
	if noise_value < -0.2:
		return TileType.WATER
	elif noise_value < 0.3:
		return TileType.GRASS
	elif noise_value < 0.5:
		return TileType.GROUND
	else:
		return TileType.STONE


func _is_tile_walkable(tile_type: int) -> bool:
	match tile_type:
		TileType.WATER:
			return false
		TileType.STONE:
			return false
		_:
			return true


static func get_tile_color(tile_type: int) -> Color:
	match tile_type:
		TileType.GROUND:
			return Color(0.45, 0.35, 0.25)
		TileType.GRASS:
			return Color(0.35, 0.55, 0.25)
		TileType.STONE:
			return Color(0.5, 0.5, 0.55)
		TileType.WATER:
			return Color(0.25, 0.4, 0.65)
		_:
			return Color.MAGENTA


static func get_all_tile_colors() -> Array[Color]:
	return [
		get_tile_color(TileType.GROUND),
		get_tile_color(TileType.GRASS),
		get_tile_color(TileType.STONE),
		get_tile_color(TileType.WATER)
	]
