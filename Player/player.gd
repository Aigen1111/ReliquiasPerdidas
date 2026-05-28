extends CharacterBody2D

@export var max_health: float = 100.0
## Segundos que espera después de la animación Dead antes de desaparecer
@export var death_delay: float = 1.2
@export var move_speed: float = 220.0
@export var acceleration: float = 1400.0
@export var friction: float = 1800.0
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.10
@export var dash_cooldown: float = 0.30
@export var cursor_texture: Texture2D
@onready var health_bar: Node2D = $HealthBar

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var gun: Node = get_node_or_null("Gun")

var coins: int = 0
var materials: Dictionary = {}
var input_direction := Vector2.ZERO
var last_move_direction := Vector2.ZERO
var dash_direction := Vector2.ZERO
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var current_health: float
var is_dead := false


func _process(_delta: float) -> void:
	rotation = 0.0
	_update_sprite_direction()
	_update_animation()


func _physics_process(delta: float) -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction

	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)

	if _can_start_dash():
		_start_dash()

	if dash_time_left > 0.0:
		dash_time_left = max(dash_time_left - delta, 0.0)
		velocity = dash_direction * dash_speed
	else:
		var target_velocity := input_direction * move_speed
		var movement_force := acceleration if input_direction != Vector2.ZERO else friction
		velocity = velocity.move_toward(target_velocity, movement_force * delta)

	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left") and gun != null and gun.has_method("shoot"):
		gun.shoot()


func _can_start_dash() -> bool:
	return Input.is_action_just_pressed("shift") and dash_cooldown_left <= 0.0 and input_direction != Vector2.ZERO


func _start_dash() -> void:
	dash_direction = last_move_direction.normalized()
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown


func _update_sprite_direction() -> void:
	var mouse_pos := get_global_mouse_position()
	animated_sprite_2d.flip_h = mouse_pos.x < global_position.x


func _update_animation() -> void:
	if velocity.length_squared() > 25.0:
		animated_sprite_2d.play("Walk")
	else:
		animated_sprite_2d.play("Idle")


func _ready() -> void:
	add_to_group("player")
	if RunManager.is_in_run:
		current_health = RunManager.player_current_health
	else:
		current_health = max_health

	if cursor_texture != null:
		Input.set_custom_mouse_cursor(
			cursor_texture,
			Input.CURSOR_ARROW,
			Vector2(16, 16)
		)


func heal(amount: int) -> void:
	if amount <= 0:
		return

	current_health = mini(current_health + amount, max_health)


func add_material(type, amount: int) -> void:
	if amount <= 0:
		return

	var material_key := StringName(type)
	materials[material_key] = int(materials.get(material_key, 0)) + amount
	
	
func _die() -> void:
	is_dead = true
	# ... animación de muerte ...
	await get_tree().create_timer(1.5).timeout
	RunManager.player_died()   # ← Esta es la línea clave
	
	
func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	# Sincronizar con RunManager para que persista entre transiciones de sala
	RunManager.player_current_health = current_health
	# ... tu código de feedback visual (flash, sonido) ...
	if current_health <= 0.0:
		_die()
		
		
	
	
	
