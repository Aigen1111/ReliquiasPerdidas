# room.gd — Sala de combate con oleadas y spawn indicators
#
# SPAWN: las oleadas aparecen en un anillo alrededor del jugador (estilo
# Vampire Survivors/Brotato solo en este aspecto puntual — el spawn, no el
# combate, que sigue siendo disparo manual). Ya no depende de marcadores de
# enemigo colocados a mano en el editor: cualquier sala de combate, pintada
# o no, tiene oleadas completas desde el primer momento.
extends "res://Rooms/portal_room.gd"

const ENEMY_POOLS: Array = [
	["res://Enemies/EnemyLancero.tscn", "res://Enemies/EnemyEscudo.tscn"],
	["res://Enemies/EnemyLancero.tscn", "res://Enemies/EnemyEscudo.tscn", "res://Enemies/EnemyAmetralladora.tscn"],
	["res://Enemies/EnemyAmetralladora.tscn", "res://Enemies/EnemyFrancotirador.tscn", "res://Enemies/EnemyLancero.tscn", "res://Enemies/EnemyEscudo.tscn"],
]
const WAVE_CONFIG: Array = [
	{ "min": 4, "max": 6,  "waves": [0.5, 0.5] },
	{ "min": 6, "max": 9,  "waves": [0.34, 0.33, 0.33] },
	{ "min": 8, "max": 12, "waves": [0.25, 0.35, 0.40] },
]
const SPAWN_WARN_DURATION: float = 3.0
const WAVE_DELAY:          float = 1.0

# ── Spawn alrededor del jugador ────────────────────────────────────────────
@export var wave_spawn_min_radius:  float = 220.0   # muy cerca se siente injusto
@export var wave_spawn_max_radius:  float = 380.0   # muy lejos y el enemigo tarda en llegar
@export var wave_spawn_edge_margin: float = 48.0     # no caer pegado a la pared
const SPAWN_PLACEMENT_ATTEMPTS: int = 12             # intentos por punto antes de resignarse

var enemies_alive:    int   = 0
var _pending_spawn_positions: Array[Vector2] = []
var _wave_sizes:      Array = []
var _current_wave:    int   = 0
var _zone:            int   = 0
var _pool:            Array = []


func _ready() -> void:
	_setup_portal_base()
	_clear_legacy_spawn_markers()

	_zone = clamp(RunManager.current_zone_index, 0, WAVE_CONFIG.size() - 1)
	_pool = ENEMY_POOLS[_zone]
	_wave_sizes = _calculate_waves()

	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_show_wave_indicators()


# Salas viejas todavía pueden tener nodos Enemy colocados a mano como
# marcador de spawn (sistema anterior) — ya no se usan para calcular
# posiciones, pero si quedó alguno en la escena hay que sacarlo para que no
# aparezca como un enemigo real extra parado ahí desde el arranque.
func _clear_legacy_spawn_markers() -> void:
	for child in get_children():
		if child.is_in_group("Enemy") or (child.get_script() and str(child.get_script().resource_path).contains("enemy")):
			child.queue_free()
	for child in get_children():
		if child.name.begins_with("Enemy") and child is Node2D:
			child.queue_free()


func _calculate_waves() -> Array:
	var cfg: Dictionary = WAVE_CONFIG[_zone]
	var total: int = randi_range(cfg["min"], cfg["max"])
	var sizes: Array = []
	var assigned: int = 0
	for i in range(cfg["waves"].size()):
		var count: int = total - assigned if i == cfg["waves"].size() - 1 \
			else max(1, int(total * cfg["waves"][i]))
		sizes.append(count)
		assigned += count
	return sizes


# Arma `count` posiciones en un anillo alrededor del jugador (entre
# wave_spawn_min_radius y wave_spawn_max_radius), evitando caer fuera del
# área jugable o pegado a la pared. Si no hay tilemap de piso todavía
# (sala sin pintar), no valida contra el área — igual reparte los puntos
# alrededor del jugador, para que el combate funcione desde el día uno.
func _get_wave_spawn_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var player: Node2D = _get_player_node()
	if player == null:
		return positions

	var local_player: Vector2 = to_local(player.global_position)
	var play_area: Rect2 = MapBorder.get_play_area(self)
	var has_bounds: bool = play_area.size.x > 0.0 and play_area.size.y > 0.0
	var safe_area: Rect2 = play_area.grow(-wave_spawn_edge_margin) if has_bounds else Rect2()

	for i in range(count):
		var chosen: Vector2 = local_player
		var found: bool = false
		for attempt in range(SPAWN_PLACEMENT_ATTEMPTS):
			var angle:  float = randf() * TAU
			var radius: float = randf_range(wave_spawn_min_radius, wave_spawn_max_radius)
			var candidate: Vector2 = local_player + Vector2(cos(angle), sin(angle)) * radius
			if not has_bounds or safe_area.has_point(candidate):
				chosen = candidate
				found  = true
				break
		# Si ningún intento cayó dentro del área (sala chica/angosta), se
		# usa el último candidato igual — mejor un spawn algo pegado a la
		# pared que perder una posición entera de la oleada.
		positions.append(chosen)
	return positions


func _get_player_node() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D


func _show_wave_indicators() -> void:
	var count: int = _wave_sizes[_current_wave] if _current_wave < _wave_sizes.size() else 0

	var final_positions: Array[Vector2] = _get_wave_spawn_positions(count)
	_pending_spawn_positions = final_positions

	var indicators: Array = []
	for pos in final_positions:
		var ind := _build_spawn_indicator(pos)
		add_child(ind)
		indicators.append(ind)

	await _animate_indicators(indicators)
	for ind in indicators:
		if is_instance_valid(ind):
			ind.queue_free()
	_spawn_wave()


func _spawn_wave() -> void:
	if _current_wave >= _wave_sizes.size():
		return
	for pos in _pending_spawn_positions:
		var scene: PackedScene = load(_pool[randi() % _pool.size()])
		if scene == null:
			continue
		var enemy = scene.instantiate()
		add_child(enemy)
		enemy.global_position = to_global(pos)
		enemy.died.connect(_on_enemy_died)
		enemies_alive += 1
	_pending_spawn_positions.clear()
	_current_wave += 1


func _build_spawn_indicator(local_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = local_pos
	var rect := ColorRect.new()
	rect.color    = Color(1.0, 0.15, 0.15, 0.7)
	rect.size     = Vector2(36, 36)
	rect.position = Vector2(-18, -18)
	node.add_child(rect)
	var lbl := Label.new()
	lbl.name                  = "CountLabel"
	lbl.text                  = str(int(SPAWN_WARN_DURATION))
	lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position              = Vector2(-20, -28)
	lbl.add_theme_font_size_override("font_size", 18)
	node.add_child(lbl)
	return node


func _animate_indicators(indicators: Array) -> void:
	var elapsed: float = 0.0
	while elapsed < SPAWN_WARN_DURATION:
		# is_inside_tree() verifica que el nodo esté en el árbol Y que get_tree() no sea null
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
		var remaining: int   = max(1, int(ceil(SPAWN_WARN_DURATION - elapsed)))
		var pulse:     float = 0.5 + 0.5 * sin(elapsed * TAU * 2.0)
		for ind in indicators:
			if not is_instance_valid(ind):
				continue
			var rect: ColorRect = ind.get_node_or_null("ColorRect")
			if rect:
				rect.color = Color(1.0, 0.15, 0.15, 0.4 + 0.4 * pulse)
			var lbl: Label = ind.get_node_or_null("CountLabel")
			if lbl:
				lbl.text = str(remaining)


func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive > 0:
		return
	if _current_wave < _wave_sizes.size():
		if not is_inside_tree():
			return
		await get_tree().create_timer(WAVE_DELAY, false).timeout
		if not is_inside_tree():
			return
		_show_wave_indicators()
	else:
		_open_portals()
