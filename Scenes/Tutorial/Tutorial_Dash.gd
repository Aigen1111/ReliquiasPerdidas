# Tutorial_Dash.gd — Zona 3: Dash
# next_scene: res://Scenes/Tutorial/Tutorial_Shooting.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

func _get_intro_lines() -> Array:
	return [
		"Algo va a dispararte desde el costado.",
		"Presioná Shift para hacer un dash y esquivarlo.",
		"Así vas a esquivar los ataques de tus enemigos. Practicalo bien.",
	]

func _on_intro_finished() -> void:
	var emitter := get_node_or_null("HazardEmitter")
	if emitter:
		emitter.start()
	# La zona se completa simplemente al llegar al portal tras hacer dash
	_unlock_exit()
