# enemy_francotirador.gd — Francotirador
# Carga larga, bala rápida y de alto daño.
extends "res://Enemies/enemy.gd"

@export var preferred_distance: float = 400.0
@export var flee_distance:      float = 160.0
@export var aim_duration:       float = 1.4    # carga visible
@export var shoot_cooldown:     float = 3.2    # pausa entre disparos
@export var bullet_damage:      float = 45.0   # alto daño
@export var bullet_speed:       float = 680.0  # bala rápida
@export var bullet_scene: PackedScene

enum State { REPOSITION, AIM, COOLDOWN }
var state:       State   = State.REPOSITION
var state_timer: float   = 0.0
var aim_target:  Vector2 = Vector2.ZERO


func _behavior(delta: float) -> void:
	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float        = to_player.length()
	state_timer -= delta

	match state:
		State.REPOSITION:
			if dist < flee_distance:
				velocity = -to_player.normalized() * speed * 1.2
			elif dist > preferred_distance + 80.0:
				velocity = to_player.normalized() * (speed * 0.6)
			else:
				velocity = Vector2.ZERO
			_update_animation(velocity)
			if state_timer <= 0.0 and dist <= preferred_distance + 100.0:
				_enter_aim(player.global_position)

		State.AIM:
			velocity = Vector2.ZERO
			# Parpadeo rojo intenso durante la carga
			var blink: float = fmod(state_timer, 0.15)
			animated_sprite.modulate = Color(2.0, 0.2, 0.1) if blink < 0.075 else Color.WHITE
			if state_timer <= 0.0:
				_fire()

		State.COOLDOWN:
			animated_sprite.modulate = Color.WHITE
			if dist < flee_distance:
				velocity = -to_player.normalized() * speed
			else:
				velocity = Vector2.ZERO
			_update_animation(velocity)
			if state_timer <= 0.0:
				state       = State.REPOSITION
				state_timer = 0.0


func _enter_aim(target_pos: Vector2) -> void:
	state       = State.AIM
	state_timer = aim_duration
	aim_target  = target_pos
	velocity    = Vector2.ZERO


func _fire() -> void:
	if bullet_scene != null:
		var dir: Vector2 = (aim_target - global_position).normalized()
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = global_position
		bullet.speed           = bullet_speed
		bullet.damage          = bullet_damage
		bullet.modulate        = Color(1.0, 0.3, 0.05)
		if bullet.has_method("setup"):
			bullet.setup(dir, self, "enemy")
	state       = State.COOLDOWN
	state_timer = shoot_cooldown


func _init() -> void:
	mask_id   = "harpia"
	weapon_id = "arco"
