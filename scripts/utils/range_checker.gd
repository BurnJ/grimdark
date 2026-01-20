class_name RangeChecker
extends RefCounted
## Unified range checking utility for all distance-based interactions
##
## Three check types:
## - AOE/Aura: Shape-to-shape intersection (Area2D.get_overlapping_areas)
## - Melee: Shape intersection (Area2D) for arcs/cones/stabs
## - Ranged: Edge-to-edge math (distance <= range + attacker_r + target_r)


# =============================================================================
# AOE/AURA CHECKS (Shape-to-Shape Intersection)
# =============================================================================

## Get all hurtboxes overlapping an Area2D (for auras, persistent AOE)
## Uses Godot's built-in physics overlap - most efficient for continuous checks
static func get_overlapping_hurtboxes(aoe_area: Area2D) -> Array[HurtboxComponent]:
	var result: Array[HurtboxComponent] = []
	for area in aoe_area.get_overlapping_areas():
		if area is HurtboxComponent:
			result.append(area as HurtboxComponent)
	return result


## Check if a specific hurtbox is within an AOE area
static func is_in_aoe(aoe_area: Area2D, hurtbox: HurtboxComponent) -> bool:
	return hurtbox in aoe_area.get_overlapping_areas()


## Get hurtboxes in AOE filtered by team
static func get_overlapping_hurtboxes_filtered(
	aoe_area: Area2D,
	exclude_team: int = -1,
	include_same_team: bool = false
) -> Array[HurtboxComponent]:
	var result: Array[HurtboxComponent] = []
	for area in aoe_area.get_overlapping_areas():
		if area is HurtboxComponent:
			var hurtbox := area as HurtboxComponent
			if exclude_team >= 0:
				if include_same_team or hurtbox.team != exclude_team:
					result.append(hurtbox)
			else:
				result.append(hurtbox)
	return result


# =============================================================================
# MELEE CHECKS (Shape Intersection)
# =============================================================================

## Perform instant melee attack check using shape intersection
## Returns all hurtboxes hit by the attack shape
static func check_melee_hit(
	attack_area: Area2D,
	attacker_team: int,
	can_friendly_fire: bool = false
) -> Array[HurtboxComponent]:
	var hits: Array[HurtboxComponent] = []

	for area in attack_area.get_overlapping_areas():
		if area is HurtboxComponent:
			var hurtbox := area as HurtboxComponent
			if can_friendly_fire or hurtbox.team != attacker_team:
				hits.append(hurtbox)

	return hits


## Check if a specific target would be hit by a melee attack area
static func would_melee_hit(
	attack_area: Area2D,
	target_hurtbox: HurtboxComponent,
	attacker_team: int,
	can_friendly_fire: bool = false
) -> bool:
	if not can_friendly_fire and target_hurtbox.team == attacker_team:
		return false
	return target_hurtbox in attack_area.get_overlapping_areas()


# =============================================================================
# RANGED CHECKS (Edge-to-Edge Math)
# =============================================================================

## Check if target is within range using edge-to-edge calculation
## Formula: distance_to_target <= attack_range + attacker_radius + target_radius
## This ensures you can shoot a giant boss as soon as their edge enters range
static func is_in_ranged_range(
	attacker_pos: Vector2,
	attacker_radius_tiles: float,
	target_hurtbox: HurtboxComponent,
	attack_range_tiles: float
) -> bool:
	var edge_distance := get_edge_distance_tiles(attacker_pos, attacker_radius_tiles, target_hurtbox)
	return edge_distance <= attack_range_tiles


## Get edge-to-edge distance in tiles between attacker and target
## Returns 0 if overlapping, negative if deeply overlapping
static func get_edge_distance_tiles(
	from_pos: Vector2,
	from_radius_tiles: float,
	to_hurtbox: HurtboxComponent
) -> float:
	var to_pos := to_hurtbox.get_center_world()
	var to_radius := to_hurtbox.get_radius_tiles()

	var center_distance := DistanceConverter.world_distance_in_tiles(from_pos, to_pos)
	return center_distance - from_radius_tiles - to_radius


## Get edge-to-edge distance between two hurtboxes
static func get_edge_distance_between(
	hurtbox_a: HurtboxComponent,
	hurtbox_b: HurtboxComponent
) -> float:
	var center_distance := DistanceConverter.world_distance_in_tiles(
		hurtbox_a.get_center_world(),
		hurtbox_b.get_center_world()
	)
	return center_distance - hurtbox_a.get_radius_tiles() - hurtbox_b.get_radius_tiles()


## Combined ranged attack validity check (range + optional line of sight)
static func can_ranged_attack(
	attacker_pos: Vector2,
	attacker_radius_tiles: float,
	target_hurtbox: HurtboxComponent,
	attack_range_tiles: float,
	require_los: bool = true
) -> bool:
	if not is_in_ranged_range(attacker_pos, attacker_radius_tiles, target_hurtbox, attack_range_tiles):
		return false

	if require_los:
		return PathfindingManager.has_line_of_sight(attacker_pos, target_hurtbox.get_center_world())

	return true


## Find all hurtboxes in ranged range within a node tree
static func find_targets_in_range(
	attacker_pos: Vector2,
	attacker_radius_tiles: float,
	attack_range_tiles: float,
	search_root: Node,
	team_filter: int = -1,
	exclude_same_team: bool = true
) -> Array[HurtboxComponent]:
	var result: Array[HurtboxComponent] = []

	var hurtboxes := _find_all_hurtboxes(search_root)
	for hurtbox in hurtboxes:
		if exclude_same_team and team_filter >= 0 and hurtbox.team == team_filter:
			continue
		if is_in_ranged_range(attacker_pos, attacker_radius_tiles, hurtbox, attack_range_tiles):
			result.append(hurtbox)

	return result


## Find closest target in range
static func find_closest_target_in_range(
	attacker_pos: Vector2,
	attacker_radius_tiles: float,
	attack_range_tiles: float,
	search_root: Node,
	team_filter: int = -1,
	exclude_same_team: bool = true
) -> HurtboxComponent:
	var targets := find_targets_in_range(
		attacker_pos,
		attacker_radius_tiles,
		attack_range_tiles,
		search_root,
		team_filter,
		exclude_same_team
	)

	if targets.is_empty():
		return null

	var closest: HurtboxComponent = null
	var closest_distance := INF

	for target in targets:
		var dist := get_edge_distance_tiles(attacker_pos, attacker_radius_tiles, target)
		if dist < closest_distance:
			closest_distance = dist
			closest = target

	return closest


# =============================================================================
# LINE OF SIGHT (for ranged validity)
# =============================================================================

## Check if there's clear line of sight between two world positions
static func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return PathfindingManager.has_line_of_sight(from, to)


## Check line of sight from position to hurtbox center
static func has_line_of_sight_to_target(from: Vector2, target: HurtboxComponent) -> bool:
	return PathfindingManager.has_line_of_sight(from, target.get_center_world())


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

## Recursively find all HurtboxComponents in a node tree
static func _find_all_hurtboxes(node: Node) -> Array[HurtboxComponent]:
	var result: Array[HurtboxComponent] = []

	if node is HurtboxComponent:
		result.append(node as HurtboxComponent)

	for child in node.get_children():
		result.append_array(_find_all_hurtboxes(child))

	return result


## Sort hurtboxes by distance from a point (closest first)
static func sort_by_distance(
	hurtboxes: Array[HurtboxComponent],
	from_pos: Vector2,
	from_radius_tiles: float = 0.0
) -> Array[HurtboxComponent]:
	var sorted := hurtboxes.duplicate()
	sorted.sort_custom(func(a: HurtboxComponent, b: HurtboxComponent) -> bool:
		var dist_a := get_edge_distance_tiles(from_pos, from_radius_tiles, a)
		var dist_b := get_edge_distance_tiles(from_pos, from_radius_tiles, b)
		return dist_a < dist_b
	)
	return sorted
