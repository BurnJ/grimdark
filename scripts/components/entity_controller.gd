extends CharacterBody2D
class_name EntityController
## Base class for all moving entities (player, enemies)

var _push_velocity: Vector2 = Vector2.ZERO
const PUSH_DECAY := 5.0  # How fast push force decays


func _physics_process(delta: float) -> void:
	# Decay push force over time
	_push_velocity = _push_velocity.move_toward(Vector2.ZERO, PUSH_DECAY * delta)

	# Subclasses should set their own velocity
	# Then we add push on top
	velocity += _push_velocity

	# Perform physics movement
	move_and_slide()

	# Reduce push after movement
	_push_velocity *= 0.8


func apply_push(force: Vector2) -> void:
	_push_velocity += force
	# Cap maximum push speed
	if _push_velocity.length() > 200.0:
		_push_velocity = _push_velocity.normalized() * 200.0
