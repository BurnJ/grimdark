class_name HitboxComponent
extends Area2D
## Attack/damage source for melee swings, AOE zones, projectiles
## Active detector: monitoring = true, monitorable = false


signal hit_entity(hurtbox: HurtboxComponent)
signal _all_hits_processed(hit_count: int)  # Reserved for future use

@export var damage: float = 10.0
@export var damage_type: String = "physical"
@export var team: int = 0
@export var can_hit_same_team: bool = false
@export var one_shot: bool = true  ## Disable after first hit per entity?
@export var max_targets: int = -1  ## -1 = unlimited

var _has_hit: bool = false
var _hit_entities: Array[HurtboxComponent] = []
var _collision_shape: CollisionShape2D


func _ready() -> void:
	_setup_area_settings()
	area_entered.connect(_on_area_entered)


func _setup_area_settings() -> void:
	# Hitboxes actively detect hurtboxes but cannot be detected themselves
	collision_layer = 0
	collision_mask = 0
	monitoring = true    # Actively detects hurtboxes
	monitorable = false  # Cannot be detected by others


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		_try_hit(hurtbox)


func _try_hit(hurtbox: HurtboxComponent) -> void:
	# Check if we've already hit this entity
	if hurtbox in _hit_entities:
		return

	# Check one-shot mode
	if one_shot and _has_hit:
		return

	# Check max targets
	if max_targets > 0 and _hit_entities.size() >= max_targets:
		return

	# Check team filtering
	if not can_hit_same_team and hurtbox.team == team:
		return

	# Register the hit
	_hit_entities.append(hurtbox)
	_has_hit = true

	# Emit signal and deal damage
	hit_entity.emit(hurtbox)
	hurtbox.receive_damage(damage, damage_type, get_parent())


## Reset hit tracking (call between attacks)
func reset() -> void:
	_has_hit = false
	_hit_entities.clear()


## Get list of entities hit this attack
func get_hit_entities() -> Array[HurtboxComponent]:
	return _hit_entities.duplicate()


## Get number of entities hit
func get_hit_count() -> int:
	return _hit_entities.size()


## Set collision shape dynamically (for melee attack variety)
func set_shape(shape: Shape2D) -> void:
	# Remove existing collision shape
	if _collision_shape:
		_collision_shape.queue_free()
		_collision_shape = null

	# Create new collision shape
	_collision_shape = CollisionShape2D.new()
	_collision_shape.shape = shape
	add_child(_collision_shape)


## Enable hitbox detection
func activate() -> void:
	monitoring = true


## Disable hitbox detection
func deactivate() -> void:
	monitoring = false


## Check if hitbox is currently active
func is_active() -> bool:
	return monitoring


## Perform instant hit check and return results
## Useful for melee attacks that check once rather than persist
func check_hits_instant() -> Array[HurtboxComponent]:
	var hits: Array[HurtboxComponent] = []

	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			var hurtbox := area as HurtboxComponent
			if _can_hit(hurtbox):
				hits.append(hurtbox)

	return hits


func _can_hit(hurtbox: HurtboxComponent) -> bool:
	if hurtbox in _hit_entities:
		return false
	if one_shot and _has_hit:
		return false
	if max_targets > 0 and _hit_entities.size() >= max_targets:
		return false
	if not can_hit_same_team and hurtbox.team == team:
		return false
	return true
