extends Sprite2D

@export var fire_cooldown: float = 0.12
@export var bullet_scene: PackedScene

@onready var marker_2d: Marker2D = $Marker2D
@onready var shot_audio_player: Node = get_node_or_null("Shoot_sound")

var cooldown_left := 0.0


func _process(delta: float) -> void:
	cooldown_left = max(cooldown_left - delta, 0.0)

	var aim_direction := get_global_mouse_position() - global_position
	if aim_direction == Vector2.ZERO:
		return

	look_at(global_position + aim_direction)
	flip_v = aim_direction.x < 0.0


func shoot() -> void:
	if cooldown_left > 0.0 or bullet_scene == null:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var aim_direction := Vector2.RIGHT.rotated(global_rotation)
	if aim_direction == Vector2.ZERO:
		return

	var shooter := get_parent() as PhysicsBody2D
	var new_bullet := bullet_scene.instantiate() as Node2D
	if new_bullet == null:
		return

	current_scene.add_child(new_bullet)
	new_bullet.global_position = marker_2d.global_position

	if new_bullet.has_method("setup"):
		new_bullet.call("setup", aim_direction, shooter)

	# Flecha del Awá: +15% daño de proyectiles
	if RunManager.has_active_relic("flecha_awa"):
		var relic: Dictionary = MuseumData.get_relic("flecha_awa")
		new_bullet.damage *= (1.0 + float(relic.get("bonus_value", 0.0)))

	_play_shot_sound()
	cooldown_left = fire_cooldown


func _play_shot_sound() -> void:
	if shot_audio_player == null:
		return

	if shot_audio_player.has_method("play"):
		shot_audio_player.call("play")
