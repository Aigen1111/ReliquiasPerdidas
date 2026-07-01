# Tutorial_Dash.gd — Zona 3: Dash
# next_scene: res://Scenes/Tutorial/Tutorial_Shooting.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

func _get_intro_lines() -> Array:
	return [
		"Ves ese obstáculo adelante.",
		"Presioná Espacio para hacer un dash y esquivarlo.",
		"El dash también te salva de ataques enemigos. Practicalo bien.",
	]

func _on_intro_finished() -> void:
	# La zona se completa simplemente al llegar al portal tras hacer dash
	_unlock_exit()
