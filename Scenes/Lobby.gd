# Lobby.gd
extends Node2D

const PEDESTAL_SCRIPT  := "res://Scenes/RelicPedestal.gd"
const MAX_SLOTS:    int = 1   # empieza con 1, se puede expandir mejorando el museo

# Posición del primer pedestal y separación entre slots
const PEDESTAL_ORIGIN:  Vector2 = Vector2(0, 80)
const PEDESTAL_SPACING: float   = 200.0

@onready var relics_label: Label = $HUD/RelicsLabel


func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var gun := player.get_node_or_null("Gun")
		if gun:
			gun.process_mode = Node.PROCESS_MODE_DISABLED

	_populate_pedestals()
	_update_hud()

	# Limpiar active_relics a solo MAX_SLOTS entradas al volver al lobby
	if RunManager.active_relics.size() > MAX_SLOTS:
		RunManager.active_relics.resize(MAX_SLOTS)


func _update_hud() -> void:
	var total:    int = RunManager.unlocked_relics.size()
	var equipped: int = 0
	for r in RunManager.active_relics:
		if r != "":
			equipped += 1

	var lines: Array = []
	lines.append("Reliquias descubiertas: %d / %d" % [total, MuseumData.get_all_relic_ids().size()])
	lines.append("Slots equipados: %d / %d" % [equipped, MAX_SLOTS])

	if RunManager.last_run_floor > 0:
		var result: String = "Victoria ✓" if RunManager.last_run_victory else "Derrota ✗"
		lines.append("Último run: %s (sala %d)" % [result, RunManager.last_run_floor])

	relics_label.text = "\n".join(lines)


func _populate_pedestals() -> void:
	var container := get_node_or_null("RelicPedestals")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	var script: Script = load(PEDESTAL_SCRIPT)

	for i in range(MAX_SLOTS):
		var pedestal := Node2D.new()
		pedestal.set_script(script)
		pedestal.position = PEDESTAL_ORIGIN + Vector2(i * PEDESTAL_SPACING, 0)
		container.add_child(pedestal)
		pedestal.call_deferred("setup", i)
