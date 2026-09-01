# enemy_lancero.gd — Lancero Bribri (melee + lanza a distancia si está protegido)
# Daño de contacto: Area2D HitArea que golpea al jugador al colisionar.
# Mientras un escudo lo está protegiendo activamente, deja de cargar cuerpo a
# cuerpo y pelea a distancia tirando lanzas — ver is_shielded() en enemy.gd.
extends "res://Enemies/enemy.gd"

@export var charge_speed:    float = 420.0
@export var charge_windup:   float = 0.5
@export var charge_duration: float = 0.35
@export var charge_cooldown: float = 3.0
@export var charge_range:    float = 300.0
@export var contact_damage:  float = 12.0
@export var charge_damage:   float = 28.0

# Modo lanza (solo activo mientras is_shielded() es true)
@export var bullet_scene: PackedScene
@export var throw_preferred_distance: float = 260.0
@export var throw_windup:    float = 0.4
@export var throw_cooldown:  float = 1.6
@export var throw_damage:    float = 16.0
@export var throw_speed:     float = 420.0

enum State { CHASE, WINDUP, CHARGE, COOLDOWN, THROW_WINDUP, THROW_COOLDOWN }
var state:            State = State.CHASE
var state_timer:      float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var _throw_direction: Vector2 = Vector2.ZERO

var _contact_cooldown: float = 0.0
const CONTACT_INTERVAL: float = 0.6


func _ready() -> void:
	super._ready()
	var hit_area := get_node_or_null("HitArea")
	if hit_area and hit_area.has_signal("body_entered"):
		hit_area.body_entered.connect(_on_hit_body_entered)


func _behavior(delta: float) -> void:
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)

	var player: Node2D = _get_player()
	if player == null:
		return

	state_timer -= delta
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# Una vez empezado un tiro de lanza, lo termina aunque el escudo se vaya
	# a mitad de camino (no lo corta de golpe). Solo ENTRA a modo lanza desde
	# CHASE/COOLDOWN si en ese momento está protegido.
	var already_ranged: bool = state == State.THROW_WINDUP or state == State.THROW_COOLDOWN
	if already_ranged or (is_shielded() and (state == State.CHASE or state == State.COOLDOWN)):
		_behavior_ranged(player, to_player, dist)
		return

	match state:
		State.CHASE:
			velocity = to_player.normalized() * speed
			_update_animation(velocity)
			if dist < 32.0:
				_try_contact_damage(player, contact_damage)
			if dist < charge_range and state_timer <= 0.0:
				_enter_windup()

		State.WINDUP:
			velocity = Vector2.ZERO
			if fmod(state_timer, 0.1) < 0.05:
				animated_sprite.modulate = Color(1.5, 0.6, 0.1)
			else:
				animated_sprite.modulate = Color.WHITE
			if state_timer <= 0.0:
				_enter_charge(to_player.normalized())

		State.CHARGE:
			velocity = charge_direction * charge_speed
			if dist < 40.0:
				_try_contact_damage(player, charge_damage)
			if state_timer <= 0.0:
				_enter_cooldown()

		State.COOLDOWN:
			var flee_speed: float = speed * 0.8
			if dist > 200.0:
				velocity = Vector2.ZERO
			else:
				velocity = -to_player.normalized() * flee_speed
			_update_animation(velocity)
			animated_sprite.modulate = Color.WHITE
			if state_timer <= 0.0:
				state       = State.CHASE
				state_timer = 0.0


# ── Modo lanza a distancia ──────────────────────────────────────────────
func _behavior_ranged(player: Node2D, to_player: Vector2, dist: float) -> void:
	if dist < throw_preferred_distance - 40.0:
		velocity = -to_player.normalized() * speed
	elif dist > throw_preferred_distance + 60.0:
		velocity = to_player.normalized() * speed
	else:
		velocity = Vector2.ZERO
	_update_animation(velocity)

	match state:
		State.CHASE, State.COOLDOWN:
			if dist <= throw_preferred_distance + 80.0:
				_enter_throw_windup(to_player.normalized())

		State.THROW_WINDUP:
			if fmod(state_timer, 0.1) < 0.05:
				animated_sprite.modulate = Color(1.5, 0.6, 0.1)
			else:
				animated_sprite.modulate = Color.WHITE
			if state_timer <= 0.0:
				_throw_spear()

		State.THROW_COOLDOWN:
			animated_sprite.modulate = Color.WHITE
			if state_timer <= 0.0:
				state       = State.CHASE
				state_timer = 0.0


func _enter_throw_windup(direction: Vector2) -> void:
	state             = State.THROW_WINDUP
	state_timer       = throw_windup
	_throw_direction  = direction
	velocity          = Vector2.ZERO


func _throw_spear() -> void:
	if bullet_scene != null:
		var spear = bullet_scene.instantiate()
		get_parent().add_child(spear)
		spear.global_position = EnemyLoadout.get_weapon_muzzle_position(self)
		spear.speed    = throw_speed
		spear.damage   = throw_damage
		spear.modulate = Color(0.75, 0.55, 0.3)   # tono madera — lanza
		if spear.has_method("setup"):
			spear.setup(_throw_direction, self, "enemy")
	animated_sprite.modulate = Color.WHITE
	state       = State.THROW_COOLDOWN
	state_timer = throw_cooldown



func _try_contact_damage(player: Node2D, amount: float) -> void:
	if _contact_cooldown > 0.0:
		return
	if player.has_method("take_damage"):
		player.take_damage(amount)
	_contact_cooldown = CONTACT_INTERVAL


func _on_hit_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		_try_contact_damage(body, charge_damage if state == State.CHARGE else contact_damage)

func _on_body_entered(body: Node2D) -> void:
	# Verificamos si lo que tocó la lanza pertenece al grupo "player"
	if body.is_in_group("player"):
		# Reemplaza "take_damage" por el método real que usas en el jugador para restar vida
		if body.has_method("take_damage"):
			body.take_damage(15.0) # Ajusta el número según el daño de la lanza

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

func _init() -> void:
	mask_id   = "jaguar"
	weapon_id = "lanza"
