# enemy_francotirador.gd — Francotirador
# Sin escudo cerca: carga larga, bala rápida y de alto daño, como siempre.
# Protegido por un escudo: abandona la precisión y hace fuego de supresión —
# se asoma alternando a los costados del escudo y tira ráfagas de 3-5 balas
# en cono, para mantener al jugador alejado en vez de buscar un tiro limpio.
extends "res://Enemies/enemy.gd"

@export var preferred_distance: float = 400.0
@export var flee_distance:      float = 160.0
@export var aim_duration:       float = 1.4
@export var shoot_cooldown:     float = 3.2
@export var bullet_damage:      float = 45.0
@export var bullet_speed:       float = 680.0
@export var bullet_scene: PackedScene

# Fuego de supresión — solo mientras is_shielded() es true
@export var suppress_burst_min:        int   = 3
@export var suppress_burst_max:        int   = 5
@export var suppress_bullet_interval:  float = 0.08
@export var suppress_spread_deg:       float = 18.0
@export var suppress_cooldown:         float = 1.1
@export var suppress_bullet_speed:     float = 520.0
@export var suppress_damage_factor:    float = 0.35   # cada bala de la ráfaga pega esta fracción del daño cargado
@export var suppress_peek_offset:      float = 50.0   # cuánto se corre al costado del escudo para asomarse

enum State { REPOSITION, AIM, COOLDOWN, SUPPRESS_BURST, SUPPRESS_COOLDOWN }
var state:       State   = State.REPOSITION
var state_timer: float   = 0.0
var aim_target:  Vector2 = Vector2.ZERO

var _suppress_remaining: int   = 0
var _suppress_timer:     float = 0.0
var _peek_side:          float = 1.0   # alterna 1.0 / -1.0 entre ráfagas


func _behavior(delta: float) -> void:
	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float        = to_player.length()
	state_timer -= delta

	# Una ráfaga de supresión ya empezada se termina aunque el escudo se
	# aleje a mitad de camino — recién en el próximo ciclo (REPOSITION o
	# COOLDOWN) se re-evalúa si sigue protegido o vuelve al modo preciso.
	var already_suppressing: bool = state == State.SUPPRESS_BURST or state == State.SUPPRESS_COOLDOWN
	if already_suppressing or (is_shielded() and (state == State.REPOSITION or state == State.COOLDOWN)):
		_behavior_suppress(delta, player, to_player)
		return

	match state:
		State.REPOSITION:
			if dist < flee_distance and not is_shielded():
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
			var blink: float = fmod(state_timer, 0.15)
			animated_sprite.modulate = Color(2.0, 0.2, 0.1) if blink < 0.075 else Color.WHITE
			if state_timer <= 0.0:
				_fire()

		State.COOLDOWN:
			animated_sprite.modulate = Color.WHITE
			if dist < flee_distance and not is_shielded():
				velocity = -to_player.normalized() * speed
			else:
				velocity = Vector2.ZERO
			_update_animation(velocity)
			if state_timer <= 0.0:
				state       = State.REPOSITION
				state_timer = 0.0


# ── Fuego de supresión (protegido por un escudo) ────────────────────────
func _behavior_suppress(delta: float, player: Node2D, to_player: Vector2) -> void:
	if not is_instance_valid(shielding_ally):
		# El escudo que lo protegía ya no existe — volver al modo normal
		state       = State.REPOSITION
		state_timer = 0.0
		return

	# Posición objetivo: a un costado del escudo (perpendicular a la línea
	# escudo→jugador), alternando de lado entre ráfagas.
	var ally_to_player: Vector2 = (player.global_position - shielding_ally.global_position).normalized()
	var perp: Vector2 = Vector2(-ally_to_player.y, ally_to_player.x)
	var peek_pos: Vector2 = shielding_ally.global_position + perp * suppress_peek_offset * _peek_side

	var to_peek: Vector2 = peek_pos - global_position
	velocity = to_peek.normalized() * speed if to_peek.length() > 12.0 else Vector2.ZERO
	_update_animation(velocity)

	match state:
		State.REPOSITION, State.COOLDOWN, State.SUPPRESS_COOLDOWN:
			if state_timer <= 0.0:
				_enter_suppress_burst()

		State.SUPPRESS_BURST:
			_suppress_timer -= delta
			if _suppress_timer <= 0.0 and _suppress_remaining > 0:
				_fire_suppress_bullet(to_player.normalized())
				_suppress_remaining -= 1
				_suppress_timer = suppress_bullet_interval
			if _suppress_remaining <= 0:
				state       = State.SUPPRESS_COOLDOWN
				state_timer = suppress_cooldown
				_peek_side *= -1.0   # la próxima ráfaga, asomarse del otro lado


func _enter_suppress_burst() -> void:
	state              = State.SUPPRESS_BURST
	_suppress_remaining = randi_range(suppress_burst_min, suppress_burst_max)
	_suppress_timer     = 0.0


func _fire_suppress_bullet(base_direction: Vector2) -> void:
	if bullet_scene == null:
		return
	var angle_offset: float = randf_range(-suppress_spread_deg * 0.5, suppress_spread_deg * 0.5)
	var dir: Vector2 = base_direction.rotated(deg_to_rad(angle_offset))
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.speed    = suppress_bullet_speed
	bullet.damage   = bullet_damage * suppress_damage_factor
	bullet.modulate = Color(1.0, 0.55, 0.15)   # naranja — distingue de la flecha cargada (roja)
	if bullet.has_method("setup"):
		bullet.setup(dir, self, "enemy")


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
		bullet.damage           = bullet_damage
		bullet.modulate         = Color(1.0, 0.3, 0.05)
		if bullet.has_method("setup"):
			bullet.setup(dir, self, "enemy")
	state       = State.COOLDOWN
	state_timer = shoot_cooldown


func _init() -> void:
	mask_id   = "harpia"
	weapon_id = "arco"
