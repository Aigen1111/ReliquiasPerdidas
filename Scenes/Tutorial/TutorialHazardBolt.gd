# TutorialHazardBolt.gd
# Proyectil provisional exclusivo del tutorial de Dash — NO es una Bullet real,
# no hace daño. Si toca al jugador, lo empuja (knockback).
# Visual placeholder armado por código (mismo patrón que TutorialEnemy.gd).
extends Area2D

const COLOR_BOLT: Color = Color(0.5, 0.3, 1.0)   # violeta, distinto al rojo de balas reales
const BOLT_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Paid/Extras/wind_bullet_large1.png"),
	preload("res://Assets/Paid/Extras/wind_bullet_large2.png"),
]
const FLAP_INTERVAL: float = 0.12               # velocidad del aleteo entre frames
const SPRITE_ROTATION_OFFSET: float = -PI / 2   # <- probá 0, PI/2, -PI/2 o PI si sigue girado

@export var speed: float = 260.0
@export var knockback_force: float = 420.0
@export var lifetime: float = 4.0

var direction := Vector2.RIGHT
var _sprite: Sprite2D
var _frame_idx: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # detecta al player (layer 2)
	body_entered.connect(_on_body_entered)
	_build_visual()
	_start_lifetime_timer()


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture  = BOLT_TEXTURES[0]
	_sprite.rotation = SPRITE_ROTATION_OFFSET
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	add_child(col)

	var flap_timer := Timer.new()
	flap_timer.wait_time = FLAP_INTERVAL
	flap_timer.autostart = true
	flap_timer.timeout.connect(_toggle_frame)
	add_child(flap_timer)


func _toggle_frame() -> void:
	_frame_idx = 1 - _frame_idx
	_sprite.texture = BOLT_TEXTURES[_frame_idx]


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
