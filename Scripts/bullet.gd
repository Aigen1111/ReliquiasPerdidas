extends CharacterBody2D

@export var speed: float = 650.0
@export var lifetime: float = 1.0

var direction := Vector2.ZERO


func _ready() -> void:
	_start_lifetime_timer()


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var collision := move_and_collide(direction * speed * delta)
	if collision != null:
		queue_free()


func setup(travel_direction: Vector2, ignored_body: PhysicsBody2D = null) -> void:
	if travel_direction == Vector2.ZERO:
		return

	if ignored_body != null:
		add_collision_exception_with(ignored_body)

	direction = travel_direction.normalized()
	global_rotation = direction.angle()


func _start_lifetime_timer() -> void:
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()
