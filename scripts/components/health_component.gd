class_name HealthComponent
extends Node
## Reusable health management for any entity (player, enemies, destructibles)


signal health_changed(current: int, maximum: int)
signal damage_taken(amount: int, source: Node)
signal healed(amount: int)
signal died

@export var max_health: int = 100
@export var starting_health: int = -1  ## -1 = use max_health

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	current_health = starting_health if starting_health > 0 else max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int, source: Node = null) -> void:
	if is_dead:
		return

	var actual_damage := mini(amount, current_health)
	current_health -= actual_damage

	damage_taken.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_die()


func heal(amount: int) -> void:
	if is_dead:
		return

	var actual_heal := mini(amount, max_health - current_health)
	current_health += actual_heal

	if actual_heal > 0:
		healed.emit(actual_heal)
		health_changed.emit(current_health, max_health)


func _die() -> void:
	is_dead = true
	died.emit()


func reset() -> void:
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)


func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)


func is_full_health() -> bool:
	return current_health >= max_health


func set_max_health(new_max: int, heal_to_full: bool = false) -> void:
	max_health = new_max
	if heal_to_full:
		current_health = max_health
	else:
		current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)
