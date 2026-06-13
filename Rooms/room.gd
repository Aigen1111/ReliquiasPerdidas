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


func _ready() -> void:
	_setup_portal_base()

	# Recoger posiciones de placeholders — buscar tanto en hijos directos
	# como en el grupo "Enemy" que estén dentro de esta escena
	for child in get_children():
		if child.is_in_group("Enemy") or (child.get_script() and str(child.get_script().resource_path).contains("enemy")):
			_spawn_positions.append(child.global_position)
			child.queue_free()

	# Fallback: si no encontró hijos Enemy, buscar por nombre (Enemy, Enemy2, etc.)
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

	await get_tree().process_frame
	_show_wave_indicators()


func _calculate_waves() -> Array:
	var cfg: Dictionary = WAVE_CONFIG[_zone]
	var total: int = min(randi_range(cfg["min"], cfg["max"]), _spawn_positions.size())
	var sizes: Array = []
	var assigned: int = 0
	for i in range(cfg["waves"].size()):
		var count: int = total - assigned if i == cfg["waves"].size() - 1 else max(1, int(total * cfg["waves"][i]))
		sizes.append(count)
		assigned += count
	return sizes


func _show_wave_indicators() -> void:
	var start_idx: int = 0
	for i in range(_current_wave):
		start_idx += _wave_sizes[i]

	var count: int = _wave_sizes[_current_wave] if _current_wave < _wave_sizes.size() else 0
	var indicators: Array = []

	for i in range(count):
		var pos_idx: int = start_idx + i
		if pos_idx >= _spawn_positions.size():
			break
		var ind := _build_spawn_indicator(_spawn_positions[pos_idx])
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
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var remaining: int  = max(1, int(ceil(SPAWN_WARN_DURATION - elapsed)))
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
	var start_idx: int = 0
	for i in range(_current_wave):
		start_idx += _wave_sizes[i]
	for i in range(_wave_sizes[_current_wave]):
		var pos_idx: int = start_idx + i
		if pos_idx >= _spawn_positions.size():
			break
		var scene: PackedScene = load(_pool[randi() % _pool.size()])
		if scene == null:
			continue
		var enemy = scene.instantiate()
		add_child(enemy)
		enemy.global_position = _spawn_positions[pos_idx]
		enemy.died.connect(_on_enemy_died)
		enemies_alive += 1
	_current_wave += 1


func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive > 0:
		return
	if _current_wave < _wave_sizes.size():
		await get_tree().create_timer(WAVE_DELAY).timeout
		_show_wave_indicators()
	else:
		_open_portals()
