# TutorialHazardBolt.gd
# Proyectil provisional exclusivo del tutorial de Dash — NO es una Bullet real,
# no hace daño. Si toca al jugador, lo empuja (knockback).
# Visual placeholder armado por código (mismo patrón que TutorialEnemy.gd).
extends Area2D

const COLOR_BOLT: Color = Color(0.5, 0.3, 1.0)   # violeta, distinto al rojo de balas reales

@export var speed: float = 260.0
@export var knockback_force: float = 420.0
@export var lifetime: float = 4.0

var direction := Vector2.RIGHT


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # detecta al player (layer 2)
	body_entered.connect(_on_body_entered)
	_build_visual()
	_start_lifetime_timer()


func _build_visual() -> void:
	var rect := ColorRect.new()
	rect.size     = Vector2(16, 16)
	rect.position = Vector2(-8, -8)
	rect.color    = COLOR_BOLT
	add_child(rect)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	add_child(col)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func setup(travel_direction: Vector2) -> void:
	if travel_direction == Vector2.ZERO:
		return
	direction = travel_direction.normalized()
	rotation = direction.angle()


func _on_body_entered(body: Node) -> void:
	if "dash_iframe_left" in body and body.dash_iframe_left > 0.0:
		return
	if body.is_in_group("player") and body.has_method("apply_knockback"):
		body.apply_knockback(direction, knockback_force)
	queue_free()


func _start_lifetime_timer() -> void:
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().create_timer(lifetime).timeout
	if not is_instance_valid(self) or get_tree() == null:
		return
	if is_inside_tree():
		queue_free()
