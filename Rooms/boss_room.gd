# boss_room.gd
# Adjuntar a BossRoom_Bribri.tscn reemplazando el script actual.
extends Node2D

# ── DATOS DE LA RELIQUIA QUE OTORGA ESTE BOSS ────────────────────────────
# Cada boss define qué reliquia desbloquea al morir.
# El ID debe coincidir con las entradas en MuseumData.RELICS.
@export var relic_id: String = "sibö_mascara"

var boss_alive: bool = true

func _ready() -> void:
	for child in get_children():
		if child.is_in_group("Enemy"):
			child.died.connect(_on_boss_died)
	var door = get_node_or_null("Door")
	if door:
		door.player_entered_door.connect(_on_door_entered)

func _on_boss_died() -> void:
	boss_alive = false
	# Desbloquear la reliquia en RunManager
	RunManager.unlock_relic(relic_id)
	# Abrir la puerta
	var door = get_node_or_null("Door")
	if door and door.has_method("unlock"):
		door.unlock()

func _on_door_entered() -> void:
	if not boss_alive:
		RunManager.complete_run()
