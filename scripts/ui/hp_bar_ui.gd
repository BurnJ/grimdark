class_name HPBarUI
extends Control
## Displays player health as a horizontal bar


@export var bar_width: float = 200.0
@export var bar_height: float = 20.0
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var fill_color: Color = Color(0.8, 0.2, 0.2, 1.0)
@export var low_health_color: Color = Color(0.6, 0.1, 0.1, 1.0)
@export var low_health_threshold: float = 0.25

var _health_component: HealthComponent
var _current_percent: float = 1.0
var _target_percent: float = 1.0

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Background/Fill
@onready var label: Label = $Label


func _ready() -> void:
	_setup_bar()


func _process(delta: float) -> void:
	# Smooth interpolation toward target health
	if absf(_current_percent - _target_percent) > 0.001:
		_current_percent = lerpf(_current_percent, _target_percent, delta * 10.0)
		_update_fill()


func connect_to_health(health_component: HealthComponent) -> void:
	if _health_component:
		_health_component.health_changed.disconnect(_on_health_changed)

	_health_component = health_component
	_health_component.health_changed.connect(_on_health_changed)

	# Initialize with current values
	_on_health_changed(_health_component.current_health, _health_component.max_health)


func _setup_bar() -> void:
	custom_minimum_size = Vector2(bar_width, bar_height + 20)

	if background:
		background.custom_minimum_size = Vector2(bar_width, bar_height)
		background.size = Vector2(bar_width, bar_height)
		background.color = background_color

	if fill:
		fill.custom_minimum_size = Vector2(bar_width, bar_height)
		fill.size = Vector2(bar_width, bar_height)
		fill.color = fill_color


func _on_health_changed(current: int, maximum: int) -> void:
	_target_percent = float(current) / float(maximum) if maximum > 0 else 0.0

	# Update label
	if label:
		label.text = "%d / %d" % [current, maximum]


func _update_fill() -> void:
	if not fill:
		return

	fill.size.x = bar_width * _current_percent

	# Change color when low health
	if _current_percent <= low_health_threshold:
		fill.color = low_health_color
	else:
		fill.color = fill_color
