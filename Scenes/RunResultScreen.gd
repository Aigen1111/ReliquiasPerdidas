# RunResultScreen.gd
# Pantalla que aparece al terminar un run (victoria o derrota).
# Adjuntar a RunResultScreen.tscn (CanvasLayer)
#
# ESTRUCTURA DE ESCENA (RunResultScreen.tscn):
#   RunResultScreen (CanvasLayer, layer=20) ← este script
#   └── Panel (PanelContainer, centrado, ~500×350px)
#       ├── VBoxContainer
#       │   ├── TitleLabel     (Label, fuente grande)
#       │   ├── FloorLabel     (Label)
#       │   ├── GoldLabel      (Label)
#       │   ├── RelicLabel     (Label) ← muestra reliquia desbloqueada si hay
#       │   └── ContinueButton (Button, "Volver al museo")
extends CanvasLayer

@onready var title_label:    Label  = $Panel/VBoxContainer/TitleLabel
@onready var floor_label:    Label  = $Panel/VBoxContainer/FloorLabel
@onready var gold_label:     Label  = $Panel/VBoxContainer/GoldLabel
@onready var relic_label:    Label  = $Panel/VBoxContainer/RelicLabel
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue)
	# Conectar señal del RunManager para mostrarse automáticamente
	RunManager.run_ended.connect(_on_run_ended)
	hide()

func _on_run_ended(victory: bool, gold_earned: int) -> void:
	show()
	if victory:
		title_label.text = "¡Victoria!"
		title_label.modulate = Color(1.0, 0.85, 0.1)
		# Mostrar reliquia desbloqueada si hay
		var last_relic: String = RunManager.unlocked_relics.back() if RunManager.unlocked_relics.size() > 0 else ""
		if last_relic != "":
			relic_label.text = "Reliquia obtenida: %s" % last_relic.replace("_", " ").capitalize()
			relic_label.show()
		else:
			relic_label.hide()
	else:
		title_label.text = "Derrota..."
		title_label.modulate = Color(0.8, 0.2, 0.2)
		relic_label.hide()

	floor_label.text = "Sala alcanzada: %d / %d" % [RunManager.last_run_floor, RunManager.run_sequence.size()]
	gold_label.text  = "Oro obtenido: %d 🪙" % gold_earned

func _on_continue() -> void:
	hide()
	# El RunManager ya cambió a Lobby.tscn en complete_run() / player_died()
	# Solo ocultamos la pantalla
