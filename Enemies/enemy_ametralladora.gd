# enemy_ametralladora.gd — Tirador en ráfagas
# Dispara ráfagas de 3 balas con pausa entre ráfagas. Daño bajo, velocidad media.
extends "res://Enemies/enemy.gd"

@export var preferred_distance: float = 280.0
@export var flee_distance:      float = 130.0
@export var strafe_speed:       float = 90.0
@export var bullet_damage:      float = 6.0    # bajo
@export var bullet_speed:       float = 260.0  # medio-lento
@export var burst_size:         int   = 3      # balas por ráfaga
@export var burst_interval:     float = 0.10   # tiempo entre balas de la ráfaga
@export var burst_cooldown:     float = 1.8    # pausa entre ráfagas
@export var bullet_scene: PackedScene

var _burst_timer:     float = 0.0
var _cooldown_timer:  float = 0.0
var _burst_remaining: int   = 0
var _burst_direction: Vector2 = Vector2.ZERO
var _in_burst:        bool  = false
var _strafe_dir:      float = 1.0
var _strafe_timer:    float = 0.0


func _behavior(delta: float) -> void:
	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float        = to_player.length()

	# Movimiento strafe
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_dir   = 1.0 if randf() > 0.5 else -1.0
		_strafe_timer = randf_range(0.8, 1.8)

	if dist < flee_distance:
		velocity = -to_player.normalized() * speed * 1.3
	elif dist > preferred_distance + 60.0:
		velocity = to_player.normalized() * speed
	else:
		var perp: Vector2 = Vector2(-to_player.normalized().y, to_player.normalized().x)
		velocity = perp * strafe_speed * _strafe_dir

	_update_animation(velocity)

	# Lógica de ráfaga
	if _in_burst:
		_burst_timer -= delta
		if _burst_timer <= 0.0 and _burst_remaining > 0:
			_shoot(_burst_direction)
			_burst_remaining -= 1
			_burst_timer = burst_interval
		if _burst_remaining <= 0:
			_in_burst       = false
			_cooldown_timer = burst_cooldown
	else:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0 and dist < preferred_distance + 150.0:
			_start_burst(to_player.normalized())


func _start_burst(direction: Vector2) -> void:
	_in_burst        = true
	_burst_remaining = burst_size
	_burst_direction = direction
	_burst_timer     = 0.0  # disparar la primera inmediatamente


func _shoot(direction: Vector2) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.speed           = bullet_speed
	bullet.damage          = bullet_damage
	bullet.modulate        = Color(0.2, 1.0, 0.3)
	if bullet.has_method("setup"):
		bullet.setup(direction, self, "enemy")

func _init() -> void:
	mask_id   = "zopilote"
	weapon_id = "cerbatana"
