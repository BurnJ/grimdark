extends Node
## DebugOverlay - Global debug visualization system for development
## Toggle with F3 to see: chunk borders, distance ruler, entity radii, AI states, etc.


signal visibility_changed(is_visible: bool)

var _canvas_layer: CanvasLayer
var _draw_node: Node2D
var _is_visible: bool = false
var _camera: Camera2D
var _player: Node2D

# Attack shape visualization queue
var _attack_shapes: Array[Dictionary] = []  # {shape: Shape2D, position: Vector2, rotation: float, timer: float}

# Pulsing animation state
var _pulse_time: float = 0.0

# Drawing constants
const CHUNK_BORDER_COLOR := Color(0.2, 0.6, 1.0, 0.6)  # Blue
const CHUNK_BORDER_WIDTH := 3.0
const MOUSE_RULER_COLOR := Color(1.0, 1.0, 0.0, 0.8)  # Yellow
const MOUSE_RULER_WIDTH := 2.0
const PLAYER_HURTBOX_COLOR := Color(0.2, 1.0, 0.2, 0.5)  # Green
const ENEMY_HURTBOX_COLOR := Color(1.0, 0.2, 0.2, 0.5)  # Red
const ATTACK_SHAPE_COLOR := Color(1.0, 0.0, 0.0, 0.7)  # Red
const AGGRO_RANGE_COLOR := Color(1.0, 1.0, 0.0, 0.3)  # Yellow
const TARGET_LASER_COLOR := Color(1.0, 0.5, 0.0, 0.6)  # Orange
const LABEL_COLOR := Color.WHITE
const LABEL_BG_COLOR := Color(0.0, 0.0, 0.0, 0.5)

# Combat debug visualization colors
const ATTACK_TARGET_COLOR := Color(0.0, 1.0, 1.0, 0.8)  # Cyan
const ATTACK_RANGE_COLOR := Color(0.2, 1.0, 0.2, 0.2)  # Light green
const APPROACH_LINE_COLOR := Color(1.0, 0.5, 0.0, 0.6)  # Orange

const ATTACK_SHAPE_DURATION := 0.1  # seconds


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_canvas()


func _setup_canvas() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100  # On top of everything
	add_child(_canvas_layer)

	_draw_node = _DebugDrawNode.new()
	_draw_node.debug_overlay = self
	_canvas_layer.add_child(_draw_node)

	_canvas_layer.visible = _is_visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_F3:
			toggle()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _is_visible:
		return

	# Find camera and player if not cached
	_update_references()

	# Update attack shape timers
	_update_attack_shapes(delta)

	# Update pulse animation
	_pulse_time += delta

	# Request redraw
	_draw_node.queue_redraw()


func _update_references() -> void:
	if not _camera:
		var cameras := get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			_camera = cameras[0]
		else:
			# Try to find any Camera2D in the scene
			_camera = _find_camera_recursive(get_tree().current_scene)

	if not _player:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]


func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result := _find_camera_recursive(child)
		if result:
			return result
	return null


func _update_attack_shapes(delta: float) -> void:
	var i := _attack_shapes.size() - 1
	while i >= 0:
		_attack_shapes[i].timer -= delta
		if _attack_shapes[i].timer <= 0:
			_attack_shapes.remove_at(i)
		i -= 1


# =============================================================================
# PUBLIC API
# =============================================================================

func toggle() -> void:
	_is_visible = not _is_visible
	_canvas_layer.visible = _is_visible
	visibility_changed.emit(_is_visible)


func show() -> void:
	_is_visible = true
	_canvas_layer.visible = true
	visibility_changed.emit(true)


func hide() -> void:
	_is_visible = false
	_canvas_layer.visible = false
	visibility_changed.emit(false)


func is_overlay_visible() -> bool:
	return _is_visible


## Called by BasicStrike (or other abilities) to visualize attack shapes
func register_attack_shape(shape: Shape2D, position: Vector2, rotation: float = 0.0) -> void:
	_attack_shapes.append({
		"shape": shape,
		"position": position,
		"rotation": rotation,
		"timer": ATTACK_SHAPE_DURATION
	})


# =============================================================================
# COORDINATE CONVERSION
# =============================================================================

func world_to_screen(world_pos: Vector2) -> Vector2:
	if not _camera:
		return world_pos

	var viewport_size := get_viewport().get_visible_rect().size
	var camera_pos := _camera.global_position
	var zoom := _camera.zoom

	var offset := (world_pos - camera_pos) * zoom
	return viewport_size * 0.5 + offset


func get_camera_zoom() -> Vector2:
	if _camera:
		return _camera.zoom
	return Vector2.ONE


func get_pulse_alpha() -> float:
	# Pulse between 0.4 and 1.0 at 2Hz
	return 0.7 + 0.3 * sin(_pulse_time * TAU * 2.0)


# =============================================================================
# INTERNAL DRAW NODE
# =============================================================================

class _DebugDrawNode extends Node2D:
	var debug_overlay: Node

	func _draw() -> void:
		if not debug_overlay or not debug_overlay._is_visible:
			return

		_draw_spatial_tools()
		_draw_combat_visualization()
		_draw_ai_debug()
		_draw_info_panel()


	func _draw_spatial_tools() -> void:
		_draw_chunk_borders()
		_draw_mouse_ruler()


	func _draw_chunk_borders() -> void:
		var chunks: Dictionary = WorldManager.loaded_chunks

		for coord: Vector2i in chunks.keys():
			var chunk_origin := coord * WorldManager.CHUNK_SIZE

			# Get the four corners of the chunk in grid coordinates
			var corners_grid := [
				chunk_origin,
				chunk_origin + Vector2i(WorldManager.CHUNK_SIZE, 0),
				chunk_origin + Vector2i(WorldManager.CHUNK_SIZE, WorldManager.CHUNK_SIZE),
				chunk_origin + Vector2i(0, WorldManager.CHUNK_SIZE)
			]

			# Convert to screen coordinates
			var corners_screen: Array[Vector2] = []
			for grid_pos: Vector2i in corners_grid:
				var world_pos: Vector2 = WorldManager.grid_to_world(grid_pos)
				var screen_pos: Vector2 = debug_overlay.world_to_screen(world_pos)
				corners_screen.append(screen_pos)

			# Draw chunk border
			for i in range(4):
				draw_line(
					corners_screen[i],
					corners_screen[(i + 1) % 4],
					CHUNK_BORDER_COLOR,
					CHUNK_BORDER_WIDTH
				)

			# Draw chunk coordinate label at center
			var center_world: Vector2 = WorldManager.grid_to_world(
				chunk_origin + Vector2i(WorldManager.CHUNK_SIZE / 2, WorldManager.CHUNK_SIZE / 2)
			)
			var center_screen: Vector2 = debug_overlay.world_to_screen(center_world)
			_draw_label(center_screen, "C(%d,%d)" % [coord.x, coord.y], CHUNK_BORDER_COLOR)


	func _draw_mouse_ruler() -> void:
		var player: Node2D = debug_overlay._player
		if not player:
			return

		var player_screen: Vector2 = debug_overlay.world_to_screen(player.global_position)
		var mouse_screen: Vector2 = get_viewport().get_mouse_position()

		# Draw dotted line
		_draw_dotted_line(player_screen, mouse_screen, MOUSE_RULER_COLOR, MOUSE_RULER_WIDTH, 10.0, 5.0)

		# Calculate distance in tiles (which equals meters)
		var player_world: Vector2 = player.global_position
		var mouse_world: Vector2 = _screen_to_world(mouse_screen)
		var distance_tiles: float = DistanceConverter.world_distance_in_tiles(player_world, mouse_world)

		# Draw distance label at midpoint
		var midpoint: Vector2 = (player_screen + mouse_screen) * 0.5
		var label_text: String = "%.1fm" % distance_tiles
		_draw_label(midpoint, label_text, MOUSE_RULER_COLOR, true)


	func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
		var direction := (to - from).normalized()
		var total_length := from.distance_to(to)
		var current := 0.0
		var drawing := true

		while current < total_length:
			var segment_length := dash_length if drawing else gap_length
			var end := minf(current + segment_length, total_length)

			if drawing:
				var start_pos := from + direction * current
				var end_pos := from + direction * end
				draw_line(start_pos, end_pos, color, width)

			current = end
			drawing = not drawing


	func _screen_to_world(screen_pos: Vector2) -> Vector2:
		if not debug_overlay._camera:
			return screen_pos

		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var camera_pos: Vector2 = debug_overlay._camera.global_position
		var zoom: Vector2 = debug_overlay._camera.zoom

		var offset: Vector2 = (screen_pos - viewport_size * 0.5) / zoom
		return camera_pos + offset


	func _draw_combat_visualization() -> void:
		_draw_entity_radii()
		_draw_attack_shapes()
		_draw_attack_range_circle()
		_draw_attack_target_indicator()
		_draw_approach_line()
		_draw_cooldown_display()


	func _draw_entity_radii() -> void:
		# Draw player hurtbox
		var player: Node2D = debug_overlay._player
		if player and player.has_node("HurtboxComponent"):
			var hurtbox: HurtboxComponent = player.get_node("HurtboxComponent")
			var screen_pos: Vector2 = debug_overlay.world_to_screen(player.global_position)
			var radius_pixels: float = hurtbox.get_radius_pixels() * debug_overlay.get_camera_zoom().x
			draw_arc(screen_pos, radius_pixels, 0, TAU, 32, PLAYER_HURTBOX_COLOR, 2.0)

		# Draw enemy hurtboxes
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		for enemy: Node in enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy is Node2D:
				continue
			var enemy_2d: Node2D = enemy as Node2D
			if enemy_2d.has_node("HurtboxComponent"):
				var hurtbox: HurtboxComponent = enemy_2d.get_node("HurtboxComponent")
				var screen_pos: Vector2 = debug_overlay.world_to_screen(enemy_2d.global_position)
				var radius_pixels: float = hurtbox.get_radius_pixels() * debug_overlay.get_camera_zoom().x
				draw_arc(screen_pos, radius_pixels, 0, TAU, 32, ENEMY_HURTBOX_COLOR, 2.0)


	func _draw_attack_shapes() -> void:
		for shape_data: Dictionary in debug_overlay._attack_shapes:
			var shape: Shape2D = shape_data.shape
			var pos: Vector2 = shape_data.position
			# Note: rotation is already baked into the shape by ShapeFactory

			var screen_pos: Vector2 = debug_overlay.world_to_screen(pos)
			var zoom: float = debug_overlay.get_camera_zoom().x

			if shape is ConvexPolygonShape2D:
				var polygon: PackedVector2Array = (shape as ConvexPolygonShape2D).points
				var screen_points: PackedVector2Array = []

				for point: Vector2 in polygon:
					# Shape is already rotated by ShapeFactory, just scale and translate
					var screen_point: Vector2 = screen_pos + point * zoom
					screen_points.append(screen_point)

				if screen_points.size() >= 3:
					draw_colored_polygon(screen_points, ATTACK_SHAPE_COLOR)

			elif shape is CircleShape2D:
				var radius: float = (shape as CircleShape2D).radius * zoom
				draw_arc(screen_pos, radius, 0, TAU, 32, ATTACK_SHAPE_COLOR, 2.0)


	func _draw_ai_debug() -> void:
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

		for enemy: Node in enemies:
			if not is_instance_valid(enemy):
				continue
			if not enemy is EnemyController:
				continue

			var enemy_ctrl: EnemyController = enemy as EnemyController
			if not enemy_ctrl.ai:
				continue

			var ai: EnemyAI = enemy_ctrl.ai
			var screen_pos: Vector2 = debug_overlay.world_to_screen(enemy_ctrl.global_position)

			# Draw aggro range circle
			var aggro_radius_pixels: float = DistanceConverter.tiles_to_pixels(ai.aggro_range_tiles)
			var aggro_radius_screen: float = aggro_radius_pixels * debug_overlay.get_camera_zoom().x
			draw_arc(screen_pos, aggro_radius_screen, 0, TAU, 48, AGGRO_RANGE_COLOR, 1.5)

			# Draw state tag above enemy
			var state_name: String = EnemyAI.State.keys()[ai.current_state]
			var label_pos: Vector2 = screen_pos + Vector2(0, -50)
			_draw_label(label_pos, "[%s]" % state_name, LABEL_COLOR, true)

			# Draw targeting laser
			var target: Node2D = ai.get_target()
			if target and is_instance_valid(target):
				var target_screen: Vector2 = debug_overlay.world_to_screen(target.global_position)
				draw_line(screen_pos, target_screen, TARGET_LASER_COLOR, 1.5)


	func _draw_attack_range_circle() -> void:
		var player: Node2D = debug_overlay._player
		if not player or not player is PlayerController:
			return

		var player_ctrl: PlayerController = player as PlayerController
		var attack_range: float = player_ctrl.get_attack_range()

		if attack_range <= 0.0:
			return

		var screen_pos: Vector2 = debug_overlay.world_to_screen(player.global_position)
		var range_pixels: float = DistanceConverter.tiles_to_pixels(attack_range)
		var range_screen: float = range_pixels * debug_overlay.get_camera_zoom().x

		draw_arc(screen_pos, range_screen, 0, TAU, 48, ATTACK_RANGE_COLOR, 2.0)


	func _draw_attack_target_indicator() -> void:
		var player: Node2D = debug_overlay._player
		if not player or not player is PlayerController:
			return

		var player_ctrl: PlayerController = player as PlayerController
		var attack_target: Node2D = player_ctrl.get_attack_target()

		if not attack_target or not is_instance_valid(attack_target):
			return

		var target_screen: Vector2 = debug_overlay.world_to_screen(attack_target.global_position)

		# Get pulsing alpha
		var pulse_alpha: float = debug_overlay.get_pulse_alpha()
		var color: Color = ATTACK_TARGET_COLOR
		color.a = pulse_alpha

		# Draw pulsing circle around target
		if attack_target.has_node("HurtboxComponent"):
			var hurtbox: HurtboxComponent = attack_target.get_node("HurtboxComponent")
			var radius_pixels: float = hurtbox.get_radius_pixels() * debug_overlay.get_camera_zoom().x
			draw_arc(target_screen, radius_pixels + 8.0, 0, TAU, 32, color, 4.0)
		else:
			# Fallback if no hurtbox
			draw_arc(target_screen, 40.0, 0, TAU, 32, color, 4.0)


	func _draw_approach_line() -> void:
		var player: Node2D = debug_overlay._player
		if not player or not player is PlayerController:
			return

		var player_ctrl: PlayerController = player as PlayerController

		if not player_ctrl.is_approaching_attack_target():
			return

		var attack_target: Node2D = player_ctrl.get_attack_target()
		if not attack_target or not is_instance_valid(attack_target):
			return

		var player_screen: Vector2 = debug_overlay.world_to_screen(player.global_position)
		var target_screen: Vector2 = debug_overlay.world_to_screen(attack_target.global_position)

		# Draw dashed line
		_draw_dotted_line(player_screen, target_screen, APPROACH_LINE_COLOR, 2.0, 10.0, 5.0)


	func _draw_cooldown_display() -> void:
		var player: Node2D = debug_overlay._player
		if not player or not player is PlayerController:
			return

		var player_ctrl: PlayerController = player as PlayerController

		# Get BasicStrike ability
		if not player_ctrl.has_node("AbilitySystem"):
			return

		var ability_system: Node = player_ctrl.get_node("AbilitySystem")
		if not ability_system.has_method("get_ability"):
			return

		var basic_strike: BasicStrike = ability_system.get_ability("basic_strike") as BasicStrike
		if not basic_strike:
			return

		# Only show if on cooldown
		if not basic_strike.is_on_cooldown():
			return

		var cooldown_remaining: float = basic_strike.get_cooldown_remaining()
		var player_screen: Vector2 = debug_overlay.world_to_screen(player.global_position)
		var label_pos: Vector2 = player_screen + Vector2(0, -70)

		_draw_label(label_pos, "CD: %.1fs" % cooldown_remaining, Color.ORANGE, true)


	func _draw_info_panel() -> void:
		var player: Node2D = debug_overlay._player
		if not player:
			return

		# Panel position (top-left corner)
		var panel_pos := Vector2(10, 10)
		var line_height := 20
		var current_y := panel_pos.y

		# Player position (pixels)
		var pixel_pos := player.global_position
		_draw_label(
			Vector2(panel_pos.x, current_y),
			"Pos: (%.0f, %.0f) px" % [pixel_pos.x, pixel_pos.y],
			LABEL_COLOR,
			false,
			false
		)
		current_y += line_height

		# Player grid position
		var grid_pos := WorldManager.world_to_grid(player.global_position)
		_draw_label(
			Vector2(panel_pos.x, current_y),
			"Grid: (%d, %d)" % [grid_pos.x, grid_pos.y],
			LABEL_COLOR,
			false,
			false
		)
		current_y += line_height

		# Movement speed
		var speed_tiles := GameConstants.PLAYER_WALK_SPEED
		if player is PlayerController:
			var pc := player as PlayerController
			if pc.is_running():
				speed_tiles = GameConstants.PLAYER_RUN_SPEED
		_draw_label(
			Vector2(panel_pos.x, current_y),
			"Speed: %s" % DistanceConverter.format_speed(speed_tiles),
			LABEL_COLOR,
			false,
			false
		)
		current_y += line_height

		# Active chunks
		var chunk_count := WorldManager.loaded_chunks.size()
		_draw_label(
			Vector2(panel_pos.x, current_y),
			"Chunks: %d" % chunk_count,
			LABEL_COLOR,
			false,
			false
		)
		current_y += line_height

		# Current chunk
		var player_chunk := WorldManager.player_chunk
		_draw_label(
			Vector2(panel_pos.x, current_y),
			"Current: C(%d,%d)" % [player_chunk.x, player_chunk.y],
			LABEL_COLOR,
			false,
			false
		)


	func _draw_label(pos: Vector2, text: String, color: Color, centered: bool = false, with_background: bool = true) -> void:
		var font := ThemeDB.fallback_font
		var font_size := 14

		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

		var draw_pos := pos
		if centered:
			draw_pos.x -= text_size.x * 0.5
			draw_pos.y += text_size.y * 0.25

		# Draw background
		if with_background:
			var bg_rect := Rect2(
				draw_pos.x - 2,
				draw_pos.y - text_size.y + 2,
				text_size.x + 4,
				text_size.y + 2
			)
			draw_rect(bg_rect, LABEL_BG_COLOR)

		# Draw text
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
