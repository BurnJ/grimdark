class_name DistanceConverter
extends RefCounted
## Utility for converting between tile-based, pixel-based, and meter display measurements

const TILE_WIDTH_PIXELS := 128.0
const METERS_PER_TILE := 1.0  # Display ratio: 1 tile = 1 meter

static func tiles_to_pixels(tiles: float) -> float:
	return tiles * TILE_WIDTH_PIXELS


static func pixels_to_tiles(pixels: float) -> float:
	return pixels / TILE_WIDTH_PIXELS


static func speed_tiles_to_pixels(tiles_per_sec: float) -> float:
	return tiles_per_sec * TILE_WIDTH_PIXELS


static func grid_distance(from: Vector2i, to: Vector2i) -> float:
	var dx := float(to.x - from.x)
	var dy := float(to.y - from.y)
	return sqrt(dx * dx + dy * dy)


static func world_distance_in_tiles(from: Vector2, to: Vector2) -> float:
	return pixels_to_tiles(from.distance_to(to))


static func is_within_range_grid(from: Vector2i, to: Vector2i, range_tiles: float) -> bool:
	return grid_distance(from, to) <= range_tiles


static func is_within_range_world(from: Vector2, to: Vector2, range_tiles: float) -> bool:
	return world_distance_in_tiles(from, to) <= range_tiles


## Get all grid tiles within a radius (for auras, AOE effects)
static func get_tiles_in_radius(center: Vector2i, radius_tiles: float) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var r := int(ceilf(radius_tiles))

	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var tile := center + Vector2i(x, y)
			if grid_distance(center, tile) <= radius_tiles:
				tiles.append(tile)

	return tiles


## Check if target is within melee range (world coordinates)
static func is_in_melee_range(from_world: Vector2, to_world: Vector2) -> bool:
	return world_distance_in_tiles(from_world, to_world) <= GameConstants.MELEE_RANGE


## Check if target is within bow/ranged attack range (world coordinates)
static func is_in_bow_range(from_world: Vector2, to_world: Vector2) -> bool:
	return world_distance_in_tiles(from_world, to_world) <= GameConstants.BOW_RANGE


## Check if target is within a custom range (world coordinates)
static func is_in_range(from_world: Vector2, to_world: Vector2, range_tiles: float) -> bool:
	return world_distance_in_tiles(from_world, to_world) <= range_tiles


# === METER DISPLAY FUNCTIONS ===

## Convert tiles to meters for UI display
static func tiles_to_meters(tiles: float) -> float:
	return tiles * METERS_PER_TILE


## Convert meters to tiles (for parsing user input)
static func meters_to_tiles(meters: float) -> float:
	return meters / METERS_PER_TILE


## Format distance for UI display (e.g., "5.5 m")
static func format_distance(tiles: float, decimals: int = 1) -> String:
	var meters := tiles_to_meters(tiles)
	return "%.*f m" % [decimals, meters]


## Format speed for UI display (e.g., "1.5 m/s")
static func format_speed(tiles_per_sec: float, decimals: int = 1) -> String:
	var meters_per_sec := tiles_to_meters(tiles_per_sec)
	return "%.*f m/s" % [decimals, meters_per_sec]


## Format range for UI display (e.g., "8 m range")
static func format_range(range_tiles: float, decimals: int = 0) -> String:
	var meters := tiles_to_meters(range_tiles)
	return "%.*f m range" % [decimals, meters]


## Format area for UI display (e.g., "28.3 m²")
static func format_area(area_tiles_squared: float, decimals: int = 1) -> String:
	var area_meters := area_tiles_squared * (METERS_PER_TILE * METERS_PER_TILE)
	return "%.*f m\u00B2" % [decimals, area_meters]


## Format radius with area tooltip info (e.g., "3 m radius (28.3 m² area)")
static func format_radius_with_area(radius_tiles: float) -> String:
	var meters := tiles_to_meters(radius_tiles)
	var area := PI * radius_tiles * radius_tiles
	var area_meters := area * (METERS_PER_TILE * METERS_PER_TILE)
	return "%.0f m radius (%.1f m\u00B2 area)" % [meters, area_meters]
