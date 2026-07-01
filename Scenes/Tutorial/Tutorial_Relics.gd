# Tutorial_Relics.gd — Zona 5: Reliquia + revelación de Sibö → Lobby
# next_scene: res://Scenes/Lobby.tscn
extends "res://Scenes/Tutorial/TutorialBase.gd"

var _relic_collected: bool = false

func _get_intro_lines() -> Array:
	return [
		"Hay algo brillando ahí adelante.",
		"Recogelo.",
	]

func _on_intro_finished() -> void:
	var relic := get_node_or_null("RelicPickup")
	if relic:
		relic.body_entered.connect(_on_relic_touched)

func _on_relic_touched(body: Node) -> void:
	if not body.is_in_group("player") or _relic_collected:
		return
	_relic_collected = true
	get_node_or_null("RelicPickup").queue_free()
	RunManager.unlock_relic("sibö_mascara")

	# Revelar a Sibö
	_reveal_sibu()

	_dialog.show_lines([
		"La Máscara de Sibö... en tus manos.",
		"Ahora podés verme como soy. Soy Sibö, guardián de estos mundos.",
		"Esa máscara te otorga un 20% más de vida máxima.",
		"Podés equipar reliquias en el museo antes de cada run.",
		"Usá Tab durante el run para verlas.",
		"El museo te espera. ¡Adelante!",
	], _on_zone_completed)

func _on_zone_completed() -> void:
	RunManager.tutorial_done = true
	_unlock_exit()
