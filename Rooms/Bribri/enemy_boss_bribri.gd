# enemy_boss_bribri.gd — Guardián Bribri (Boss)
# Casco de conquistador español corrupto, inmóvil flota en el centro
# de la sala y ataca con proyectiles, sin perseguir ni embestir.
#
# FASES:
#   Fase 1 (100% → 50% vida): FAN_SHOT + BARRAGE + SPIRAL
#   Fase 2 (< 50% vida): todo lo anterior más frecuente, más SUMMON (invoca
#     Lanceros) y RING_BURST (anillo de 360°).
#     La transición a Fase 2 tiene una pausa de 1.5 s con flash blanco.


extends "res://Enemies/enemy.gd"

# ── Exportados/Variables
@export var bullet_scene:   PackedScene
@export var lancero_scene:  PackedScene

# Barrage (línea de balas telegrafiada)
@export var barrage_windup:    float = 0.55
@export var barrage_bullets:   int   = 10
@export var barrage_interval:  float = 0.06
@export var barrage_speed:     float = 520.0
@export var barrage_damage:    float = 14.0
@export var barrage_cooldown:  float = 3.5

@export var contact_damage:  float = 14.0   # si el jugador se pega demasiado

# Abanico
@export var fan_cooldown:    float = 2.8
@export var fan_bullets_p1:  int   = 7      # antes 5 — más denso
@export var fan_bullets_p2:  int   = 10     # antes 7
@export var fan_spread_deg:  float = 70.0
@export var fan_speed:       float = 300.0
@export var fan_damage:      float = 18.0

# Invocación (Fase 2)
@export var summon_cooldown: float = 8.0
@export var summon_offset:   float = 120.0

# Espiral (chorro rotante — disponible desde Fase 1, obliga a moverse en vez
# de esquivar una sola vez, porque el brazo va barriendo toda la sala)
@export var spiral_cooldown:            float = 7.0
@export var spiral_windup:              float = 0.4
@export var spiral_duration:            float = 2.2
@export var spiral_bullet_interval:     float = 0.08
@export var spiral_rotation_speed_deg:  float = 260.0
@export var spiral_speed:               float = 300.0
@export var spiral_damage:              float = 10.0

# Anillo de 360° (Fase 2 — ataque más fuerte, telegrafiado más largo)
@export var ring_cooldown: float = 6.0
@export var ring_windup:   float = 0.9
@export var ring_bullets:  int   = 16
@export var ring_speed:    float = 260.0
@export var ring_damage:   float = 12.0

# Pesos de selección — probabilidad relativa entre los ataques disponibles
# en ese instante (no son porcentajes fijos, se normalizan solos según
# cuáles estén listos). Subir un peso hace que ese ataque salga más seguido
# sin quitarle del todo la chance a los demás.
@export var weight_fan:     float = 1.0
@export var weight_barrage: float = 1.0
@export var weight_spiral:  float = 0.9
@export var weight_summon:  float = 1.0
@export var weight_ring:    float = 0.6   # más fuerte → pesa menos

# ── Constantes
const PHASE2_THRESHOLD: float = 0.5
const CONTACT_INTERVAL: float = 0.55
const PHASE_FLASH_TIME: float = 1.5

# ── Estado interno
enum State {
	IDLE, BARRAGE_WINDUP, BARRAGE, FAN_SHOT, SUMMON,
	SPIRAL_WINDUP, SPIRAL, RING_WINDUP, PHASE_TRANSITION
}

var state:              State = State.IDLE
var state_timer:        float = 0.0
var _barrage_direction:  Vector2 = Vector2.ZERO
var _barrage_shots_left: int = 0
var _barrage_shot_timer: float = 0.0
var _barrage_timer:     float = 2.0   # primer barrage a los 2s
var _contact_cooldown:  float = 0.0
var _fan_timer:         float = 1.0
var _summon_timer:      float = 4.0
var _phase:             int   = 1
var _phase2_entered:    bool  = false

# Espiral
var _spiral_timer:      float = 4.5
var _spiral_angle:      float = 0.0
var _spiral_time_left:  float = 0.0
var _spiral_shot_timer: float = 0.0

# Anillo (solo cuenta en Fase 2, igual que summon)
var _ring_timer:        float = 5.0


func _init() -> void:
	has_corruption_particles = false

# ── Setup
func _ready() -> void:
	super._ready()
	max_health = 950.0   # estimado — ajustar según cuánto dure la pelea en la práctica
	speed      = 0.0     # inmóvil
	gold_drop  = 40
	current_health = max_health
	health_bar.update(current_health, max_health)
	_set_telegraphing(false)


# ── Comportamiento principal
func _behavior(delta: float) -> void:
	velocity = Vector2.ZERO   # nunca se mueve — se sobreescribe explícito por claridad
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)

	if not _phase2_entered and current_health / max_health <= PHASE2_THRESHOLD:
		_phase2_entered = true
		_enter_phase_transition()
		return

	if state == State.PHASE_TRANSITION:
		return

	state_timer -= delta

	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float        = to_player.length()

	_fan_timer     -= delta
	_barrage_timer -= delta
	_spiral_timer  -= delta
	if _phase == 2:
		_summon_timer -= delta
		_ring_timer    -= delta

	match state:
		State.IDLE:
			# Daño de contacto si el jugador se pega demasiado
			if dist < 40.0:
				_try_contact_damage(player, contact_damage)

			_try_start_attack()

		State.BARRAGE_WINDUP:
			if state_timer <= 0.0:
				_start_barrage((player.global_position - global_position).normalized())

		State.BARRAGE:
			_barrage_shot_timer -= delta
			if _barrage_shot_timer <= 0.0 and _barrage_shots_left > 0:
				_fire_barrage_bullet()
			if _barrage_shots_left <= 0:
				_set_telegraphing(false)
				_barrage_timer = barrage_cooldown
				state = State.IDLE

		State.FAN_SHOT:
			if state_timer <= 0.0:
				_fire_fan(to_player.normalized())

		State.SUMMON:
			if state_timer <= 0.0:
				_do_summon()

		State.SPIRAL_WINDUP:
			if state_timer <= 0.0:
				_start_spiral(to_player.normalized())

		State.SPIRAL:
			_spiral_time_left  -= delta
			_spiral_angle      += deg_to_rad(spiral_rotation_speed_deg) * delta
			_spiral_shot_timer -= delta
			if _spiral_shot_timer <= 0.0:
				_fire_spiral_bullet()
				_spiral_shot_timer = spiral_bullet_interval
			if _spiral_time_left <= 0.0:
				_set_telegraphing(false)
				_spiral_timer = spiral_cooldown
				state = State.IDLE

		State.RING_WINDUP:
			if state_timer <= 0.0:
				_fire_ring()


# ── Selección de ataque (aleatoria con pesos, entre los que estén listos)
func _try_start_attack() -> void:
	var candidates: Array = []

	if _fan_timer <= 0.0:
		candidates.append({"enter": Callable(self, "_enter_fan_shot"), "weight": weight_fan})
	if _barrage_timer <= 0.0:
		candidates.append({"enter": Callable(self, "_enter_barrage_windup"), "weight": weight_barrage})
	if _spiral_timer <= 0.0:
		candidates.append({"enter": Callable(self, "_enter_spiral_windup"), "weight": weight_spiral})
	if _phase == 2:
		if _summon_timer <= 0.0:
			candidates.append({"enter": Callable(self, "_enter_summon"), "weight": weight_summon})
		if _ring_timer <= 0.0:
			candidates.append({"enter": Callable(self, "_enter_ring_windup"), "weight": weight_ring})

	if candidates.is_empty():
		return

	var total_weight: float = 0.0
	for c in candidates:
		total_weight += c["weight"]

	# Si por alguna razón todos los pesos quedaron en 0, se reparte parejo
	if total_weight <= 0.0:
		candidates.pick_random()["enter"].call()
		return

	var roll: float = randf() * total_weight
	var acc:  float = 0.0
	for c in candidates:
		acc += c["weight"]
		if roll <= acc:
			c["enter"].call()
			return


# ── Entradas de estado
func _enter_barrage_windup() -> void:
	state       = State.BARRAGE_WINDUP
	state_timer = barrage_windup
	_set_telegraphing(true)


func _start_barrage(direction: Vector2) -> void:
	state               = State.BARRAGE
	_barrage_direction  = direction
	_barrage_shots_left = barrage_bullets
	_barrage_shot_timer = 0.0
	_set_telegraphing(true)


func _enter_fan_shot() -> void:
	state       = State.FAN_SHOT
	state_timer = 0.5
	_fan_timer  = fan_cooldown
	_set_telegraphing(true)


func _enter_summon() -> void:
	state         = State.SUMMON
	state_timer   = 0.6
	_summon_timer = summon_cooldown
	_set_telegraphing(true)


func _enter_spiral_windup() -> void:
	state         = State.SPIRAL_WINDUP
	state_timer   = spiral_windup
	_spiral_timer = spiral_cooldown
	_set_telegraphing(true)


func _start_spiral(base_direction: Vector2) -> void:
	state               = State.SPIRAL
	_spiral_angle       = base_direction.angle()
	_spiral_time_left   = spiral_duration
	_spiral_shot_timer  = 0.0
	_set_telegraphing(true)


func _enter_ring_windup() -> void:
	state       = State.RING_WINDUP
	state_timer = ring_windup
	_ring_timer = ring_cooldown
	_set_telegraphing(true)


func _enter_phase_transition() -> void:
	state = State.PHASE_TRANSITION
	_do_phase_transition()


# ── Ataques
func _fire_barrage_bullet() -> void:
	if bullet_scene == null:
		_barrage_shots_left = 0
		return

	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.speed  = barrage_speed
	bullet.damage = barrage_damage
	bullet.modulate = Color(2.0, 0.5, 0.2)   # naranja intenso — línea recta
	if bullet.has_method("setup"):
		bullet.setup(_barrage_direction, self, "enemy")

	_barrage_shots_left -= 1
	_barrage_shot_timer  = barrage_interval


func _fire_fan(base_direction: Vector2) -> void:
	_set_telegraphing(false)
	if bullet_scene == null:
		state = State.IDLE
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
		bullet.modulate = Color(0.3, 1.8, 0.5)   # verde — abanico
		if bullet.has_method("setup"):
			bullet.setup(dir, self, "enemy")

	state = State.IDLE


func _do_summon() -> void:
	_set_telegraphing(false)
	if lancero_scene == null:
		state = State.IDLE
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
		var room = get_parent()
		if room.has_method("_on_enemy_died"):
			lancero.died.connect(room._on_enemy_died)

	state = State.IDLE


func _fire_spiral_bullet() -> void:
	if bullet_scene == null:
		return

	var dir: Vector2 = Vector2.RIGHT.rotated(_spiral_angle)
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	bullet.speed  = spiral_speed
	bullet.damage = spiral_damage
	bullet.modulate = Color(0.6, 0.3, 1.8)   # morado — espiral
	if bullet.has_method("setup"):
		bullet.setup(dir, self, "enemy")


func _fire_ring() -> void:
	_set_telegraphing(false)
	if bullet_scene == null:
		state = State.IDLE
		return

	for i in range(ring_bullets):
		var angle_deg: float = (360.0 / ring_bullets) * i
		var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))

		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = global_position
		bullet.speed  = ring_speed
		bullet.damage = ring_damage
		bullet.modulate = Color(1.8, 1.8, 0.3)   # amarillo — anillo
		if bullet.has_method("setup"):
			bullet.setup(dir, self, "enemy")

	state = State.IDLE


# ── Transición a Fase 2
func _do_phase_transition() -> void:
	_phase = 2
	fan_cooldown     *= 0.75
	barrage_cooldown *= 0.7   # todo más frecuente en vez de "más rápido moviéndose"
	spiral_cooldown  *= 0.8
	ring_cooldown    *= 0.8

	var flash_colors: Array = [
		Color(2.0, 2.0, 2.0),
		Color(1.6, 0.3, 0.1),
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
	_set_telegraphing(false)
	state          = State.IDLE
	state_timer    = 0.0
	_fan_timer     = 1.0
	_barrage_timer = 1.5
	_spiral_timer  = 2.0
	_summon_timer  = 2.0
	_ring_timer    = 3.0


# ── Visual: 2 sprites (Base/Glow) con fallback a modulate si no existen todavía
func _set_telegraphing(active: bool) -> void:
	var anim_name := "attack" if active else "idle_down"
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		animated_sprite.modulate = Color.WHITE
	else:
		animated_sprite.modulate = Color(1.6, 0.6, 0.1) if active else Color.WHITE


# ── Helpers
func _try_contact_damage(player: Node2D, amount: float) -> void:
	if _contact_cooldown > 0.0:
		return
	if player.has_method("take_damage"):
		player.take_damage(amount)
	_contact_cooldown = CONTACT_INTERVAL
