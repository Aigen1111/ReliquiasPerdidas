# RunManager.gd  (actualizado)
# ─────────────────────────────────────────────────────────────────────────────
# Autoload singleton que gestiona el ciclo completo: Lobby → Run → Lobby.
# Ya registrado en project.godot, no hay que volver a agregarlo.
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# ═══════════════════════════════════════════════════════════════════════════
#  Rutas de escenas — ajustar si cambian los archivos
# ═══════════════════════════════════════════════════════════════════════════
const LOBBY_SCENE:    String = "res://Scenes/Lobby.tscn"
const FIRST_ROOM:     String = "res://Rooms/Room_01.tscn"


# ═══════════════════════════════════════════════════════════════════════════
#  Estado del run actual
# ═══════════════════════════════════════════════════════════════════════════
var is_in_run:   bool  = false
var current_floor: int = 0

## Vida del jugador persistente entre salas (para no resetearse al transicionar)
var player_current_health: float = 100.0
var player_max_health:     float = 100.0


# ═══════════════════════════════════════════════════════════════════════════
#  Estado persistente entre runs (se acumula)
# ═══════════════════════════════════════════════════════════════════════════
## Reliquias/artefactos desbloqueados en el museo
var collected_relics: Array = []

## Datos del último run (para mostrar en el lobby)
var last_run_floor:   int  = 0
var last_run_victory: bool = false


# ═══════════════════════════════════════════════════════════════════════════
#  API pública
# ═══════════════════════════════════════════════════════════════════════════

## Inicia un nuevo run desde el lobby
func start_run() -> void:
	is_in_run = true
	current_floor = 1
	# Resetear la vida del jugador al inicio de cada run
	player_current_health = player_max_health
	get_tree().change_scene_to_file(FIRST_ROOM)


## Llamado por la sala cuando el jugador avanza de piso
## (opcional por ahora, útil cuando haya más salas)
func advance_floor(next_room_path: String) -> void:
	current_floor += 1
	get_tree().change_scene_to_file(next_room_path)


## Llamado por el jugador al morir (desde player.gd)
func player_died() -> void:
	if not is_in_run:
		return
	last_run_floor   = current_floor
	last_run_victory = false
	_end_run()


## Llamado si el jugador completa el run (derrota al jefe)
func complete_run() -> void:
	last_run_floor   = current_floor
	last_run_victory = true
	_end_run()


## Agrega una reliquia al museo (llamar desde MuseumRoom o trigger cultural)
func add_relic(relic_id: String) -> void:
	if relic_id not in collected_relics:
		collected_relics.append(relic_id)


# ═══════════════════════════════════════════════════════════════════════════
#  Interno
# ═══════════════════════════════════════════════════════════════════════════

func _end_run() -> void:
	is_in_run = false
	current_floor = 0
	get_tree().change_scene_to_file(LOBBY_SCENE)
