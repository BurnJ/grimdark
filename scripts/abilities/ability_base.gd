class_name AbilityBase
extends Node
## Base class for all abilities - extend this for specific ability implementations


signal ability_executed
signal ability_ready

@export var ability_name: String = "ability"
@export var cooldown: float = 1.0
@export var range_tiles: float = 1.0

var ability_owner: Node2D
var _cooldown_timer: float = 0.0


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_cooldown_timer = 0.0
			ability_ready.emit()


func can_use() -> bool:
	return _cooldown_timer <= 0.0


func execute(_target: Node = null, _cursor_world = null) -> void:
	## Override in subclasses to implement ability logic. Some abilities may
	## accept an optional cursor_world parameter (world-space Vector2) to
	## influence targeting. Keep the signature compatible with existing
	## subclasses by providing a default null value.
	_start_cooldown()
	ability_executed.emit()


func _start_cooldown() -> void:
	_cooldown_timer = cooldown


func get_cooldown_remaining() -> float:
	return _cooldown_timer


func get_cooldown_percent() -> float:
	if cooldown <= 0.0:
		return 0.0
	return _cooldown_timer / cooldown


func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0


func reset_cooldown() -> void:
	_cooldown_timer = 0.0
	ability_ready.emit()
