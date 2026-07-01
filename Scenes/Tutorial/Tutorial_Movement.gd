# Tutorial_Movement.gd — Zona 2: Movimiento
# next_scene: res://Scenes/Tutorial/Tutorial_Dash.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

func _get_intro_lines() -> Array:
	return [
		"Usá WASD o las flechas para moverte.",
		"El ratón controla hacia dónde apuntás.",
		"Explorá esta zona y seguí el camino.",
	]

func _on_intro_finished() -> void:
	_unlock_exit()
