# Tutorial_Shooting.gd — Zona 4: Disparo con dummies
# next_scene: res://Scenes/Tutorial/Tutorial_Relics.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

var _enemies_alive: int = 0

func _get_intro_lines() -> Array:
	return [
		"Hay obstaculos en esta zona.",
		"Click izquierdo para disparar. Tenés 5 balas — R para recargar.",
		"Destruyelos para continuar.",
	]

func _on_intro_finished() -> void:
	_set_gun_enabled(true)
	# Conectar enemigos
	var enemies_node := get_node_or_null("Enemies")
	if enemies_node:
		for child in enemies_node.get_children():
			if child.has_signal("died"):
				child.died.connect(_on_enemy_died)
				_enemies_alive += 1
	# Si no hay enemigos en escena, completar igual
	if _enemies_alive == 0:
		_on_zone_completed()

func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_dialog.show_lines([
			"¡Bien hecho!",
			"Sigue adelante.",
		], _on_zone_completed)

func _on_zone_completed() -> void:
	_unlock_exit()
