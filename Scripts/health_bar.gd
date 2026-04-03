extends Node2D

## Ancho de la barra en píxeles de mundo
@export var bar_width: float = 40.0
## Alto de la barra
@export var bar_height: float = 6.0
## Separación vertical sobre el pivote del enemigo (negativo = arriba)
@export var offset_y: float = -24.0

var _current: float = 1.0
var _max: float = 1.0


func _ready() -> void:
	position.y = offset_y


## Llamar esto cada vez que cambie la vida
func update(current: float, max_val: float) -> void:
	_current = current
	_max = max_val
	queue_redraw()


func _draw() -> void:
	var half := bar_width / 2.0

	# Fondo oscuro
	draw_rect(Rect2(-half, 0.0, bar_width, bar_height), Color(0.15, 0.15, 0.15, 0.85))

	# Relleno que cambia de verde → rojo según la vida restante
	var ratio := clampf(_current / _max, 0.0, 1.0)
	if ratio > 0.0:
		var fill_color := Color(1.0 - ratio, ratio * 0.85, 0.0)
		draw_rect(Rect2(-half, 0.0, bar_width * ratio, bar_height), fill_color)

	# Borde fino
	draw_rect(Rect2(-half, 0.0, bar_width, bar_height), Color(0, 0, 0, 0.6), false, 1.0)
