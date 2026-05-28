extends Node2D

@onready var transition = $RoomTransition
var current_room: Node2D

func load_room(room_path: String):
	# 1. Limpiar la sala anterior si existe
	if current_room:
		current_room.queue_free()
	
	# 2. Cargar e instanciar la nueva sala
	var room_scene = load(room_path)
	current_room = room_scene.instantiate()
	add_child(current_room)
	
	# 3. Conectar las puertas de la nueva sala
	for child in current_room.get_children():
		if child is Area2D and child.has_signal("player_entered_door"):
			child.player_entered_door.connect(_on_player_entered_door)

func _on_player_entered_door(next_room_path: String):
	await transition.fade_out()
	load_room(next_room_path)
	await transition.fade_in()
