# Tutorial_Intro.gd — Zona 1: Introducción e historia
# next_scene: res://Scenes/Tutorial/Tutorial_Movement.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

func _get_intro_lines() -> Array:
	return [
		"...",
		"¿Podés oírme?",
		"Encontraste el collar en Talamanca. Eso no fue accidente.",
		"No puedo revelarte quién soy todavía. Hay algo que debés encontrar primero.",
		"Por ahora... seguí el camino.",
	]

func _on_intro_finished() -> void:
	_unlock_exit()
