# RunManager.gd — Autoload singleton
# CAMBIOS: _end_run ahora NO cambia de escena automáticamente.
# Emite run_ended y espera a que RunResultScreen llame a go_to_lobby().
# Esto permite que la pantalla de resultado se muestre antes del cambio.
extends Node

signal gold_changed(new_amount: int)
signal relic_unlocked(relic_id: String)
signal area_unlocked(area_id: String)
signal run_started(area_id: String)
signal run_ended(victory: bool, gold_earned: int)

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

# ── Estado del run activo ─────────────────────────────────────────────────
var is_in_run: bool = false
var current_area_id: String = ""
var current_zone_index: int = 0
var current_room_index: int = 0
var run_sequence: Array = []
var gold_this_run: int = 0
var player_current_health: float = 100.0
var player_max_health: float = 100.0
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
	player_current_health = player_max_health
	relics_found_this_run = []
	run_sequence = _build_run_sequence(area_id)
	emit_signal("run_started", area_id)
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
	current_room_index += 1
	current_zone_index = _zone_for_index(current_room_index)
	if current_room_index < run_sequence.size():
		run_sequence[current_room_index] = scene_path
	get_tree().change_scene_to_file(scene_path)


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
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var selected: Array = []
	var last_type := ""
	var combat_count := 0
	for entry: Dictionary in shuffled:
		if selected.size() >= ROOMS_PER_ZONE:
			break
		var t: String = entry["type"]
		if t == last_type and t in ["museum", "rest"]:
			continue
		selected.append(entry)
		last_type = t
		if t == "combat":
			combat_count += 1
	if selected.size() < ROOMS_PER_ZONE:
		for entry: Dictionary in shuffled:
			if selected.size() >= ROOMS_PER_ZONE:
				break
			if entry not in selected:
				selected.append(entry)
	if combat_count < 2:
		for i in range(selected.size() - 1, -1, -1):
			if combat_count >= 2:
				break
			if selected[i]["type"] != "combat":
				for entry: Dictionary in shuffled:
					if entry["type"] == "combat" and entry not in selected:
						selected[i] = entry
						combat_count += 1
						break
	return selected


func _zone_for_index(room_index: int) -> int:
	return clamp(room_index / ROOMS_PER_ZONE, 0, 2)


# ── Internos ──────────────────────────────────────────────────────────────

func _load_current_room() -> void:
	get_tree().change_scene_to_file(run_sequence[current_room_index])


func _end_run(victory: bool) -> void:
	is_in_run = false
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
