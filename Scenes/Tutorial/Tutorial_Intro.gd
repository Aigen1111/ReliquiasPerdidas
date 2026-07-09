# Tutorial_Intro.gd — Zona 1: Historia + movimiento libre
# Next Scene: res://Scenes/Tutorial/Tutorial_Dash.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

func _get_intro_lines() -> Array:
	return [
		"...",
		"¿Podés oírme?",
		"Encontraste el collar en Talamanca. Eso no fue accidente.",
		"Los planos están corrompidos. Necesito tu ayuda para limpiarlos.",
		"No puedo revelarte quién soy todavía. Hay algo que debés encontrar primero.",
		"Por ahora... explorá este lugar. Usá WASD para moverte.",
	]

func _on_intro_finished() -> void:
	_unlock_exit()
