class_name BasicStrike
extends AbilityBase
## Basic melee attack - single target with future sweep support


signal strike_hit(target: HurtboxComponent)
signal strike_missed
signal debug_attack_shape(shape: Shape2D, position: Vector2, rotation: float)

@export var damage: float = 15.0
@export var damage: float = 15.0
@export var reach_tiles: float = 1.0  ## Increased reach so tile-centered entities can hit each other
@export var attack_width_tiles: float = 0.5  # Wider detection to make aiming less fussy
@export var selection_mode: String = "closest_cursor"  # closest_cursor or closest_center

## Future sweep properties (prepared but not active by default)
@export var is_sweep: bool = false
@export var sweep_arc_degrees: float = 90.0
@export var sweep_max_targets: int = 3

var _hitbox: HitboxComponent


func _ready() -> void:
	ability_name = "basic_strike"
	cooldown = 0.8
	range_tiles = reach_tiles

	_create_hitbox()


func _create_hitbox() -> void:
	_hitbox = HitboxComponent.new()
	_hitbox.damage = damage
	_hitbox.damage_type = "physical"
	_hitbox.team = 0  # Player team
	_hitbox.one_shot = not is_sweep
	_hitbox.max_targets = 1 if not is_sweep else sweep_max_targets
	add_child(_hitbox)
	_hitbox.deactivate()


func execute(target: Node = null, cursor_world: Vector2 = null) -> void:
	if not ability_owner:
		return

	var target_pos: Vector2
	if target and target is Node2D:
		target_pos = (target as Node2D).global_position
	elif target and target is HurtboxComponent:
		target_pos = (target as HurtboxComponent).get_center_world()
	else:
		# No target - attack in current facing direction
		# Get direction from owner if possible
		strike_missed.emit()
		_start_cooldown()
		ability_executed.emit()
		return

	# Calculate facing direction toward target
	var direction := (target_pos - ability_owner.global_position).normalized()
	var facing_angle := direction.angle()

	# Create attack shape based on sweep mode
	var shape: Shape2D
	if is_sweep:
		shape = ShapeFactory.create_arc(reach_tiles, sweep_arc_degrees, 8, facing_angle)
	else:
		shape = ShapeFactory.create_line(reach_tiles, attack_width_tiles, facing_angle)

	_hitbox.set_shape(shape)
	_hitbox.global_position = ability_owner.global_position
	_hitbox.damage = damage

	# Notify debug overlay for visualization
	debug_attack_shape.emit(shape, ability_owner.global_position, facing_angle)
	if Engine.has_singleton("DebugOverlay") or has_node("/root/DebugOverlay"):
		var debug_overlay := get_node_or_null("/root/DebugOverlay")
		if debug_overlay and debug_overlay.has_method("register_attack_shape"):
			debug_overlay.register_attack_shape(shape, ability_owner.global_position, facing_angle)

	# Update hitbox settings in case they changed
	_hitbox.one_shot = not is_sweep
	_hitbox.max_targets = 1 if not is_sweep else sweep_max_targets

	# Execute attack
	_hitbox.reset()
	_hitbox.activate()

	# Wait for physics frame for collision detection
	await ability_owner.get_tree().physics_frame

	var hits := _hitbox.get_hit_entities()
	_hitbox.deactivate()

	# Select a single target according to selection_mode
	if hits.size() > 0:
		var chosen: HurtboxComponent = null
		if cursor_world != null and selection_mode == "closest_cursor":
			# pick the hit whose center is closest to the cursor
			var best_dist := 1e9
			for h in hits:
				var d := h.get_center_world().distance_to(cursor_world)
				if d < best_dist:
					best_dist = d
					chosen = h
		else:
			# pick the hit whose center is closest to the attacker
			var best_dist2 := 1e9
			for h in hits:
				var d2 := h.get_center_world().distance_to(ability_owner.global_position)
				if d2 < best_dist2:
					best_dist2 = d2
					chosen = h

		if chosen:
			strike_hit.emit(chosen)
			# Apply damage to the chosen target
			chosen.receive_damage(damage, "physical", ability_owner)
	else:
		strike_missed.emit()

	_start_cooldown()
	ability_executed.emit()


## Enable sweep mode (for future use)
func enable_sweep(arc_degrees: float = 90.0, max_targets: int = 3) -> void:
	is_sweep = true
	sweep_arc_degrees = arc_degrees
	sweep_max_targets = max_targets


## Disable sweep mode (return to single target)
func disable_sweep() -> void:
	is_sweep = false
