class_name ShapeFactory
extends RefCounted
## Factory for creating collision shapes for melee attacks
## All dimensions are specified in tiles and converted to pixels internally


# === ARC SHAPES (Sword swings, cleaves) ===

## Create an arc/fan shape for sweeping melee attacks
## Returns a ConvexPolygonShape2D approximating the arc
static func create_arc(
	radius_tiles: float,
	arc_degrees: float,
	segments: int = 8,
	facing_angle: float = 0.0
) -> ConvexPolygonShape2D:
	var radius_pixels := DistanceConverter.tiles_to_pixels(radius_tiles)
	var half_arc := deg_to_rad(arc_degrees / 2.0)

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)  # Origin point (attacker position)

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := facing_angle - half_arc + (t * 2.0 * half_arc)
		var point := Vector2(cos(angle), sin(angle)) * radius_pixels
		points.append(point)

	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	return shape


# === CONE SHAPES (Spear thrusts, breath attacks) ===

## Create a cone/triangle shape for directional attacks
## Tip at origin, expands outward
static func create_cone(
	length_tiles: float,
	base_width_tiles: float,
	facing_angle: float = 0.0
) -> ConvexPolygonShape2D:
	var length_pixels := DistanceConverter.tiles_to_pixels(length_tiles)
	var half_width_pixels := DistanceConverter.tiles_to_pixels(base_width_tiles) / 2.0

	var direction := Vector2(cos(facing_angle), sin(facing_angle))
	var perpendicular := Vector2(-direction.y, direction.x)

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)  # Tip at origin
	points.append(direction * length_pixels + perpendicular * half_width_pixels)
	points.append(direction * length_pixels - perpendicular * half_width_pixels)

	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	return shape


# === LINE SHAPES (Stabs, quick thrusts) ===

## Create a thin rectangle for stab/thrust attacks
static func create_line(
	length_tiles: float,
	width_tiles: float = 0.25,
	facing_angle: float = 0.0
) -> ConvexPolygonShape2D:
	var length_pixels := DistanceConverter.tiles_to_pixels(length_tiles)
	var half_width_pixels := DistanceConverter.tiles_to_pixels(width_tiles) / 2.0

	var direction := Vector2(cos(facing_angle), sin(facing_angle))
	var perpendicular := Vector2(-direction.y, direction.x)

	var points := PackedVector2Array()
	points.append(perpendicular * half_width_pixels)
	points.append(-perpendicular * half_width_pixels)
	points.append(direction * length_pixels - perpendicular * half_width_pixels)
	points.append(direction * length_pixels + perpendicular * half_width_pixels)

	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	return shape


# === CIRCLE SHAPES (Slam attacks, ground pounds, AOE) ===

## Create a circle shape for radial attacks
static func create_circle(radius_tiles: float) -> CircleShape2D:
	var shape := CircleShape2D.new()
	shape.radius = DistanceConverter.tiles_to_pixels(radius_tiles)
	return shape


## Create a circle shape with area-based scaling
static func create_circle_scaled(
	base_radius_tiles: float,
	area_percent_bonus: float
) -> CircleShape2D:
	var scaled_radius := AreaScaler.scale_radius_by_area(base_radius_tiles, area_percent_bonus)
	return create_circle(scaled_radius)


# === RECTANGLE SHAPES (Wide cleave attacks) ===

## Create a rectangle shape for wide attacks
static func create_rectangle(
	width_tiles: float,
	height_tiles: float
) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(
		DistanceConverter.tiles_to_pixels(width_tiles),
		DistanceConverter.tiles_to_pixels(height_tiles)
	)
	return shape


# === CAPSULE SHAPES (Elongated hitboxes) ===

## Create a capsule shape for elongated attacks
static func create_capsule(
	radius_tiles: float,
	height_tiles: float
) -> CapsuleShape2D:
	var shape := CapsuleShape2D.new()
	shape.radius = DistanceConverter.tiles_to_pixels(radius_tiles)
	shape.height = DistanceConverter.tiles_to_pixels(height_tiles)
	return shape


# === HELPER: Direction conversion ===

## Convert 8-direction enum to angle in radians
## Assumes Direction enum: N=0, NE=1, E=2, SE=3, S=4, SW=5, W=6, NW=7
static func direction_to_angle(direction: int) -> float:
	# Map direction to angle (E=0, going counter-clockwise)
	# N = -PI/2, NE = -PI/4, E = 0, SE = PI/4, S = PI/2, etc.
	var angles := [
		-PI / 2.0,      # N (up)
		-PI / 4.0,      # NE
		0.0,            # E (right)
		PI / 4.0,       # SE
		PI / 2.0,       # S (down)
		3.0 * PI / 4.0, # SW
		PI,             # W (left)
		-3.0 * PI / 4.0 # NW
	]
	return angles[direction % 8]
