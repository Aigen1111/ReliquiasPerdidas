# EnemyLoadout.gd
# Máscaras: sprites reales (Assets/Paid/EnemySprites/Masks/), con textura
# distinta por dirección (up/down/left) — "right" reutiliza la de "left"
# con flip_h, ya que las hojas de origen no traen perfil derecho aparte.
# Armas: siguen siendo placeholders geométricos hasta conseguir arte real.
class_name EnemyLoadout
extends RefCounted

const MASK_TEXTURE_DIR := "res://Assets/Paid/EnemySprites/Masks/"

# up/down: de frente (no hay arte de "espalda" en las hojas de origen, así
# que reutilizan el mismo archivo). left: perfil real. right: el mismo
# archivo de "left" con flip_h — ver _apply_mask_direction().
const MASKS := {
	"jaguar": {
		"up": "jaguar.png", "down": "jaguar_down.png",
		"left": "jaguar_left.png", "right": "jaguar_right.png",
	},
	"danta": {
		"up": "danta.png", "down": "danta.png", "left": "danta_left.png",
	},
	"harpia": {
		"up": "harpia.png", "down": "harpia.png", "left": "harpia_left.png",
	},
	"zopilote": {
		"up": "zopilote.png", "down": "zopilote.png", "left": "zopilote_left.png",
	},
}

const WEAPON_TEXTURES := {
	"lanza":     "res://Assets/Paid/Weapons/lanza.png",
	"escudo":    "res://Assets/Paid/Weapons/Escudo.png",
	"cerbatana": "res://Assets/Paid/Weapons/cerbatana.png",
	"honda":     "res://Assets/Paid/Weapons/honda.png",
}

# Escala de arranque por arma — los PNG originales son gigantes (300-1600px),
# hay que aplastarlos bastante para que se vean proporcionados al enemigo
# (32x32px). Ajustá a ojo si hace falta.
const WEAPON_SCALE := {
	"lanza":     0.030,
	"escudo":    0.05,
	"cerbatana": 0.03,
	"honda":     0.03,
}

const WEAPON_ORBIT_RADIUS: float = 22.0
const WEAPON_ORBIT_PERIOD: float = 2.2   # segundos por vuelta completa


static func attach(enemy: Node2D, mask_id: String, weapon_id: String) -> void:
	#_attach_mask(enemy, mask_id)
	_attach_weapon(enemy, weapon_id)


static func _attach_mask(enemy: Node2D, mask_id: String) -> void:
	if not MASKS.has(mask_id):
		return

	var mask := TextureRect.new()
	mask.name = "Mask"
	mask.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mask.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mask.size     = Vector2(22, 18)   # más grande que el placeholder viejo — a 14x10 el detalle se perdía
	mask.position = Vector2(-11, -9)  # AnimatedSprite2D no tiene offset -> el nodo está centrado en el
									   # frame (16x32 centrado en el origen, de y=-16 a y=+16). y=-9 fue
									   # ajustado a ojo contra el sprite real para que caiga en la cara.
	mask.z_index  = 5
	enemy.add_child(mask)
	_apply_mask_direction(mask, mask_id, "down")   # mismo default que animated_sprite ("idle_down")


## Llamado por enemy.gd cada vez que cambia _facing_dir, para que la máscara
## gire junto con el cuerpo. dir_name: "up" | "down" | "left" | "right".
static func update_mask_direction(enemy: Node2D, mask_id: String, dir_name: String) -> void:
	if not MASKS.has(mask_id):
		return
	var mask := enemy.get_node_or_null("Mask") as TextureRect
	if mask == null:
		return
	_apply_mask_direction(mask, mask_id, dir_name)


static func _apply_mask_direction(mask: TextureRect, mask_id: String, dir_name: String) -> void:
	var dirs: Dictionary = MASKS[mask_id]
	var file: String = ""
	var flip := false

	if dir_name == "right" and dirs.has("right"):
		# Algunos animales (jaguar) sí tienen un dibujo propio para "right",
		# no todos dependen de espejar "left".
		file = dirs["right"]
	elif dir_name == "right":
		file = dirs.get("left", dirs.get("down", ""))
		flip = true
	else:
		file = dirs.get(dir_name, dirs.get("down", ""))

	if file == "":
		return
	var tex: Texture2D = load(MASK_TEXTURE_DIR + file)
	if tex == null:
		push_warning("EnemyLoadout: no se encontró '%s' en %s" % [file, MASK_TEXTURE_DIR])
		return
	mask.texture = tex
	mask.flip_h  = flip

## Textura circular suave para las partículas — sin esto, CPUParticles2D
## dibuja un punto de 1-2px que casi no se nota.
static func _make_particle_texture() -> Texture2D:
	var size := 10
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var d: float = Vector2(x, y).distance_to(center) / (size / 2.0)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func attach_corruption_particles(enemy: Node2D) -> void:
	var particles := CPUParticles2D.new()
	particles.name       = "CorruptionParticles"
	particles.texture    = _make_particle_texture()
	particles.amount     = 6
	particles.lifetime   = 1.6
	particles.randomness = 0.6
	particles.z_index    = 4   # delante del cuerpo (z=0), detrás del arma (z=5)

	particles.direction              = Vector2(0, -1)
	particles.spread                 = 25.0
	particles.initial_velocity_min   = 3.0
	particles.initial_velocity_max   = 8.0
	particles.gravity                = Vector2(0, -5)   # negativo = flotan hacia arriba
	particles.scale_amount_min       = 1.6
	particles.scale_amount_max       = 2.8
	particles.emission_shape         = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0

	# se desvanecen con el tiempo de vida (alpha 1.0 -> 0.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.65, 0.1, 0.55, 1.0))
	ramp.set_color(1, Color(0.65, 0.1, 0.55, 0.0))
	particles.color_ramp = ramp

	particles.position = Vector2(0, -6)   # centrado en el torso
	particles.emitting = true
	enemy.add_child(particles)
	
	

static func _attach_weapon(enemy: Node2D, weapon_id: String) -> void:
	if not WEAPON_TEXTURES.has(weapon_id):
		return
	var tex: Texture2D = load(WEAPON_TEXTURES[weapon_id])
	if tex == null:
		return

	var scale_factor: float = WEAPON_SCALE.get(weapon_id, 0.04)

	var orbit := Node2D.new()
	orbit.name = "WeaponOrbit"
	orbit.set_meta("weapon_id", weapon_id)
	enemy.add_child(orbit)

	var sprite := Sprite2D.new()
	sprite.name    = "WeaponSprite"
	sprite.texture = tex
	sprite.scale   = Vector2.ONE * scale_factor
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 5
	sprite.offset  = Vector2.ZERO 
	orbit.add_child(sprite)

	if weapon_id == "escudo":
		sprite.position = Vector2(0, -18)
		# Cambiar a -PI / 2.0 invierte el escudo para que no esté boca abajo
		sprite.rotation = -PI / 2.0
		orbit.set_meta("muzzle_local", Vector2.ZERO)
		
	elif weapon_id == "honda":
		sprite.position = Vector2(0, -18)
		orbit.set_meta("muzzle_local", Vector2.ZERO)
		
	else:
		sprite.offset = Vector2(0, -tex.get_size().y / 2.0)
		sprite.position = Vector2(0, -WEAPON_ORBIT_RADIUS)
		var weapon_length = tex.get_size().y * scale_factor
		orbit.set_meta("muzzle_local", Vector2(0, -weapon_length))
		
		# Crear hitbox dinámico si es una lanza
		if weapon_id == "lanza":
			var hitbox := Area2D.new()
			hitbox.name = "WeaponHitbox"
			hitbox.collision_layer = 0  # No emite colisión propia
			hitbox.collision_mask = 1   # Detecta la capa del jugador (Capa 1)
			
			var shape := CollisionShape2D.new()
			var capsule := CapsuleShape2D.new()
			capsule.radius = 6.0        # Un poco más gruesa para asegurar el impacto
			capsule.height = weapon_length
			shape.shape = capsule
			
			shape.position = Vector2(0, -WEAPON_ORBIT_RADIUS - (weapon_length / 2.0))
			hitbox.add_child(shape)
			orbit.add_child(hitbox)
			
			# Conecta con el nombre correcto de tu función en el lancero
			if enemy.has_method("_on_hit_body_entered"):
				hitbox.body_entered.connect(enemy._on_hit_body_entered)
			elif enemy.has_method("_on_body_entered"):
				hitbox.body_entered.connect(enemy._on_body_entered)
			
## Rota el arma para que apunte hacia el jugador. Se llama todos los frames
## (ver enemy.gd _physics_process).
static func update_weapon_aim(enemy: Node2D) -> void:
	var orbit := enemy.get_node_or_null("WeaponOrbit") as Node2D
	if orbit == null: return
	
	var players := enemy.get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	
	var player: Node2D = players[0]
	var to_player: Vector2 = player.global_position - orbit.global_position
	
	var weapon_id: String = orbit.get_meta("weapon_id", "")
	var sprite := orbit.get_node_or_null("WeaponSprite") as Sprite2D
	
	if weapon_id == "honda":
		# La honda no orbita, se queda recta y cambia de lado del cuerpo
		orbit.rotation = 0.0
		if sprite:
			sprite.flip_h = to_player.x < 0
			sprite.position = Vector2(-15, 0) if to_player.x < 0 else Vector2(15, 0)
	else:
		# Lanzas, escudos y cerbatanas orbitan normalmente
		orbit.rotation = to_player.angle() + PI / 2.0
		
		if weapon_id == "escudo" and sprite:
			# flip_v corrige que el escudo no se vea de cabeza hacia la izquierda
			sprite.flip_v = to_player.x < 0

static func get_weapon_muzzle_position(enemy: Node2D) -> Vector2:
	var orbit := enemy.get_node_or_null("WeaponOrbit") as Node2D
	if orbit == null or not orbit.has_meta("muzzle_local"):
		return enemy.global_position
	var local_tip: Vector2 = orbit.get_meta("muzzle_local")
	return orbit.global_position + local_tip.rotated(orbit.rotation)
