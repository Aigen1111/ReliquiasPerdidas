# bullet.gd
# ─────────────────────────────────────────────────────────────────────────────
# team = "player"  → solo daña a nodos del grupo "Enemy"
# team = "enemy"   → solo daña a nodos del grupo "player"
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody2D

@export var speed:    float = 650.0
@export var lifetime: float = 1.0
@export var damage:   float = 25.0

var direction := Vector2.ZERO
var team:       String = "player"   # se sobreescribe en setup()


func _ready() -> void:
	_start_lifetime_timer()


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var collision := move_and_collide(direction * speed * delta)
	if collision == null:
		return

	var collider := collision.get_collider()

	# Si el que la recibió está dasheando, la atraviesa entero —
	if collider != null and "dash_iframe_left" in collider and collider.dash_iframe_left > 0.0:
		move_and_collide(collision.get_remainder())
		return

	if collider != null and collider.has_method("take_damage"):
		# Solo dañar al equipo contrario
		var should_damage: bool = false
		if team == "player" and collider.is_in_group("Enemy"):
			should_damage = true
		elif team == "enemy" and collider.is_in_group("player"):
			should_damage = true

		if should_damage:
			collider.take_damage(damage)

	queue_free()


func setup(travel_direction: Vector2, shooter: PhysicsBody2D = null, bullet_team: String = "player") -> void:
	if travel_direction == Vector2.ZERO:
		return

	team = bullet_team

	# Ignorar colisión física con el shooter para evitar auto-daño
	if shooter != null:
		add_collision_exception_with(shooter)

	direction = travel_direction.normalized()
	global_rotation = direction.angle()


func _start_lifetime_timer() -> void:
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().create_timer(lifetime).timeout
	if not is_instance_valid(self) or get_tree() == null:
		return
	if is_inside_tree():
		queue_free()
