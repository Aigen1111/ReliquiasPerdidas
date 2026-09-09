extends Camera2D

@export var allow_mouse_wheel_zoom := true
@export_range(0.25, 4.0, 0.05) var min_zoom := 1.5
@export_range(0.25, 4.0, 0.05) var max_zoom := 2.5
@export_range(0.01, 1.0, 0.01) var zoom_step := 0.10
@export var smooth_follow := false
@export_range(1.0, 30.0, 0.5) var follow_speed := 12.0

##Camera border "peek"
@export var edge_margin: float = 300.0
@export var max_offset: float = 80.0
@export_range(1.0, 20.0, 0.5) var offset_speed: float = 4.0

var target: Node2D
var _mouse_offset := Vector2.ZERO

func _ready() -> void:
	target = get_parent() as Node2D
	top_level = true
	_set_zoom_level(zoom.x)

	if target != null:
		global_position = target.global_position
		
	
	


func _physics_process(delta: float) -> void:
	if target == null:
		return


	# Calcular el offset objetivo según la posición del mouse en pantalla 
	var screen_size := get_viewport().get_visible_rect().size
	var mouse_screen := get_viewport().get_mouse_position()
	var target_offset := Vector2.ZERO
 
	# Eje X
	if mouse_screen.x < edge_margin:
		target_offset.x = -max_offset * (1.0 - mouse_screen.x / edge_margin)
	elif mouse_screen.x > screen_size.x - edge_margin:
		target_offset.x = max_offset * ((mouse_screen.x - (screen_size.x - edge_margin)) / edge_margin)
 
	# Eje Y
	if mouse_screen.y < edge_margin:
		target_offset.y = -max_offset * (1.0 - mouse_screen.y / edge_margin)
	elif mouse_screen.y > screen_size.y - edge_margin:
		target_offset.y = max_offset * ((mouse_screen.y - (screen_size.y - edge_margin)) / edge_margin)
 
	# Suavizar el offset para que no sea abrupto
	_mouse_offset = _mouse_offset.lerp(target_offset, minf(delta * offset_speed, 1.0))
 
	#  Posición final de la cámara = jugador + offset del mouse
	var desired_pos := target.global_position + _mouse_offset
 
	if smooth_follow:
		global_position = global_position.lerp(desired_pos, minf(delta * follow_speed, 1.0))
	else:
		global_position = desired_pos


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
