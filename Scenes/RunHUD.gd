# RunHUD.gd
# HUD visible durante la run. Adjuntar a RunHUD.tscn (CanvasLayer, layer=5).
# Instanciar RunHUD.tscn como hijo del nodo raíz de CADA room (Room.tscn),
# o mejor: agregarlo como AutoLoad en project.godot para que persista.
#
# OPCIÓN MÁS SIMPLE: agregarlo como hijo de Room.tscn base — se instancia
# automáticamente en todas las rooms.
#
# ESTRUCTURA DE ESCENA (RunHUD.tscn):
#   RunHUD (CanvasLayer, layer=5) ← este script
#   └── MarginContainer (márgenes 16px)
#       ├── HBoxContainer (arriba izquierda)
#       │   ├── HealthBar (ProgressBar, min=0, max=100, w=180, h=20)
#       │   └── HealthLabel (Label, "100 / 100")
#       └── GoldLabel (Label, esquina sup. derecha, texto "🪙 0")
extends CanvasLayer

@onready var health_bar:   ProgressBar = $MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label       = $MarginContainer/HBoxContainer/HealthLabel
@onready var gold_label:   Label       = $GoldLabel   # anclado arriba-derecha

func _ready() -> void:
	# Conectar señal de oro del RunManager
	RunManager.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(RunManager.get_display_gold())

func _process(_delta: float) -> void:
	# Actualizar vida en tiempo real leyendo del RunManager
	var hp:     float = RunManager.player_current_health
	var max_hp: float = RunManager.player_max_health
	health_bar.max_value = max_hp
	health_bar.value     = hp
	health_label.text    = "%d / %d" % [int(hp), int(max_hp)]
	# Color de la barra según % de vida
	if hp / max_hp > 0.5:
		health_bar.modulate = Color(0.2, 0.9, 0.2)
	elif hp / max_hp > 0.25:
		health_bar.modulate = Color(0.9, 0.7, 0.1)
	else:
		health_bar.modulate = Color(0.9, 0.2, 0.2)

func _on_gold_changed(new_amount: int) -> void:
	gold_label.text = "🪙 %d" % new_amount
