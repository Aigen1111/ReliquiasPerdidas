# Portal.gd  (actualizado — pasa el area_id al RunManager)
extends Area2D

@export var area_id: String = "bribri"
@onready var prompt_label: Label = $PromptLabel
var player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.hide()

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		RunManager.start_run(area_id)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		prompt_label.show()
		var tween := create_tween()
		tween.tween_property(prompt_label, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(prompt_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt_label.hide()
