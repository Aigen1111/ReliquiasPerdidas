extends Node2D

var enemies_alive: int = 0
var is_cleared: bool = false

func _ready():
	# Al cargar la sala, contamos cuántos enemigos hay y bloqueamos las puertas
	for child in get_children():
		if child.is_in_group("Enemy"):
			enemies_alive += 1
			# Conectamos la señal "died" que le pusimos a tu enemigo
			child.died.connect(_on_enemy_died)
		elif child is Area2D and child.has_method("lock"):
			child.lock()
	
	# Si entras a una sala y no hay enemigos, se abre sola
	if enemies_alive == 0:
		clear_room()

func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive <= 0 and not is_cleared:
		clear_room()

func clear_room():
	is_cleared = true
	# Abrimos todas las puertas de la sala
	for child in get_children():
		if child is Area2D and child.has_method("unlock"):
			child.unlock()
