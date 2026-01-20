extends Node
## PathfindingManager - Wraps AStarGrid2D for isometric pathfinding

const TILE_SIZE := Vector2i(128, 64)
const CHUNK_SIZE := 16

var astar: AStarGrid2D
var _grid_bounds: Rect2i = Rect2i(-256, -256, 512, 512)


func _ready() -> void:
	_initialize_astar()


func _initialize_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = _grid_bounds
	astar.cell_size = Vector2(TILE_SIZE)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	# Use ALWAYS for true 8-directional pathfinding (Diablo 2 style)
	# AT_LEAST_ONE_WALKABLE blocked diagonals when adjacent cells weren't explicitly walkable
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update()


func request_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _is_in_bounds(from) or not _is_in_bounds(to):
		return []

	# CRITICAL FIX: Don't reject if starting position is solid
	# Player may be standing on a cell marked solid due to collision overlap
	# Only reject if destination is unreachable
	if astar.is_point_solid(to):
		return []

	return astar.get_id_path(from, to)


## Check if there's a clear line-of-sight between two world positions
## Used for ranged attacks, detection, and path smoothing
func has_line_of_sight(from_world: Vector2, to_world: Vector2) -> bool:
	var direction := (to_world - from_world).normalized()
	var distance := from_world.distance_to(to_world)
	var step_size := 32.0  # Check every 32 pixels along the line

	var steps := int(distance / step_size)
	for i in range(1, steps):
		var check_pos := from_world + direction * (i * step_size)
		var check_grid := WorldManager.world_to_grid(check_pos)

		if astar.is_point_solid(check_grid):
			return false

	return true


func set_cell_solid(coord: Vector2i, solid: bool) -> void:
	if _is_in_bounds(coord):
		astar.set_point_solid(coord, solid)


func update_region(origin: Vector2i, size: Vector2i, walkable_data: Array) -> void:
	_ensure_bounds_contain(origin, size)

	for y in range(size.y):
		for x in range(size.x):
			var cell := origin + Vector2i(x, y)
			var index := y * size.x + x
			if index < walkable_data.size():
				var is_solid: bool = not walkable_data[index]
				astar.set_point_solid(cell, is_solid)


func clear_region(origin: Vector2i, size: Vector2i) -> void:
	for y in range(size.y):
		for x in range(size.x):
			var cell := origin + Vector2i(x, y)
			if _is_in_bounds(cell):
				astar.set_point_solid(cell, false)


func _is_in_bounds(coord: Vector2i) -> bool:
	return _grid_bounds.has_point(coord)


func _ensure_bounds_contain(origin: Vector2i, size: Vector2i) -> void:
	var needed_rect := Rect2i(origin, size)
	if not _grid_bounds.encloses(needed_rect):
		var new_bounds := _grid_bounds.merge(needed_rect)
		new_bounds = new_bounds.grow(CHUNK_SIZE * 2)
		_grid_bounds = new_bounds
		astar.region = _grid_bounds
		astar.update()
