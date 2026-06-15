# gun.gd — Pistola del jugador con sistema de munición
extends Sprite2D

@export var magazine_size: int   = 5
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

	# R para recarga manual — detectar presión, no hold continuo
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


func _build_reload_bar() -> void:
	var player := get_parent()
	if player == null:
		return
	var bar := ProgressBar.new()
	bar.name            = "ReloadBar"
	bar.min_value       = 0.0
	bar.max_value       = 1.0
	bar.value           = 0.0
	bar.size            = Vector2(36, 5)
	bar.position        = Vector2(-18, -48)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.1)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bar.add_theme_stylebox_override("background", bg)
	bar.hide()
	player.add_child(bar)
	_reload_bar = bar


func _update_reload_bar(progress: float) -> void:
	if is_instance_valid(_reload_bar):
		_reload_bar.value = progress


func _play_shot_sound() -> void:
	if shot_audio_player and shot_audio_player.has_method("play"):
		shot_audio_player.call("play")


func get_ammo_info() -> Dictionary:
	return { "current": _current_ammo, "max": magazine_size, "reloading": _reloading }
