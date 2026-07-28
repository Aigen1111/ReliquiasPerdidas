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
@export var dash_iframe_duration: float = 0.25 
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
var knockback_velocity := Vector2.ZERO
var knockback_time_left := 0.0
var movement_locked := false
var current_health: float
var is_dead := false
enum FacingDir { DOWN, UP, LEFT, RIGHT }
const DIR_NAMES := {
	FacingDir.DOWN:  "down",
	FacingDir.UP:    "up",
	FacingDir.LEFT:  "left",
	FacingDir.RIGHT: "right",
}

var _facing_dir: int = FacingDir.DOWN

# Stats derivados — se calculan en _apply_relic_bonuses()
var _effective_max_health: float = 0.0
var _dodge_chance:         float = 0.0
var _dash_charges:         int   = 1   # cuántos dashes disponibles
var _dash_charges_left:    int   = 1
var _dash_recharge_timer:  float = 0.0
var dash_iframe_left := 0.0

# Popup flotante sobre el jugador
var _popup_label: Label = null


func _process(_delta: float) -> void:
	rotation = 0.0
	_update_sprite_direction()
	_update_animation()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if movement_locked:
		input_direction = Vector2.ZERO
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		last_move_direction = input_direction

	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	dash_iframe_left   = max(dash_iframe_left - delta, 0.0)

	# Recargar cargas de dash cuando el cooldown termina
	if dash_cooldown_left <= 0.0 and _dash_charges_left < _dash_charges:
		_dash_recharge_timer -= delta
		if _dash_recharge_timer <= 0.0:
			_dash_charges_left   = _dash_charges
			_dash_recharge_timer = 0.0

	if _can_start_dash():
		_start_dash()
		_dash_recharge_timer = dash_cooldown + 0.2

	if dash_time_left > 0.0:
		dash_time_left = max(dash_time_left - delta, 0.0)
		velocity = dash_direction * dash_speed
	elif knockback_time_left > 0.0:
		knockback_time_left = max(knockback_time_left - delta, 0.0)
		velocity = knockback_velocity
	else:
		var target_velocity := input_direction * move_speed
		var movement_force := acceleration if input_direction != Vector2.ZERO else friction
		velocity = velocity.move_toward(target_velocity, movement_force * delta)

	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left") and gun != null and gun.has_method("shoot") and gun.process_mode != Node.PROCESS_MODE_DISABLED:
		gun.shoot()


func _can_start_dash() -> bool:
	return (Input.is_action_just_pressed("shift")
		and _dash_charges_left > 0
		and dash_cooldown_left <= 0.0
		and input_direction != Vector2.ZERO)


func _start_dash() -> void:
	dash_direction     = last_move_direction.normalized()
	dash_time_left     = dash_duration
	dash_cooldown_left = dash_cooldown
	dash_iframe_left   = dash_iframe_duration   # ← nueva línea
	_dash_charges_left -= 1
	_spawn_afterimages()


func _update_sprite_direction() -> void:
	# La orientación la manda hacia dónde apunta el mouse, no hacia dónde
	# caminás — es el mismo criterio que ya tenía el flip_h de antes,
	# solo que ahora resolvemos las 4 direcciones en vez de solo L/R.
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 1.0:
		return  # mouse prácticamente encima del personaje, no vale la pena recalcular
	_facing_dir = _direction_from_vector(to_mouse)


func _direction_from_vector(v: Vector2) -> int:
	# Se queda con el eje dominante del vector. En Godot Y+ es hacia abajo.
	if absf(v.x) > absf(v.y):
		return FacingDir.RIGHT if v.x > 0.0 else FacingDir.LEFT
	else:
		return FacingDir.DOWN if v.y > 0.0 else FacingDir.UP


func _update_animation() -> void:
	var frames := animated_sprite_2d.sprite_frames
	if frames == null:
		return

	var state := "walk" if velocity.length_squared() > 25.0 else "idle"
	var dir_name: String = DIR_NAMES[_facing_dir]
	var anim_name := "%s_%s" % [state, dir_name]

	# Si la hoja no trae left/right dibujados aparte, se prueba  con una
	# versión "side" espejo
	if not frames.has_animation(anim_name) and (_facing_dir == FacingDir.LEFT or _facing_dir == FacingDir.RIGHT):
		anim_name = "%s_side" % state
		animated_sprite_2d.flip_h = (_facing_dir == FacingDir.LEFT)
	else:
		animated_sprite_2d.flip_h = false

	if frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)


func _ready() -> void:
	add_to_group("player")
	# La barra de vida del RunHUD reemplaza la del player — ocultarla
	if health_bar:
		health_bar.hide()
	_build_popup_label()
	_apply_relic_bonuses()

	if RunManager.is_in_run:
		current_health = minf(RunManager.player_current_health, _effective_max_health)
	else:
		current_health = _effective_max_health

	# Sincronizar max_health en RunManager para que rest_room calcule bien
	RunManager.player_max_health = _effective_max_health

	if cursor_texture != null:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
		
	if not RunManager.relic_activated.is_connected(_on_relic_activated):
		RunManager.relic_activated.connect(_on_relic_activated)


## Crea el Label flotante que sube sobre el jugador (invisible por defecto).
func _build_popup_label() -> void:
	_popup_label = Label.new()
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_label.add_theme_font_size_override("font_size", 13)
	_popup_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	_popup_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_popup_label.add_theme_constant_override("outline_size", 4)
	# El player tiene scale(5,5) — compensar para que el texto sea legible
	_popup_label.scale    = Vector2(0.2, 0.2)
	# size en espacio local del Label. En pantalla: 150*0.2=30px ancho, 24*0.2≈5px alto
	_popup_label.size     = Vector2(150, 24)
	# position en espacio del PADRE (player), donde 1 unidad = 5px en pantalla.
	# Barra de recarga está en y=-10. Popup va en y=-13 (3 unidades = 15px más arriba).
	# Para centrar: label mide 30px pantalla = 6 unidades padre → x = -3
	_popup_label.position = Vector2(-3, -13)
	_popup_label.z_index  = 10
	_popup_label.visible  = false
	add_child(_popup_label)


## Muestra un texto flotante encima del jugador que sube y desaparece.
func show_popup(text: String, color: Color = Color(1.0, 0.95, 0.3)) -> void:
	if _popup_label == null:
		return
	_popup_label.text         = text
	_popup_label.modulate     = color
	_popup_label.modulate.a   = 1.0
	_popup_label.position     = Vector2(-3, -13)
	_popup_label.visible      = true

	var tween := create_tween()
	# Sube 4 unidades padre = 20px en pantalla durante 1.2s (más visible)
	tween.tween_property(_popup_label, "position:y", -17.0, 1.2)
	tween.parallel().tween_property(_popup_label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func(): _popup_label.visible = false)

func _on_relic_activated(relic_id: String) -> void:
	var data := MuseumData.get_relic(relic_id)
	if data.is_empty():
		return
	var line: String = data.get("pickup_line", data.get("name", ""))
	show_popup(line, Color(0.9, 0.78, 0.2))   # dorado — color de Sibö

## Lee las reliquias activas y modifica los stats del jugador en consecuencia.
## Se llama una sola vez en _ready() — los efectos duran toda la sala.
func _apply_relic_bonuses() -> void:
	_effective_max_health = max_health
	_dodge_chance         = 0.0
	_dash_charges         = 1

	for relic_id in RunManager.active_relics:
		var data: Dictionary = MuseumData.get_relic(relic_id)
		if data.is_empty():
			continue
		var bonus_type:  String = data.get("bonus_type",  "")
		var bonus_value: float  = float(data.get("bonus_value", 0.0))

		match bonus_type:
			"max_health_pct":
				# Máscara de Sibö: +20% vida máxima
				_effective_max_health *= (1.0 + bonus_value)

			"dodge_chance":
				# Piedra Tsuru: 15% de esquivar
				_dodge_chance = clampf(_dodge_chance + bonus_value, 0.0, 0.75)

			"extra_dash":
				# Tambor Ceremonial: 1 dash extra
				_dash_charges += int(bonus_value)

			# rest_heal_pct y projectile_dmg_pct se aplican en otros scripts:
			# rest_room.gd ya lee vasija_cacao
			# gun.gd leerá flecha_awa en shoot()

	_effective_max_health = roundf(_effective_max_health)
	max_health            = _effective_max_health
	_dash_charges_left    = _dash_charges


func _spawn_afterimages() -> void:
	# Crear 4 afterimages del sprite actual que se desvanecen rápidamente
	const IMAGE_COUNT:    int   = 4
	const IMAGE_INTERVAL: float = 0.03
	const FADE_TIME:      float = 0.18

	for i in range(IMAGE_COUNT):
		if not is_instance_valid(self) or get_tree() == null:
			return
		await get_tree().create_timer(IMAGE_INTERVAL * i).timeout
		if not is_instance_valid(self) or get_tree() == null:
			return
		if not is_inside_tree():
			return

		var ghost := Sprite2D.new()
		ghost.texture        = animated_sprite_2d.sprite_frames.get_frame_texture(
			animated_sprite_2d.animation, animated_sprite_2d.frame)
		ghost.flip_h         = animated_sprite_2d.flip_h
		ghost.scale          = animated_sprite_2d.scale
		ghost.global_position = global_position
		ghost.modulate       = Color(0.4, 0.7, 1.0, 0.7)  # azul fantasma
		ghost.z_index        = z_index - 1
		get_parent().add_child(ghost)

		# Desvanecer y eliminar
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(ghost.queue_free)


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
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self) or get_tree() == null:
		return
	RunManager.player_died()   # ← Esta es la línea clave
	
	
## Empuja al jugador en una dirección sin aplicar daño.
## Usado por hazards que no dañan (ej. bala del tutorial de dash).
func apply_knockback(direction: Vector2, force: float, duration: float = 0.15) -> void:
	if direction == Vector2.ZERO:
		return
	knockback_velocity = direction.normalized() * force
	knockback_time_left = duration

func set_movement_locked(locked: bool) -> void:
	movement_locked = locked

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if dash_iframe_left > 0.0:
		return
	# Piedra Tsuru: esquivar con probabilidad
	if _dodge_chance > 0.0 and randf() < _dodge_chance:
		show_popup("ESQUIVAR", Color(0.4, 1.0, 0.6))
		return
	current_health = maxf(current_health - amount, 0.0)
	RunManager.player_current_health = current_health
	if current_health <= 0.0:
		_die()
