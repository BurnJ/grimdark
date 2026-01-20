class_name EnemyAttack
extends Node
## Handles enemy melee attack execution


signal attack_started
signal attack_hit(target: HurtboxComponent)
signal attack_missed

@export var damage: float = 10.0
@export var attack_range_tiles: float = 0.75
@export var attack_width_tiles: float = 0.3

var _hitbox: HitboxComponent
var _owner_enemy: Node2D
var _ai: EnemyAI


func _ready() -> void:
	# Get references from parent
	_owner_enemy = get_parent()
	if _owner_enemy:
		_ai = _owner_enemy.get_node_or_null("EnemyAI")
		if _ai:
			_ai.attack_requested.connect(_on_attack_requested)

	_create_hitbox()


func set_enemy(enemy: Node2D) -> void:
	_owner_enemy = enemy


func set_ai(ai: EnemyAI) -> void:
	_ai = ai
	if _ai and not _ai.attack_requested.is_connected(_on_attack_requested):
		_ai.attack_requested.connect(_on_attack_requested)


func _create_hitbox() -> void:
	_hitbox = HitboxComponent.new()
	_hitbox.damage = damage
	_hitbox.damage_type = "physical"
	_hitbox.team = 1  # Enemy team
	_hitbox.one_shot = true
	add_child(_hitbox)
	_hitbox.deactivate()


func _on_attack_requested() -> void:
	_execute_attack()


func _execute_attack() -> void:
	if not _owner_enemy or not _ai:
		return

	var target := _ai.get_target()
	if not target:
		attack_missed.emit()
		return

	attack_started.emit()

	# Calculate direction to target
	var direction := (target.global_position - _owner_enemy.global_position).normalized()
	var facing_angle := direction.angle()

	# Create attack shape
	var shape := ShapeFactory.create_line(attack_range_tiles, attack_width_tiles, facing_angle)
	_hitbox.set_shape(shape)
	_hitbox.global_position = _owner_enemy.global_position
	_hitbox.damage = damage

	# Activate, check hits, deactivate
	_hitbox.reset()
	_hitbox.activate()

	# Wait one physics frame for collision detection
	await _owner_enemy.get_tree().physics_frame

	var hits := _hitbox.get_hit_entities()
	_hitbox.deactivate()

	if hits.size() > 0:
		for hit in hits:
			attack_hit.emit(hit)
	else:
		attack_missed.emit()
