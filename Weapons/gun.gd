# gun.gd — Pistola del jugador con sistema de munición
extends Sprite2D

@export var magazine_size: int   = 7
@export var reload_time:   float = 1.5
@export var bullet_scene:  PackedScene
@export var bullet_damage: float = 20.0
@export var bullet_speed:  float = 420.0

@onready var marker_2d:         Marker2D = $Marker2D
@onready var shot_audio_player: Node     = get_node_or_null("Shoot_sound")

var _current_ammo:    int   = 0
var _reloading:       bool  = false
var _reload_progress: float = 0.0
var _reload_key_held: bool  = false
var _reload_bar:      Node  = null

signal ammo_changed(current: int, max_ammo: int)


func _ready() -> void:
	_current_ammo = magazine_size
	call_deferred("_build_reload_bar")
	emit_signal("ammo_changed", _current_ammo, magazine_size)


func _process(delta: float) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return

	var aim_direction := get_global_mouse_position() - global_position
	if aim_direction != Vector2.ZERO:
		look_at(global_position + aim_direction)
		flip_v = aim_direction.x < 0.0

	if _reloading:
		_reload_progress += delta / reload_time
		_update_reload_bar(_reload_progress)
		if _reload_progress >= 1.0:
			_finish_reload()
		return

	if Input.is_key_pressed(KEY_R):
		if not _reload_key_held and not _reloading and _current_ammo < magazine_size:
			_start_reload()
		_reload_key_held = true
	else:
		_reload_key_held = false


func shoot() -> void:
	if _reloading or bullet_scene == null:
		return
	if _current_ammo <= 0:
		_start_reload()
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var aim_direction := Vector2.RIGHT.rotated(global_rotation)
	if aim_direction == Vector2.ZERO:
		return

	var shooter    := get_parent() as PhysicsBody2D
	var new_bullet := bullet_scene.instantiate()
	current_scene.add_child(new_bullet)
	new_bullet.global_position = marker_2d.global_position
	new_bullet.speed           = bullet_speed
	new_bullet.damage          = bullet_damage

	if new_bullet.has_method("setup"):
		new_bullet.setup(aim_direction, shooter, "player")

	if RunManager.has_active_relic("flecha_awa"):
		var relic: Dictionary = MuseumData.get_relic("flecha_awa")
		new_bullet.damage *= (1.0 + float(relic.get("bonus_value", 0.0)))

	_play_shot_sound()
	_current_ammo -= 1
	emit_signal("ammo_changed", _current_ammo, magazine_size)

	if _current_ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if _reloading or _current_ammo == magazine_size:
		return
	_reloading       = true
	_reload_progress = 0.0
	if is_instance_valid(_reload_bar):
		_reload_bar.show()


func _finish_reload() -> void:
	_reloading       = false
	_reload_progress = 0.0
	_current_ammo    = magazine_size
	if is_instance_valid(_reload_bar):
		_reload_bar.hide()
	emit_signal("ammo_changed", _current_ammo, magazine_size)


func _cancel_reload() -> void:
	_reloading       = false
	_reload_progress = 0.0
	if is_instance_valid(_reload_bar):
		_reload_bar.hide()


func _build_reload_bar() -> void:
	var player := get_parent()
	if player == null:
		return

	# Usar Node2D + ColorRect en vez de ProgressBar para evitar problemas de layout
	var container := Node2D.new()
	container.name     = "ReloadBar"
	# Con scale x5 del player, -8 local = -40px en pantalla, justo encima del sprite
	container.position = Vector2(-4, -4)

	var bg := ColorRect.new()
	bg.color    = Color(0.15, 0.15, 0.15, 0.85)
	bg.size     = Vector2(8, 1)
	bg.position = Vector2.ZERO
	container.add_child(bg)

	var fill := ColorRect.new()
	fill.name     = "Fill"
	fill.color    = Color(1.0, 0.85, 0.1)
	fill.size     = Vector2(0, 1)
	fill.position = Vector2.ZERO
	container.add_child(fill)

	container.hide()
	player.add_child(container)
	_reload_bar = container


func _update_reload_bar(progress: float) -> void:
	if not is_instance_valid(_reload_bar):
		return
	var fill: ColorRect = _reload_bar.get_node_or_null("Fill")
	if fill:
		fill.size.x = 8.0 * clampf(progress, 0.0, 1.0)


func _play_shot_sound() -> void:
	if shot_audio_player and shot_audio_player.has_method("play"):
		shot_audio_player.call("play")


func get_ammo_info() -> Dictionary:
	return { "current": _current_ammo, "max": magazine_size, "reloading": _reloading }
