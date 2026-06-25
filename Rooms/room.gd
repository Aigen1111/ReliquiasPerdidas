# room.gd — Sala de combate con oleadas y spawn indicators
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

var enemies_alive:    int   = 0
var _spawn_positions: Array = []
var _wave_sizes:      Array = []
var _current_wave:    int   = 0
var _zone:            int   = 0
var _pool:            Array = []
# Índice de posición de spawn — se cicla con módulo para reusar posiciones
var _spawn_pos_idx:   int   = 0


func _ready() -> void:
	_setup_portal_base()

	for child in get_children():
		if child.is_in_group("Enemy") or (child.get_script() and str(child.get_script().resource_path).contains("enemy")):
			_spawn_positions.append(child.global_position)
			child.queue_free()

	if _spawn_positions.is_empty():
		for child in get_children():
			if child.name.begins_with("Enemy") and child is Node2D:
				_spawn_positions.append(child.global_position)
				child.queue_free()

	_zone = clamp(RunManager.current_zone_index, 0, WAVE_CONFIG.size() - 1)
	_pool = ENEMY_POOLS[_zone]
	_wave_sizes = _calculate_waves()

	if _spawn_positions.is_empty():
		_open_portals()
		return

	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_show_wave_indicators()


func _calculate_waves() -> Array:
	var cfg: Dictionary = WAVE_CONFIG[_zone]
	# Ya no limitamos por _spawn_positions.size() — las posiciones se reusan con módulo
	var total: int = randi_range(cfg["min"], cfg["max"])
	var sizes: Array = []
	var assigned: int = 0
	for i in range(cfg["waves"].size()):
		var count: int = total - assigned if i == cfg["waves"].size() - 1 \
			else max(1, int(total * cfg["waves"][i]))
		sizes.append(count)
		assigned += count
	return sizes


func _show_wave_indicators() -> void:
	var count: int = _wave_sizes[_current_wave] if _current_wave < _wave_sizes.size() else 0
	var indicators: Array = []

	# Barajar posiciones cada oleada para variar el orden
	var shuffled: Array = _spawn_positions.duplicate()
	shuffled.shuffle()

	for i in range(count):
		var base_pos: Vector2 = shuffled[i % shuffled.size()]
		# Si hay más enemigos que posiciones, agregar offset para no superponerse
		var offset: Vector2 = Vector2.ZERO
		if i >= shuffled.size():
			offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var ind := _build_spawn_indicator(base_pos + offset)
		add_child(ind)
		indicators.append(ind)

	await _animate_indicators(indicators)
	for ind in indicators:
		if is_instance_valid(ind):
			ind.queue_free()
	_spawn_wave()


func _build_spawn_indicator(world_pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.global_position = world_pos
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


func _spawn_wave() -> void:
	if _current_wave >= _wave_sizes.size():
		return
	var count: int = _wave_sizes[_current_wave]

	var shuffled: Array = _spawn_positions.duplicate()
	shuffled.shuffle()

	for i in range(count):
		var base_pos: Vector2 = shuffled[i % shuffled.size()]
		var offset: Vector2 = Vector2.ZERO
		if i >= shuffled.size():
			offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var scene: PackedScene = load(_pool[randi() % _pool.size()])
		if scene == null:
			continue
		var enemy = scene.instantiate()
		add_child(enemy)
		enemy.global_position = base_pos + offset
		enemy.died.connect(_on_enemy_died)
		enemies_alive += 1
	_current_wave += 1


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
