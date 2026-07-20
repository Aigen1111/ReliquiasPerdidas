# RunManager.gd — Autoload singleton

extends Node

signal gold_changed(new_amount: int)
signal relic_unlocked(relic_id: String)
signal area_unlocked(area_id: String)
signal run_started(area_id: String)
signal run_ended(victory: bool, gold_earned: int)
signal relic_activated(relic_id: String)   # se emite CADA vez que se activa en una run (aunque ya esté desbloqueada)

const LOBBY_SCENE := "res://Scenes/Lobby.tscn"
const BOSS_SCENES := {
	"bribri": "res://Rooms/Bribri/BossRoom_Bribri.tscn",
}

const ROOMS_PER_ZONE := 4

const AREA_DATA := {
	"bribri": {
		"display_name": "Mundo Bribri",
		"zones": [
			{
				"display_name": "Jungla",
				"pool": [
					{ "scene": "res://Rooms/Bribri/Z1_Combat_A.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z1_Combat_B.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z1_Combat_C.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z1_Rest_A.tscn",    "type": "rest"    },
					{ "scene": "res://Rooms/Bribri/Z1_Museum_A.tscn",  "type": "museum"  },
					{ "scene": "res://Rooms/Bribri/Z1_Reward_A.tscn",  "type": "reward"  },
					{ "scene": "res://Rooms/Bribri/Z1_Combat_D.tscn",  "type": "combat"  },
				]
			},
			{
				"display_name": "Ruinas",
				"pool": [
					{ "scene": "res://Rooms/Bribri/Z2_Combat_A.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z2_Combat_B.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z2_Combat_C.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z2_Rest_A.tscn",    "type": "rest"    },
					{ "scene": "res://Rooms/Bribri/Z2_Museum_A.tscn",  "type": "museum"  },
					{ "scene": "res://Rooms/Bribri/Z2_Reward_A.tscn",  "type": "reward"  },
					{ "scene": "res://Rooms/Bribri/Z2_Combat_D.tscn",  "type": "combat"  },
				]
			},
			{
				"display_name": "Zona Corrupta",
				"pool": [
					{ "scene": "res://Rooms/Bribri/Z3_Combat_A.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z3_Combat_B.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z3_Combat_C.tscn",  "type": "combat"  },
					{ "scene": "res://Rooms/Bribri/Z3_Rest_A.tscn",    "type": "rest"    },
					{ "scene": "res://Rooms/Bribri/Z3_Museum_A.tscn",  "type": "museum"  },
					{ "scene": "res://Rooms/Bribri/Z3_Reward_A.tscn",  "type": "reward"  },
					{ "scene": "res://Rooms/Bribri/Z3_Combat_D.tscn",  "type": "combat"  },
				]
			},
		]
	},
}

const AREA_UNLOCK_ORDER := ["bribri"]

# ── Estado persistente ────────────────────────────────────────────────────
var gold: int = 0
var unlocked_areas: Array = ["bribri"]
var unlocked_relics: Array = []
var active_relics: Array = []
var last_run_victory: bool = false
var last_run_floor: int = 0
var last_run_gold_earned: int = 0
var tutorial_done: bool = false
var tutorial_sibu_revealed: bool = false

# ── Estado del run activo ─────────────────────────────────────────────────
var is_in_run: bool = false
var current_area_id: String = ""
var current_zone_index: int = 0
var current_room_index: int = 0
var run_sequence: Array = []
var room_type_history: Array = []  # tipos de sala visitados en orden
var gold_this_run: int = 0
var player_current_health: float = 100.0
var player_max_health: float = 100.0
var player_max_health_before_relic: float = 100.0  # vida máxima ANTES de aplicar reliquias en sala
var relics_found_this_run: Array = []

# ── API run ───────────────────────────────────────────────────────────────

func start_run(area_id: String = "bribri") -> void:
	assert(area_id in AREA_DATA, "RunManager: área desconocida '%s'" % area_id)
	assert(area_id in unlocked_areas, "RunManager: área bloqueada '%s'" % area_id)
	is_in_run = true
	current_area_id = area_id
	current_zone_index = 0
	current_room_index = 0
	gold_this_run = 0
	# Reliquias activas en el run = solo las equipadas desde el Lobby.
	# Se limpian aquí para que cada run empiece desde cero
	# (las del Lobby se re-añaden vía set_active_relics antes de start_run).
	active_relics = active_relics.filter(func(id): return id in unlocked_relics and id not in relics_found_this_run)
	relics_found_this_run = []
	player_current_health = 100.0   # se recalcula en player._ready() tras aplicar reliquias
	player_max_health = 100.0
	player_max_health_before_relic = 100.0
	room_type_history = []
	run_sequence = _build_run_sequence(area_id)
	emit_signal("run_started", area_id)
	SaveManager.save_slot(SaveManager.SLOT_AUTOSAVE_START)
	_load_current_room()


func advance_room() -> void:
	assert(is_in_run, "RunManager.advance_room llamado fuera de un run")
	current_room_index += 1
	current_zone_index = _zone_for_index(current_room_index)
	if current_room_index < run_sequence.size():
		_load_current_room()

## Llamado por portales: carga la escena específica que eligió el jugador
## y la registra en la secuencia para que el piso count sea correcto.
func choose_room(scene_path: String) -> void:
	assert(is_in_run, "RunManager.choose_room llamado fuera de un run")
	if current_room_index < run_sequence.size():
		room_type_history.append(_scene_type(run_sequence[current_room_index]))
	current_room_index += 1
	current_zone_index = _zone_for_index(current_room_index)
	if current_room_index < run_sequence.size():
		run_sequence[current_room_index] = scene_path
	get_tree().change_scene_to_file(scene_path)


## Cuántas salas seguidas sin combate lleva el jugador
func non_combat_streak() -> int:
	var streak: int = 0
	for i in range(room_type_history.size() - 1, -1, -1):
		if room_type_history[i] == "combat":
			break
		streak += 1
	return streak


func _scene_type(scene_path: String) -> String:
	if "Combat" in scene_path: return "combat"
	if "Rest"   in scene_path: return "rest"
	if "Reward" in scene_path: return "reward"
	if "Museum" in scene_path: return "museum"
	if "Boss"   in scene_path: return "boss"
	return "combat"


func player_died() -> void:
	if not is_in_run:
		return
	var kept := gold_this_run / 2
	_add_gold(kept)
	last_run_victory = false
	last_run_floor = current_room_index + 1
	last_run_gold_earned = kept
	gold_this_run = 0
	_end_run(false)


func complete_run() -> void:
	_add_gold(gold_this_run)
	last_run_victory = true
	last_run_floor = run_sequence.size()
	last_run_gold_earned = gold_this_run
	gold_this_run = 0
	_try_unlock_next_area()
	_end_run(true)


## Llamado por RunResultScreen cuando el jugador presiona "Continuar"
func go_to_lobby() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


# ── API oro ───────────────────────────────────────────────────────────────

func add_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold_this_run += amount
	emit_signal("gold_changed", get_display_gold())


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true


func get_display_gold() -> int:
	return gold + gold_this_run


# ── API reliquias ─────────────────────────────────────────────────────────

func unlock_relic(relic_id: String) -> void:
	if relic_id not in unlocked_relics:
		unlocked_relics.append(relic_id)
		relics_found_this_run.append(relic_id)
		emit_signal("relic_unlocked", relic_id)
	# Si estamos en un run, activar la reliquia automáticamente
	if is_in_run and relic_id not in active_relics:
		# Guardar vida máxima ANTES de aplicar la nueva reliquia
		# para que player._ready() pueda escalar la vida actual correctamente
		player_max_health_before_relic = player_max_health
		active_relics.append(relic_id)
		emit_signal("relic_activated", relic_id)


func set_active_relics(relic_ids: Array) -> void:
	active_relics = relic_ids.duplicate()


func has_active_relic(relic_id: String) -> bool:
	return relic_id in active_relics


# ── Construcción de secuencia ─────────────────────────────────────────────

func _build_run_sequence(area_id: String) -> Array:
	var sequence: Array = []
	for zone_data: Dictionary in AREA_DATA[area_id]["zones"]:
		for entry: Dictionary in _pick_rooms_from_pool(zone_data["pool"]):
			sequence.append(entry["scene"])
	if BOSS_SCENES.has(area_id):
		sequence.append(BOSS_SCENES[area_id])
	return sequence


func _pick_rooms_from_pool(pool: Array) -> Array:
	# Reglas:
	# 1. Nunca dos non-combat seguidos (rest, reward, museum siempre separados por combat)
	# 2. Mínimo 2 combates por zona
	# 3. Exactamente ROOMS_PER_ZONE salas
	var shuffled := pool.duplicate()
	shuffled.shuffle()

	# Separar por tipo
	var combats:  Array = shuffled.filter(func(e): return e["type"] == "combat")
	var specials: Array = shuffled.filter(func(e): return e["type"] != "combat")
	specials.shuffle()

	# Construir secuencia intercalada: combat, special, combat, special...
	# Siempre empieza con combat y nunca pone dos specials seguidos
	var selected: Array = []
	var si: int = 0  # índice en specials
	var ci: int = 0  # índice en combats
	var last_was_special: bool = false

	while selected.size() < ROOMS_PER_ZONE:
		if last_was_special or si >= specials.size():
			# Forzar combat
			if ci < combats.size():
				selected.append(combats[ci])
				ci += 1
				last_was_special = false
			elif si < specials.size():
				# No quedan combats, añadir special (último recurso)
				selected.append(specials[si])
				si += 1
				last_was_special = true
			else:
				break
		else:
			# Podemos poner combat o special — alternar para variedad
			# Preferir special si llevamos 2+ combats seguidos, sino combat
			var recent_combats: int = 0
			for k in range(selected.size() - 1, max(selected.size() - 3, -1), -1):
				if selected[k]["type"] == "combat":
					recent_combats += 1
				else:
					break
			if recent_combats >= 1 and si < specials.size():
				selected.append(specials[si])
				si += 1
				last_was_special = true
			elif ci < combats.size():
				selected.append(combats[ci])
				ci += 1
				last_was_special = false
			elif si < specials.size():
				selected.append(specials[si])
				si += 1
				last_was_special = true
			else:
				break

	# Garantizar mínimo 2 combates
	var combat_count: int = selected.filter(func(e): return e["type"] == "combat").size()
	if combat_count < 2 and combats.size() >= 2:
		# Reemplazar últimas specials por combats hasta tener 2
		for i in range(selected.size() - 1, -1, -1):
			if combat_count >= 2:
				break
			if selected[i]["type"] != "combat" and ci < combats.size():
				selected[i] = combats[ci]
				ci += 1
				combat_count += 1

	return selected


func _zone_for_index(room_index: int) -> int:
	return clamp(room_index / ROOMS_PER_ZONE, 0, 2)


# ── Internos ──────────────────────────────────────────────────────────────

func _load_current_room() -> void:
	get_tree().change_scene_to_file(run_sequence[current_room_index])


func _end_run(victory: bool) -> void:
	is_in_run = false
	SaveManager.save_slot(SaveManager.SLOT_AUTOSAVE_END)
	# Solo emitir señal — RunResultScreen escucha y muestra la pantalla.
	# El cambio a Lobby lo hace go_to_lobby() cuando el jugador presiona Continuar.
	emit_signal("run_ended", victory, last_run_gold_earned)


func _add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	emit_signal("gold_changed", gold)


func _try_unlock_next_area() -> void:
	var idx := AREA_UNLOCK_ORDER.find(current_area_id)
	if idx == -1 or idx + 1 >= AREA_UNLOCK_ORDER.size():
		return
	var next: String = AREA_UNLOCK_ORDER[idx + 1]
	if next not in unlocked_areas:
		unlocked_areas.append(next)
		emit_signal("area_unlocked", next)
