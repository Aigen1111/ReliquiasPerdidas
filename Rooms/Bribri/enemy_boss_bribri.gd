# enemy_boss_bribri.gd — Guardián Bribri (Boss)
#
# FASES:
#   Fase 1 (100% → 50% vida): CHASE + FAN_SHOT + CHARGE
#   Fase 2 (< 50% vida): todo lo anterior más rápido + SUMMON (invoca Lanceros)
#     La transición a Fase 2 tiene una pausa de 1.5 s con flash blanco.

extends "res://Enemies/enemy.gd"

# ── Exportados/Variables 
@export var bullet_scene:   PackedScene
@export var lancero_scene:  PackedScene

# Stats base (sobreescriben los del padre)
@export var phase2_speed_multiplier: float = 1.45

# Carga
@export var charge_speed:    float = 480.0
@export var charge_windup:   float = 0.55
@export var charge_duration: float = 0.38
@export var charge_cooldown: float = 3.5
@export var charge_range:    float = 340.0
@export var charge_damage:   float = 32.0
@export var contact_damage:  float = 14.0

# Abanico
@export var fan_cooldown:    float = 2.8   # tiempo entre abanicos de balas
@export var fan_bullets_p1:  int   = 5     # balas en Fase 1
@export var fan_bullets_p2:  int   = 7     # balas en Fase 2
@export var fan_spread_deg:  float = 60.0  # ángulo total del abanico
@export var fan_speed:       float = 300.0
@export var fan_damage:      float = 18.0

# Invocación (Fase 2)
@export var summon_cooldown: float = 8.0
@export var summon_offset:   float = 120.0  # distancia lateral del spawn

# ── Constantes
const PHASE2_THRESHOLD: float = 0.5   # % de vida para pasar a Fase 2
const CONTACT_INTERVAL: float = 0.55  # cooldown entre daños de contacto
const PHASE_FLASH_TIME: float = 1.5   # pausa dramática al entrar Fase 2

# ── Estado interno
enum State { CHASE, WINDUP, CHARGE, COOLDOWN, FAN_SHOT, SUMMON, PHASE_TRANSITION }

var state:            State = State.CHASE
var state_timer:      float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var _contact_cooldown: float = 0.0
var _fan_timer:        float = 1.0   # primer abanico al segundo de entrar
var _summon_timer:     float = 4.0   # primera invocación a los 4 s
var _phase:            int   = 1
var _phase2_entered:   bool  = false


# ── Setup 
func _ready() -> void:
	super._ready()
	max_health = 350.0
	speed      = 75.0
	gold_drop  = 40
	current_health = max_health
	health_bar.update(current_health, max_health)


# ── Comportamiento principal 
func _behavior(delta: float) -> void:
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)

	# Comprobar transición de fase (solo una vez)
	if not _phase2_entered and current_health / max_health <= PHASE2_THRESHOLD:
		_phase2_entered = true
		_enter_phase_transition()
		return

	# No actualizar timers secundarios durante transición
	if state == State.PHASE_TRANSITION:
		return

	state_timer -= delta

	var player: Node2D = _get_player()
	if player == null:
		velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float        = to_player.length()

	# Decrementar timers de habilidades pasivas
	_fan_timer    -= delta
	if _phase == 2:
		_summon_timer -= delta

	match state:
		State.CHASE:
			velocity = to_player.normalized() * speed
			_update_animation(velocity)

			# Daño de contacto en chase
			if dist < 36.0:
				_try_contact_damage(player, contact_damage)

			# Prioridad: abanico > invocación > carga
			if _fan_timer <= 0.0:
				_enter_fan_shot()
			elif _phase == 2 and _summon_timer <= 0.0:
				_enter_summon()
			elif dist < charge_range and state_timer <= 0.0:
				_enter_windup()

		State.WINDUP:
			velocity = Vector2.ZERO
			# Flash naranja parpadeante (igual que Lancero)
			if fmod(state_timer, 0.1) < 0.05:
				animated_sprite.modulate = Color(1.5, 0.55, 0.05)
			else:
				animated_sprite.modulate = Color.WHITE
			if state_timer <= 0.0:
				_enter_charge((player.global_position - global_position).normalized())

		State.CHARGE:
			velocity = charge_direction * charge_speed
			if dist < 44.0:
				_try_contact_damage(player, charge_damage)
			if state_timer <= 0.0:
				_enter_cooldown()

		State.COOLDOWN:
			animated_sprite.modulate = Color.WHITE
			# Huir levemente tras la carga
			var flee_speed: float = speed * 0.7
			velocity = Vector2.ZERO if dist > 210.0 else -to_player.normalized() * flee_speed
			_update_animation(velocity)
			if state_timer <= 0.0:
				state       = State.CHASE
				state_timer = 0.0

		State.FAN_SHOT:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_fire_fan(to_player.normalized())

		State.SUMMON:
			velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_do_summon()


# ── Entradas de estado
func _enter_windup() -> void:
	state       = State.WINDUP
	state_timer = charge_windup
	velocity    = Vector2.ZERO


func _enter_charge(direction: Vector2) -> void:
	state            = State.CHARGE
	state_timer      = charge_duration
	charge_direction = direction
	animated_sprite.modulate = Color.WHITE


func _enter_cooldown() -> void:
	state       = State.COOLDOWN
	state_timer = charge_cooldown


func _enter_fan_shot() -> void:
	state       = State.FAN_SHOT
	state_timer = 0.5   # breve pausa de preparación antes del abanico
	_fan_timer  = fan_cooldown
	# Flash azulado como telegrafía del abanico
	animated_sprite.modulate = Color(0.4, 0.8, 2.0)


func _enter_summon() -> void:
	state         = State.SUMMON
	state_timer   = 0.6   # pausa antes de invocar
	_summon_timer = summon_cooldown
	animated_sprite.modulate = Color(1.8, 0.2, 1.8)   # flash morado


func _enter_phase_transition() -> void:
	state = State.PHASE_TRANSITION
	velocity = Vector2.ZERO
	_do_phase_transition()


# ── Ataques
func _fire_fan(base_direction: Vector2) -> void:
	animated_sprite.modulate = Color.WHITE
	if bullet_scene == null:
		state = State.CHASE
		return

	var bullet_count: int = fan_bullets_p2 if _phase == 2 else fan_bullets_p1
	var half_spread:  float = fan_spread_deg / 2.0

	for i in range(bullet_count):
		var t: float = float(i) / float(bullet_count - 1) if bullet_count > 1 else 0.0
		var angle_deg: float = lerp(-half_spread, half_spread, t)
		var dir: Vector2 = base_direction.rotated(deg_to_rad(angle_deg))

		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = global_position
		bullet.speed  = fan_speed
		bullet.damage = fan_damage
		bullet.modulate = Color(0.3, 1.8, 0.5)   # verde brillante
		if bullet.has_method("setup"):
			bullet.setup(dir, self, "enemy")

	state = State.CHASE


func _do_summon() -> void:
	animated_sprite.modulate = Color.WHITE
	if lancero_scene == null:
		state = State.CHASE
		return

	var player: Node2D = _get_player()
	var ref_dir: Vector2 = Vector2.RIGHT if player == null \
		else (player.global_position - global_position).normalized()

	var perp: Vector2 = Vector2(-ref_dir.y, ref_dir.x)
	var offsets: Array = [perp * summon_offset, -perp * summon_offset]

	for offset in offsets:
		var lancero = lancero_scene.instantiate()
		get_parent().add_child(lancero)
		lancero.global_position = global_position + offset
		# Conectar died al contador de enemigos de room.gd si existe
		var room = get_parent()
		if room.has_method("_on_enemy_died"):
			lancero.died.connect(room._on_enemy_died)

	state = State.CHASE


# ── Transición a Fase 2
func _do_phase_transition() -> void:
	_phase = 2
	speed *= phase2_speed_multiplier
	charge_speed  *= 1.2
	fan_cooldown  *= 0.75   # abanico más frecuente

	# Flash blanco prolongado + brevísima invulnerabilidad visual
	var flash_colors: Array = [
		Color(2.0, 2.0, 2.0),   # blanco
		Color(1.6, 0.3, 0.1),   # naranja
		Color(2.0, 2.0, 2.0),
		Color(1.6, 0.3, 0.1),
		Color(2.0, 2.0, 2.0),
	]
	for c in flash_colors:
		animated_sprite.modulate = c
		if not is_instance_valid(self) or get_tree() == null:
			return
		await get_tree().create_timer(PHASE_FLASH_TIME / flash_colors.size()).timeout
		if not is_instance_valid(self) or get_tree() == null:
			return

	animated_sprite.modulate = Color.WHITE
	state       = State.CHASE
	state_timer = 0.0
	_fan_timer  = 1.0
	# Summon inmediato al entrar en Fase 2
	_summon_timer = 2.0


# ── Helpers
func _try_contact_damage(player: Node2D, amount: float) -> void:
	if _contact_cooldown > 0.0:
		return
	if player.has_method("take_damage"):
		player.take_damage(amount)
	_contact_cooldown = CONTACT_INTERVAL
