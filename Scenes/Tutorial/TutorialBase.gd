# TutorialBase.gd
# Script base para todas las zonas del tutorial.
# Cada zona hereda este script y solo define _get_dialog_lines() y _on_ready().


extends Node2D

# Cada zona define su siguiente escena
@export var next_scene: String = ""

const C_PORTAL_LOCKED   := Color(0.3, 0.3, 0.3, 0.8)
const C_PORTAL_UNLOCKED := Color(0.45, 0.2, 0.9, 0.9)

var _dialog:         Node  = null
var _zone_complete:  bool  = false
var _player_at_exit: bool  = false
# El estado de silueta persiste entre escenas via RunManager
var _sibu_revealed:  bool  = false


func _ready() -> void:
	_sibu_revealed = RunManager.tutorial_sibu_revealed
	call_deferred("_setup")


func _setup() -> void:
	_lock_player_movement(true)
	
	MapBorder.build(self, MapBorder.find_floor_tilemap(self))

	# Crear DialogBox
	_dialog = CanvasLayer.new()
	_dialog.set_script(load("res://Scenes/DialogBox.gd"))
	add_child(_dialog)

	if _sibu_revealed:
		_dialog.reveal_sibu()

	# Conectar portal de salida
	var exit := get_node_or_null("ExitTrigger")
	if exit:
		exit.body_entered.connect(_on_exit_entered)
		exit.body_exited.connect(_on_exit_exited)
		_set_portal_locked(true)

	_set_gun_enabled(false)

	# Iniciar diálogo de entrada si lo hay
	var lines := _get_intro_lines()
	if not lines.is_empty():
		_dialog.show_lines(lines, _on_intro_finished_wrapper)
	else:
		_on_intro_finished_wrapper()


# ── Override en subclases ─────────────────────────────────────────────────

## Diálogo que aparece al entrar a la zona. Vacío = sin diálogo de entrada.
func _get_intro_lines() -> Array:
	return []


## Llamado cuando termina el diálogo de entrada (o inmediatamente si no hay).
## Aquí la subclase hace su setup (conectar enemigos, habilitar gun, etc.)
func _on_intro_finished() -> void:
	pass


## Llamado cuando la zona se completa (todos los objetivos cumplidos).
## La subclase puede mostrar un diálogo de cierre antes de llamar _unlock_exit().
func _on_zone_completed() -> void:
	_unlock_exit()


# ── Sistema de portal ─────────────────────────────────────────────────────

func _unlock_exit() -> void:
	_zone_complete = true
	_set_portal_locked(false)
	# Si el jugador ya está en el trigger, avanzar directo
	if _player_at_exit:
		_go_to_next()


func _set_portal_locked(locked: bool) -> void:
	var exit := get_node_or_null("ExitTrigger")
	if exit == null:
		return
	var rect := exit.get_node_or_null("ColorRect")
	if rect:
		rect.color = C_PORTAL_LOCKED if locked else C_PORTAL_UNLOCKED
	# Mostrar/ocultar label
	var lbl := exit.get_node_or_null("Label")
	if lbl:
		lbl.text    = "..." if locked else "[E] Continuar"
		lbl.modulate = Color(0.5, 0.5, 0.5) if locked else Color(1, 1, 1)


func _on_exit_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_at_exit = true
	if _zone_complete:
		_go_to_next()


func _on_exit_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_at_exit = false


func _go_to_next() -> void:
	if next_scene.is_empty():
		push_warning("TutorialBase: next_scene no está definido en esta zona.")
		return
	call_deferred("_deferred_change_scene")


func _deferred_change_scene() -> void:
	get_tree().change_scene_to_file(next_scene)


# ── Helpers ───────────────────────────────────────────────────────────────

func _set_gun_enabled(enabled: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var gun := players[0].get_node_or_null("Gun")
	if gun:
		gun.process_mode = Node.PROCESS_MODE_INHERIT if enabled \
			else Node.PROCESS_MODE_DISABLED


func _reveal_sibu() -> void:
	_sibu_revealed = true
	RunManager.tutorial_sibu_revealed = true
	_dialog.reveal_sibu()


func _on_intro_finished_wrapper() -> void:
	_lock_player_movement(false)
	_on_intro_finished()


func _lock_player_movement(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	if players[0].has_method("set_movement_locked"):
		players[0].set_movement_locked(locked)
