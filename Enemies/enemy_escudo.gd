# enemy_escudo.gd — Portador de Escudo (melee)
# Daño de contacto + reducción de daño frontal. Protege al aliado más cercano
# refrescando su shielded_time_left, lo que activa el modo a distancia en
# Lancero y el modo abanico en Ametralladora mientras están cerca de este.
extends "res://Enemies/enemy.gd"

@export var shield_damage_reduction: float = 0.6
@export var ally_protection_range:   float = 200.0
@export var block_arc_degrees:       float = 100.0
@export var contact_damage:          float = 10.0

var _contact_cooldown: float = 0.0
const CONTACT_INTERVAL: float = 0.7


func _ready() -> void:
	super._ready()


func _behavior(delta: float) -> void:
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)

	var player: Node2D = _get_player()
	if player == null:
		return

	var protect_target: Node2D = _find_ally_to_protect()

	if protect_target != null and "shielded_time_left" in protect_target:
		protect_target.shielded_time_left = 0.25
		protect_target.shielding_ally = self
		

	if protect_target != null:
		var to_player: Vector2 = (player.global_position - protect_target.global_position).normalized()
		var ideal_pos: Vector2 = protect_target.global_position + to_player * 80.0
		velocity = (ideal_pos - global_position).normalized() * speed
	else:
		velocity = (player.global_position - global_position).normalized() * speed

	_update_animation(velocity)

	# Daño de contacto al estar cerca del jugador
	if global_position.distance_to(player.global_position) < 32.0:
		if _contact_cooldown <= 0.0 and player.has_method("take_damage"):
			player.take_damage(contact_damage)
			_contact_cooldown = CONTACT_INTERVAL


func take_damage(amount: float) -> void:
	var player: Node2D = _get_player()
	if player != null:
		var to_attacker: Vector2 = (player.global_position - global_position).normalized()
		var facing: Vector2 = _facing_vector()
		var angle: float = rad_to_deg(to_attacker.angle_to(facing))
		if abs(angle) < block_arc_degrees * 0.5:
			amount *= (1.0 - shield_damage_reduction)
	super.take_damage(amount)


func _facing_vector() -> Vector2:
	match _facing_dir:
		FacingDir.LEFT:
			return Vector2.LEFT
		FacingDir.RIGHT:
			return Vector2.RIGHT
		FacingDir.UP:
			return Vector2.UP
		_:
			return Vector2.DOWN


func _find_ally_to_protect() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("Enemy")
	var nearest: Node2D = null
	var nearest_dist: float = ally_protection_range
	for e: Node in enemies:
		if e == self:
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e as Node2D
	return nearest

func _init() -> void:
	mask_id   = "danta"
	weapon_id = "escudo"
