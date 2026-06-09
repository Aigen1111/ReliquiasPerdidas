# room.gd — Sala de combate con oleadas
# ─────────────────────────────────────────────────────────────────────────────
# CAMBIOS vs versión anterior:
#   - Fix race condition: la puerta ya NO se abre en _ready antes de que terminen
#     de spawnear los enemigos. El check se hace al final del propio spawn.
#   - Sistema de oleadas: los enemigos se dividen en grupos y spawnean
#     progresivamente. La puerta solo se abre al terminar la última oleada.
#   - Cantidad total de enemigos aleatoria dentro de un rango por zona.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

# ── Pools de enemigos por zona ─────────────────────────────────────────────
const ENEMY_POOLS: Array = [
	# Zona 0 — Jungla
	[
		"res://Enemies/EnemyLancero.tscn",
		"res://Enemies/EnemyEscudo.tscn",
	],
	# Zona 1 — Ruinas
	[
		"res://Enemies/EnemyLancero.tscn",
		"res://Enemies/EnemyEscudo.tscn",
		"res://Enemies/EnemyAmetralladora.tscn",
	],
	# Zona 2 — Corrupta
	[
		"res://Enemies/EnemyAmetralladora.tscn",
		"res://Enemies/EnemyFrancotirador.tscn",
		"res://Enemies/EnemyLancero.tscn",
		"res://Enemies/EnemyEscudo.tscn",
	],
]

# ── Config de oleadas por zona ─────────────────────────────────────────────
# [total_min, total_max, oleadas]
# Las oleadas son proporciones que suman 1.0 — se reparten del total aleatorio.
# Ejemplo zona 0: entre 4 y 6 enemigos en 2 oleadas (50% / 50%)
const WAVE_CONFIG: Array = [
	{ "min": 4, "max": 6,  "waves": [0.5, 0.5] },           # Zona 0 — Jungla
	{ "min": 6, "max": 9,  "waves": [0.34, 0.33, 0.33] },   # Zona 1 — Ruinas
	{ "min": 8, "max": 12, "waves": [0.25, 0.35, 0.40] },   # Zona 2 — Corrupta
]

# ── Tiempo entre oleadas (segundos) ───────────────────────────────────────
const WAVE_DELAY: float = 1.5

# ── Estado ────────────────────────────────────────────────────────────────
var enemies_alive:    int  = 0
var is_cleared:       bool = false
var _spawn_positions: Array = []
var _wave_sizes:      Array = []   # [int] — cuántos spawnear por oleada
var _current_wave:    int   = 0
var _zone:            int   = 0
var _pool:            Array = []


func _ready() -> void:
	# Recolectar posiciones placeholder y eliminarlos
	for child in get_children():
		if child.is_in_group("Enemy"):
			_spawn_positions.append(child.global_position)
			child.queue_free()

	# Conectar puerta — empieza BLOQUEADA (lock() ya es el estado inicial de door.gd)
	var exit_door = get_node_or_null("Door")
	if exit_door:
		exit_door.player_entered_door.connect(_on_player_entered_door)

	# Calcular oleadas y arrancar spawn
	_zone = clamp(RunManager.current_zone_index, 0, WAVE_CONFIG.size() - 1)
	_pool = ENEMY_POOLS[_zone]
	_wave_sizes = _calculate_waves()

	# Si no hay posiciones placeholder, abrir directo (sala vacía por diseño)
	if _spawn_positions.is_empty():
		clear_room()
		return

	await get_tree().process_frame  # esperar queue_free de placeholders
	_spawn_wave()


# ── Cálculo de oleadas ─────────────────────────────────────────────────────

func _calculate_waves() -> Array:
	var cfg: Dictionary = WAVE_CONFIG[_zone]
	var total: int = randi_range(cfg["min"], cfg["max"])
	# Limitar al número de posiciones disponibles
	total = min(total, _spawn_positions.size())

	var proportions: Array = cfg["waves"]
	var sizes: Array = []
	var assigned: int = 0

	for i in range(proportions.size()):
		var count: int
		if i == proportions.size() - 1:
			# Última oleada toma el resto para que sumen exacto
			count = total - assigned
		else:
			count = max(1, int(total * proportions[i]))
		sizes.append(count)
		assigned += count

	return sizes


# ── Spawn de oleada ────────────────────────────────────────────────────────

func _spawn_wave() -> void:
	if _current_wave >= _wave_sizes.size():
		return

	var count: int = _wave_sizes[_current_wave]

	# Usar posiciones disponibles (las siguientes del array según oleada)
	var start_idx: int = 0
	for i in range(_current_wave):
		start_idx += _wave_sizes[i]

	for i in range(count):
		var pos_idx: int = start_idx + i
		if pos_idx >= _spawn_positions.size():
			break

		var scene_path: String = _pool[randi() % _pool.size()]
		var scene: PackedScene = load(scene_path)
		if scene == null:
			push_warning("room.gd: no se pudo cargar %s" % scene_path)
			continue

		var enemy = scene.instantiate()
		add_child(enemy)
		enemy.global_position = _spawn_positions[pos_idx]
		enemy.died.connect(_on_enemy_died)
		enemies_alive += 1

	_current_wave += 1


# ── Callbacks ──────────────────────────────────────────────────────────────

func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive > 0:
		return

	# Si quedan oleadas, esperar y spawnear la siguiente
	if _current_wave < _wave_sizes.size():
		await get_tree().create_timer(WAVE_DELAY).timeout
		_spawn_wave()
	else:
		# Todas las oleadas terminadas
		clear_room()


func clear_room() -> void:
	is_cleared = true
	for child in get_children():
		if child is Area2D and child.has_method("unlock"):
			child.unlock()


func _on_player_entered_door() -> void:
	if is_cleared:
		RunManager.advance_room()
