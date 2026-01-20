class_name RangeIndicator
extends Node2D
## Visual range indicator for debug and gameplay use
## Supports circles, arcs, cones, and rectangles


enum IndicatorType { CIRCLE, ARC, CONE, RECTANGLE }

@export var indicator_type: IndicatorType = IndicatorType.CIRCLE
@export var radius_tiles: float = 5.0
@export var arc_degrees: float = 90.0  ## Used for ARC and CONE types
@export var width_tiles: float = 2.0   ## Used for RECTANGLE type
@export var color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var border_width: float = 2.0
@export var show_border: bool = true
@export var show_fill: bool = true
@export var segments: int = 32  ## Smoothness for curved shapes

var _facing_angle: float = 0.0
var _area_percent_bonus: float = 0.0


func _draw() -> void:
	match indicator_type:
		IndicatorType.CIRCLE:
			_draw_circle_indicator()
		IndicatorType.ARC:
			_draw_arc_indicator()
		IndicatorType.CONE:
			_draw_cone_indicator()
		IndicatorType.RECTANGLE:
			_draw_rectangle_indicator()


func _draw_circle_indicator() -> void:
	var effective_radius := _get_effective_radius_pixels()

	if show_fill:
		draw_circle(Vector2.ZERO, effective_radius, color)
	if show_border:
		draw_arc(Vector2.ZERO, effective_radius, 0, TAU, segments, border_color, border_width)


func _draw_arc_indicator() -> void:
	var effective_radius := _get_effective_radius_pixels()
	var half_arc := deg_to_rad(arc_degrees / 2.0)
	var start_angle := _facing_angle - half_arc
	var end_angle := _facing_angle + half_arc

	if show_fill:
		var points := PackedVector2Array()
		points.append(Vector2.ZERO)
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var angle := start_angle + t * (end_angle - start_angle)
			points.append(Vector2(cos(angle), sin(angle)) * effective_radius)
		draw_colored_polygon(points, color)

	if show_border:
		draw_arc(Vector2.ZERO, effective_radius, start_angle, end_angle, segments, border_color, border_width)
		draw_line(Vector2.ZERO, Vector2(cos(start_angle), sin(start_angle)) * effective_radius, border_color, border_width)
		draw_line(Vector2.ZERO, Vector2(cos(end_angle), sin(end_angle)) * effective_radius, border_color, border_width)


func _draw_cone_indicator() -> void:
	var length_pixels := _get_effective_radius_pixels()
	var half_arc := deg_to_rad(arc_degrees / 2.0)

	var direction := Vector2(cos(_facing_angle), sin(_facing_angle))
	var left := Vector2(cos(_facing_angle - half_arc), sin(_facing_angle - half_arc))
	var right := Vector2(cos(_facing_angle + half_arc), sin(_facing_angle + half_arc))

	var points := PackedVector2Array([
		Vector2.ZERO,
		left * length_pixels,
		right * length_pixels
	])

	if show_fill:
		draw_colored_polygon(points, color)
	if show_border:
		var border_points := points.duplicate()
		border_points.append(Vector2.ZERO)  # Close the shape
		draw_polyline(border_points, border_color, border_width)


func _draw_rectangle_indicator() -> void:
	var width_pixels := DistanceConverter.tiles_to_pixels(width_tiles)
	var height_pixels := _get_effective_radius_pixels()

	# Rectangle extends from origin in facing direction
	var direction := Vector2(cos(_facing_angle), sin(_facing_angle))
	var perpendicular := Vector2(-direction.y, direction.x)

	var half_width := width_pixels / 2.0
	var points := PackedVector2Array([
		perpendicular * half_width,
		-perpendicular * half_width,
		direction * height_pixels - perpendicular * half_width,
		direction * height_pixels + perpendicular * half_width
	])

	if show_fill:
		draw_colored_polygon(points, color)
	if show_border:
		var border_points := points.duplicate()
		border_points.append(points[0])  # Close the shape
		draw_polyline(border_points, border_color, border_width)


## Get effective radius accounting for area scaling
func _get_effective_radius_pixels() -> float:
	var effective_tiles := radius_tiles
	if _area_percent_bonus > 0.0:
		effective_tiles = AreaScaler.scale_radius_by_area(radius_tiles, _area_percent_bonus)
	return DistanceConverter.tiles_to_pixels(effective_tiles)


## Set the facing direction (radians)
func set_facing(angle_radians: float) -> void:
	_facing_angle = angle_radians
	queue_redraw()


## Set facing from a direction vector
func set_facing_from_vector(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		_facing_angle = direction.angle()
		queue_redraw()


## Set the base radius in tiles
func set_radius(tiles: float) -> void:
	radius_tiles = tiles
	queue_redraw()


## Set arc/cone angle in degrees
func set_arc(degrees: float) -> void:
	arc_degrees = degrees
	queue_redraw()


## Set rectangle width in tiles
func set_width(tiles: float) -> void:
	width_tiles = tiles
	queue_redraw()


## Set area bonus for scaled indicators (AOE effects)
func set_area_bonus(percent_bonus: float) -> void:
	_area_percent_bonus = percent_bonus
	queue_redraw()


## Set indicator type
func set_type(type: IndicatorType) -> void:
	indicator_type = type
	queue_redraw()


## Set colors
func set_colors(fill: Color, border: Color) -> void:
	color = fill
	border_color = border
	queue_redraw()


## Get the effective radius in tiles (with area scaling)
func get_effective_radius_tiles() -> float:
	if _area_percent_bonus > 0.0:
		return AreaScaler.scale_radius_by_area(radius_tiles, _area_percent_bonus)
	return radius_tiles


## Get display string for this indicator's range
func get_range_display() -> String:
	return DistanceConverter.format_distance(get_effective_radius_tiles())


## Show the indicator
func show_indicator() -> void:
	visible = true


## Hide the indicator
func hide_indicator() -> void:
	visible = false


## Toggle visibility
func toggle_indicator() -> void:
	visible = not visible
