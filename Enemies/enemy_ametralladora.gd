# enemy_ametralladora.gd — Tirador Rápido (ranged)
# FIX: setup() ahora pasa team = "enemy" para que sus balas solo dañen al jugador.
extends "res://Enemies/enemy.gd"

@export var preferred_distance: float = 280.0
@export var flee_distance:      float = 130.0
@export var strafe_speed:       float = 90.0
@export var shoot_cooldown:     float = 0.45
@export var bullet_damage:      float = 8.0
@export var bullet_speed:       float = 320.0
@export var bullet_scene: PackedScene

var shoot_timer:        float = 0.0
var strafe_dir:         float = 1.0
var strafe_change_timer: float = 0.0


func _behavior(delta: float) -> void:
	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	strafe_change_timer -= delta
	if strafe_change_timer <= 0.0:
		strafe_dir = 1.0 if randf() > 0.5 else -1.0
		strafe_change_timer = randf_range(0.8, 1.8)

	if dist < flee_distance:
		velocity = -to_player.normalized() * speed * 1.3
	elif dist > preferred_distance + 60.0:
		velocity = to_player.normalized() * speed
	else:
		var perpendicular: Vector2 = Vector2(-to_player.normalized().y, to_player.normalized().x)
		velocity = perpendicular * strafe_speed * strafe_dir

	_update_animation(velocity)

	shoot_timer -= delta
	if shoot_timer <= 0.0 and dist < preferred_distance + 150.0:
		_shoot(to_player.normalized())
		shoot_timer = shoot_cooldown


func _shoot(direction: Vector2) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	bullet.modulate = Color(0.2, 1.0, 0.3)
	# FIX: pasar team "enemy" para que solo dañe al jugador
	if bullet.has_method("setup"):
		bullet.setup(direction, self, "enemy")
