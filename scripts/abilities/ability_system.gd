class_name AbilitySystem
extends Node
## Manages abilities and their execution for an entity


signal ability_started(ability_name: String)
signal ability_completed(ability_name: String)
signal ability_failed(ability_name: String, reason: String)

var _abilities: Dictionary = {}  # String -> AbilityBase
var _current_ability: AbilityBase = null
var _owner: Node2D


func _ready() -> void:
	_owner = get_parent()
	_register_child_abilities()


func _register_child_abilities() -> void:
	for child in get_children():
		if child is AbilityBase:
			register_ability(child)


func register_ability(ability: AbilityBase) -> void:
	_abilities[ability.ability_name] = ability
	ability.ability_owner = _owner


func use_ability(ability_name: String, target: Node = null, cursor_world: Vector2 = null) -> bool:
	if not _abilities.has(ability_name):
		ability_failed.emit(ability_name, "Unknown ability")
		return false

	var ability: AbilityBase = _abilities[ability_name]

	if not ability.can_use():
		ability_failed.emit(ability_name, "On cooldown")
		return false

	_current_ability = ability
	ability_started.emit(ability_name)

	# Forward optional cursor_world to ability.execute if supported
	if ability.has_method("execute"):
		# call with two args if the method accepts cursor_world
		# many abilities accept only (target), but BasicStrike accepts (target, cursor_world)
		ability.execute(target, cursor_world)

	_current_ability = null
	ability_completed.emit(ability_name)
	return true


func is_ability_ready(ability_name: String) -> bool:
	if not _abilities.has(ability_name):
		return false
	return _abilities[ability_name].can_use()


func get_ability(ability_name: String) -> AbilityBase:
	return _abilities.get(ability_name)


func has_ability(ability_name: String) -> bool:
	return _abilities.has(ability_name)


func get_all_abilities() -> Array[AbilityBase]:
	var result: Array[AbilityBase] = []
	for ability in _abilities.values():
		result.append(ability)
	return result


func is_using_ability() -> bool:
	return _current_ability != null


func get_current_ability() -> AbilityBase:
	return _current_ability
