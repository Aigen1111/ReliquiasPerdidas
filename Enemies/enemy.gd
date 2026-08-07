extends CharacterBody2D

signal died

# ── Stats exportados ───────────────────────────────────────────────────────
@export var max_health:  float = 100.0
@export var speed:       float = 60.0
@export var death_delay: float = 1.2
## Oro que suelta este enemigo al morir. Las subclases pueden sobreescribir.
@export var gold_drop:   int   = 5

@export var mask_id:   String = ""   # "jaguar", "danta", "zopilote", "harpia"
@export var weapon_id: String = ""   # "lanza", "escudo", "cerbatana", "arco"

# ── Referencias de nodos ──────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar:      Node2D           = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ── Estado interno ─────────────────────────────────────────────────────────
var current_health: float
var is_dead: bool = false


func _ready() -> void:
	add_to_group("Enemy")
	current_health = max_health
	health_bar.update(current_health, max_health)
	animated_sprite.play("Idle")
	EnemyLoadout.attach(self, mask_id, weapon_id)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_behavior(delta)
	move_and_slide()


# ── Comportamiento (sobreescribir en subclases) ────────────────────────────
# El enemigo base solo persigue al jugador en línea recta.
func _behavior(_delta: float) -> void:
	var player := _get_player()
	if player == null:
		velocity = Vector2.ZERO
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	_update_animation(dir)


# ── Helpers disponibles para las subclases ─────────────────────────────────
func _get_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D


func _update_animation(direction: Vector2) -> void:
	if direction.length() > 0.1:
		animated_sprite.play("Walk")
		animated_sprite.flip_h = direction.x < 0
	else:
		animated_sprite.play("Idle")


# ── Daño y muerte ──────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_bar.update(current_health, max_health)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	died.emit()
	# Entregar oro al run activo
	if RunManager.is_in_run and gold_drop > 0:
		RunManager.add_run_gold(gold_drop)
	animated_sprite.play("Dead")
	collision_shape.set_deferred("disabled", true)
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().create_timer(death_delay).timeout
	if not is_instance_valid(self) or get_tree() == null:
		return
	queue_free()
