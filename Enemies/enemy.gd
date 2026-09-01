extends CharacterBody2D

signal died

# ── Stats exportados ───────────────────────────────────────────────────────
@export var max_health:  float = 100.0
@export var speed:       float = 60.0
@export var death_delay: float = 1.2
## Oro que suelta este enemigo al morir. Las subclases pueden sobreescribir.
@export var gold_drop:   int   = 5
@export var hurt_flash_duration: float = 0.35

@export var mask_id:   String = ""   # "jaguar", "danta", "zopilote", "harpia"
@export var weapon_id: String = ""   # "lanza", "escudo", "cerbatana", "arco"

# ── Referencias de nodos ──────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar:      Node2D           = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ── Direcciones (mismo criterio que player.gd: eje dominante del vector) ──
enum FacingDir { DOWN, UP, LEFT, RIGHT }
const DIR_NAMES := {
	FacingDir.DOWN:  "down",
	FacingDir.UP:    "up",
	FacingDir.LEFT:  "left",
	FacingDir.RIGHT: "right",
}
var _facing_dir: int = FacingDir.DOWN

# ── Estado interno ─────────────────────────────────────────────────────────
var current_health: float
var is_dead: bool = false
var _hurt_flash_time_left: float = 0.0

# Lo refresca enemy_escudo.gd cada frame mientras este enemigo está siendo
# protegido — si el escudo deja de protegerlo (murió, se alejó, eligió otro
# aliado), se apaga solo en fracciones de segundo sin que nadie más avise.
var shielded_time_left: float = 0.0
var shielding_ally: Node2D = null
var has_corruption_particles: bool = true

func _ready() -> void:
	add_to_group("Enemy")
	current_health = max_health
	health_bar.update(current_health, max_health)
	animated_sprite.play("idle_down")
	EnemyLoadout.attach(self, mask_id, weapon_id)
	if has_corruption_particles:
		EnemyLoadout.attach_corruption_particles(self)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_hurt_flash_time_left = maxf(_hurt_flash_time_left - delta, 0.0)
	shielded_time_left    = maxf(shielded_time_left - delta, 0.0)
	_behavior(delta)
	move_and_slide()


func is_shielded() -> bool:
	return shielded_time_left > 0.0


# ── Comportamiento (sobreescribir en subclases) ────────────────────────────
# El enemigo base solo persigue al jugador en línea recta.
func _behavior(_delta: float) -> void:
	var player := _get_player()
	if player == null:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
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


func _direction_from_vector(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return FacingDir.RIGHT if v.x > 0.0 else FacingDir.LEFT
	else:
		return FacingDir.DOWN if v.y > 0.0 else FacingDir.UP


func _update_animation(direction: Vector2) -> void:
	if _hurt_flash_time_left > 0.0:
		return

	var moving := direction.length() > 0.1
	if moving:
		_facing_dir = _direction_from_vector(direction)

	var state := "walk" if moving else "idle"
	var anim_name := "%s_%s" % [state, DIR_NAMES[_facing_dir]]
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _play_hurt_flash() -> void:
	if animated_sprite.sprite_frames == null:
		return
	var anim_name := "hurt_%s" % DIR_NAMES[_facing_dir]
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		_hurt_flash_time_left = hurt_flash_duration

static func attach_corruption_particles(enemy: Node2D) -> void:
	var particles := GPUParticles2D.new()
	particles.name       = "CorruptionParticles"
	particles.amount     = 10
	particles.lifetime   = 1.6
	particles.randomness = 0.4
	particles.z_index    = 4   # detrás de la máscara (z=5), delante del piso

	var mat := ParticleProcessMaterial.new()
	mat.direction              = Vector3(0, -1, 0)
	mat.spread                 = 25.0
	mat.initial_velocity_min   = 4.0
	mat.initial_velocity_max   = 10.0
	mat.gravity                = Vector3(0, -6, 0)   # negativo = flotan hacia arriba
	mat.scale_min              = 0.5
	mat.scale_max              = 1.2
	mat.emission_shape         = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.05, 0.35, 0.9))
	ramp.set_color(1, Color(0.45, 0.05, 0.35, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	particles.process_material = mat

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	particles.texture = ImageTexture.create_from_image(img)

	particles.position = Vector2(0, -6)
	particles.emitting = true
	enemy.add_child(particles)

# ── Daño y muerte ──────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_bar.update(current_health, max_health)
	if current_health <= 0.0:
		_die()
	else:
		_play_hurt_flash()


func _die() -> void:
	is_dead = true
	died.emit()
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
