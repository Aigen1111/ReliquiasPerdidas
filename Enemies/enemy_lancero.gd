# enemy_lancero.gd — Lancero Bribri (melee)
# Daño de contacto: Area2D HitArea que golpea al jugador al colisionar.
# La carga telegrafíada sigue igual.
extends "res://Enemies/enemy.gd"

@export var charge_speed:    float = 420.0
@export var charge_windup:   float = 0.5
@export var charge_duration: float = 0.35
@export var charge_cooldown: float = 3.0
@export var charge_range:    float = 300.0
@export var contact_damage:  float = 12.0   # daño por contacto normal
@export var charge_damage:   float = 28.0   # daño extra durante la carga

enum State { CHASE, WINDUP, CHARGE, COOLDOWN }
var state:            State = State.CHASE
var state_timer:      float = 0.0
var charge_direction: Vector2 = Vector2.ZERO

# Cooldown de contacto para no aplicar daño cada frame
var _contact_cooldown: float = 0.0
const CONTACT_INTERVAL: float = 0.6


func _ready() -> void:
	super._ready()
	# Conectar HitArea si existe en la escena, si no usar body_entered del propio CharacterBody
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

	match state:
		State.CHASE:
			velocity = to_player.normalized() * speed
			_update_animation(velocity)
			# Daño de contacto en chase
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
			# Daño mayor durante la carga
			if dist < 40.0:
				_try_contact_damage(player, charge_damage)
			if state_timer <= 0.0:
				_enter_cooldown()

		State.COOLDOWN:
			velocity = to_player.normalized() * (speed * 0.5)
			_update_animation(velocity)
			if state_timer <= 0.0:
				state = State.CHASE
				state_timer = 0.0


func _try_contact_damage(player: Node2D, amount: float) -> void:
	if _contact_cooldown > 0.0:
		return
	if player.has_method("take_damage"):
		player.take_damage(amount)
	_contact_cooldown = CONTACT_INTERVAL


func _on_hit_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		_try_contact_damage(body, charge_damage if state == State.CHARGE else contact_damage)


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
