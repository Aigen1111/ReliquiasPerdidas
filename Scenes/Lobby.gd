# Lobby.gd  (versión walkable — reemplaza la versión anterior con botón)
# ─────────────────────────────────────────────────────────────────────────────
# El lobby es una sala normal que el jugador puede explorar. La UI es solo
# un overlay mínimo. La interacción con el portal y los pedestales se maneja
# en sus propios scripts.
#
# ESTRUCTURA DE ESCENA (Lobby.tscn):
#   Lobby (Node2D)  ← este script
#   ├── TileMapLayer            (piso/paredes del lobby, placeholder por ahora)
#   ├── Player (player.tscn)    (instancia del jugador, posicionado al centro)
#   ├── Portal (Portal.tscn)    (a la derecha de la sala — inicia el run)
#   ├── RelicPedestals (Node2D) (hijos: RelicPedestal.tscn ×N, ver abajo)
#   └── HUD (CanvasLayer)
#       └── RelicsLabel (Label) (esquina sup. izq.)
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D


@onready var relics_label: Label = $HUD/RelicsLabel


func _ready() -> void:
	# Desactivar arma en el lobby
	var player := $Player
	var gun := player.get_node_or_null("Gun")
	if gun:
		gun.process_mode = Node.PROCESS_MODE_DISABLED
	_update_hud()
	_populate_relic_pedestals()


func _update_hud() -> void:
	var count: int = RunManager.unlocked_relics.size()
	relics_label.text = "Reliquias: %d" % count
	if RunManager.last_run_floor > 0:
		var result := "Victoria ✓" if RunManager.last_run_victory else "Derrota ✗"
		relics_label.text += "\nÚltimo run: %s (piso %d)" % [result, RunManager.last_run_floor]


func _populate_relic_pedestals() -> void:
	if not has_node("RelicPedestals"):
		return
	var pedestals := $RelicPedestals.get_children()
	for i: int in range(pedestals.size()):
		var pedestal := pedestals[i]
		if not pedestal.has_method("setup"):
			continue
		if i < RunManager.unlocked_relics.size():
			pedestal.setup(RunManager.unlocked_relics[i])
		else:
			pedestal.setup("")
