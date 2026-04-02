extends Camera2D

@export var allow_mouse_wheel_zoom := true
@export_range(0.25, 4.0, 0.05) var min_zoom := 0.75
@export_range(0.25, 4.0, 0.05) var max_zoom := 2.5
@export_range(0.01, 1.0, 0.01) var zoom_step := 0.10
@export var smooth_follow := false
@export_range(1.0, 30.0, 0.5) var follow_speed := 12.0

var target: Node2D


func _ready() -> void:
	target = get_parent() as Node2D
	top_level = true
	_set_zoom_level(zoom.x)

	if target != null:
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return

	if smooth_follow:
		global_position = global_position.lerp(target.global_position, min(delta * follow_speed, 1.0))
	else:
		global_position = target.global_position


func _unhandled_input(event: InputEvent) -> void:
	if not allow_mouse_wheel_zoom:
		return

	if event.is_action_pressed("mousewheel_up"):
		_set_zoom_level(zoom.x + zoom_step)
	elif event.is_action_pressed("mousewheel_down"):
		_set_zoom_level(zoom.x - zoom_step)


func _set_zoom_level(value: float) -> void:
	var zoom_level := clampf(value, min_zoom, max_zoom)
	zoom = Vector2.ONE * zoom_level
