# Portal.gd
# ─────────────────────────────────────────────────────────────────────────────
# Puerta/portal del lobby que inicia un run cuando el jugador presiona E cerca.
#
# ESTRUCTURA DE ESCENA (Portal.tscn):
#   Portal (Area2D)  ← este script
#   ├── CollisionShape2D    (CircleShape2D, radio ~60px — zona de detección)
#   ├── Sprite2D / AnimatedSprite2D   (visual del portal, placeholder por ahora)
#   └── PromptLabel (Label)           (texto "Presiona E para entrar", centrado)
# ─────────────────────────────────────────────────────────────────────────────
extends Area2D


@onready var prompt_label: Label = $PromptLabel

var player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.hide()


func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		RunManager.start_run()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		prompt_label.show()
		# Pequeña animación de escala para que llame la atención
		var tween := create_tween()
		tween.tween_property(prompt_label, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(prompt_label, "scale", Vector2(1.0, 1.0), 0.1)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt_label.hide()
