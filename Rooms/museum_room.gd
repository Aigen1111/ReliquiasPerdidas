# museum_room.gd — Sala de museo
# Extiende portal_room para tener portales dobles al salir.
# Deshabilita el arma del jugador — no hay combate en el museo.
extends "res://Rooms/portal_room.gd"


func _ready() -> void:
	_setup_portal_base()

	# Deshabilitar arma del jugador
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or get_tree() == null:
		return
	if not is_instance_valid(self):
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var gun := players[0].get_node_or_null("Gun")
		if gun:
			gun.process_mode = Node.PROCESS_MODE_DISABLED
			# Cancelar cualquier recarga activa
			if gun.has_method("_cancel_reload"):
				gun._cancel_reload()

	# Conectar ficha cultural si existe en la escena
	var artifact := get_node_or_null("ArtifactDisplay")
	if artifact and artifact.has_method("setup"):
		var zone: int = clamp(RunManager.current_zone_index, 0, 2)
		artifact.setup(zone)

	# Abrir portales de salida directamente (no hay enemigos)
	_open_portals()
