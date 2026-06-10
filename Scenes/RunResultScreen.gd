# RunResultScreen.gd
# Muestra victoria/derrota, sala alcanzada, oro y TODAS las reliquias
# descubiertas en el run (no solo la última).
extends CanvasLayer

@onready var title_label:     Label  = $Panel/VBoxContainer/TitleLabel
@onready var floor_label:     Label  = $Panel/VBoxContainer/FloorLabel
@onready var gold_label:      Label  = $Panel/VBoxContainer/GoldLabel
@onready var relic_label:     Label  = $Panel/VBoxContainer/RelicLabel
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	RunManager.run_ended.connect(_on_run_ended)
	hide()


func _on_run_ended(victory: bool, gold_earned: int) -> void:
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	show()

	if victory:
		title_label.text = "¡Victoria!"
		title_label.modulate = Color(1.0, 0.85, 0.1)
	else:
		title_label.text = "Derrota..."
		title_label.modulate = Color(0.8, 0.2, 0.2)

	floor_label.text = "Sala alcanzada: %d / %d" % [
		RunManager.last_run_floor,
		RunManager.run_sequence.size()
	]
	gold_label.text = "Oro obtenido: %d 🪙" % gold_earned

	# Mostrar todas las reliquias descubiertas en este run
	var found: Array = RunManager.relics_found_this_run
	if found.is_empty():
		relic_label.text = "Sin nuevas reliquias"
		relic_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		var names: Array = []
		for relic_id in found:
			var data: Dictionary = MuseumData.get_relic(relic_id)
			names.append("✦ " + data.get("name", relic_id))
		relic_label.text = "Reliquias descubiertas:\n" + "\n".join(names)
		relic_label.modulate = Color(1.0, 0.85, 0.2)
	relic_label.show()


func _on_continue() -> void:
	get_tree().paused = false
	hide()
	RunManager.go_to_lobby()
