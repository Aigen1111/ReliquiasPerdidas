extends Area2D

signal player_entered_door(next_room_path: String)

@export var next_room_path: String = ""
var is_locked: bool = true

@onready var visual = $ColorRect

func _ready():
	# Conectamos la señal que detecta cuando un cuerpo entra al Area2D
	body_entered.connect(_on_body_entered)
	lock()

func lock():
	is_locked = true
	if visual: visual.color = Color.RED # Rojo = Bloqueada

func unlock():
	is_locked = false
	if visual: visual.color = Color.GREEN # Verde = Abierta

func _on_body_entered(body: Node2D):
	# Verificamos que la puerta esté abierta y que quien entró sea el Jugador
	if not is_locked and body.is_in_group("Player"):
		player_entered_door.emit(next_room_path)
