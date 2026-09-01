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

const WEAPONS := {
	"lanza":     {"color": Color(0.6, 0.4, 0.2),   "size": Vector2(4, 30)},
	"escudo":    {"color": Color(0.4, 0.3, 0.15),  "size": Vector2(16, 22)},
	"cerbatana": {"color": Color(0.3, 0.2, 0.1),   "size": Vector2(3, 24)},
	"arco":      {"color": Color(0.55, 0.35, 0.15),"size": Vector2(4, 26)},
}


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
	if not WEAPONS.has(weapon_id):
		return
	var data: Dictionary = WEAPONS[weapon_id]
	var sz: Vector2 = data["size"]

	var weapon := ColorRect.new()
	weapon.name = "WeaponPlaceholder"
	weapon.size = sz
	weapon.position = Vector2(10, -sz.y * 0.5)   # al costado del cuerpo
	weapon.color = data["color"]
	weapon.z_index = 5
	enemy.add_child(weapon)
