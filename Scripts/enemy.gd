extends CharacterBody2D

@export var max_health: float = 100.0
## Segundos que espera después de la animación Dead antes de desaparecer
@export var death_delay: float = 1.2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: Node2D = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_health: float
var is_dead := false


func _ready() -> void:
	current_health = max_health
	health_bar.update(current_health, max_health)
	animated_sprite.play("Idle")


## Llamado por la bala al colisionar
func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_bar.update(current_health, max_health)

	if current_health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	animated_sprite.play("Dead")
	# Desactivar colisión para que nada más interactúe con el cadáver
	collision_shape.set_deferred("disabled", true)
	await get_tree().create_timer(death_delay).timeout
	queue_free()
