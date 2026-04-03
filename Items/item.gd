extends Area2D
class_name Item

@export var item_name: String = ""
@export_multiline var description: String = ""
@export var hover_height: float = 6.0
@export var hover_speed: float = 2.5

var base_position: Vector2
var hover_time: float = 0.0


func _ready() -> void:
	base_position = position

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	hover_time += delta * hover_speed
	position = base_position + Vector2(0.0, sin(hover_time) * hover_height)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	apply_effect(body)
	queue_free()


func apply_effect(player):
	pass
