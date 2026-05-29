extends Node2D

var enemies_alive: int = 0
var is_cleared: bool = false

func _ready():
	for child in get_children():
		if child.is_in_group("Enemy"):
			enemies_alive += 1
			child.died.connect(_on_enemy_died)
		elif child is Area2D and child.has_method("lock"):
			child.lock()

	var exit_door = get_node_or_null("Door")
	if exit_door:
		# Escuchar la señal del door en lugar de body_entered directamente
		exit_door.player_entered_door.connect(_on_player_entered_door)

	if enemies_alive == 0:
		clear_room()

func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive <= 0 and not is_cleared:
		clear_room()

func clear_room():
	is_cleared = true
	for child in get_children():
		if child is Area2D and child.has_method("unlock"):
			child.unlock()

func _on_player_entered_door():
	if is_cleared:
		RunManager.advance_room()
