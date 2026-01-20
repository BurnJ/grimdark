extends Node2D
class_name ClickMarker
## Visual indicator showing where player clicked - fades out quickly

func _ready() -> void:
	# Fade out and remove
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Draw a simple ring at click position
	draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, Color(1.0, 1.0, 1.0, 0.7), 2.0)
	# Inner dot
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.5))
