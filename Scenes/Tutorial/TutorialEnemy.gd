# TutorialEnemy.gd
# Enemigo placeholder para el tutorial.
# Recibe daño y muere, pero NO daña al jugador.
# Usa el mismo sistema de señal "died" que enemy.gd para compatibilidad.

extends CharacterBody2D

signal died

const HEALTH:    float = 30.0
const COLOR_OK:  Color = Color(0.3, 0.7, 0.3)   # verde
const COLOR_HIT: Color = Color(1.0, 0.3, 0.3)   # rojo al recibir daño
const BOX_TEXTURE: Texture2D = preload("res://Assets/Paid/Crates/crate_broken.png")

var current_health: float = HEALTH
var _label: Label
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("Enemy")
	_build_visual()


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = BOX_TEXTURE
	add_child(_sprite)

	# "?" encima para que sea obvio que es un dummy
	_label = Label.new()
	_label.text                = "?"
	_label.size                = Vector2(28, 28)
	_label.position            = Vector2(-14, -18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(_label)

	# Collision
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	col.shape  = shape
	add_child(col)


func take_damage(amount: float) -> void:
	current_health -= amount
	# Flash rojo
	_sprite.modulate = COLOR_HIT / COLOR_OK
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self):
		return
	if current_health > 0:
		_sprite.modulate = COLOR_HIT / COLOR_OK
	else:
		_die()


func _die() -> void:
	emit_signal("died")
	queue_free()
