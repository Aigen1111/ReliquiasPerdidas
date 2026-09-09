extends Area2D

signal player_entered_door

@export var next_room_path: String = ""
var is_locked: bool = true
var player_inside: bool = false

@onready var visual = _find_visual()
@onready var prompt_label: Label = $PromptLabel

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	lock()

func _find_visual() -> Node:
	# Door.tscn (la puerta genérica de las salas) usa un ColorRect rojo/verde.
	# Door_Portal.tscn (tutoriales y sala del boss) usa el mismo sprite del
	# portal del Lobby, tintado en vez de recoloreado — mismo script para
	# ambas variantes, así el resto de la lógica no se duplica.
	if has_node("ColorRect"):
		return $ColorRect
	if has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D
	return null

func _process(_delta: float) -> void:
	if player_inside and not is_locked and Input.is_action_just_pressed("interact"):
		emit_signal("player_entered_door")

func lock():
	is_locked = true
	_apply_visual_state()
	_hide_prompt()

func unlock():
	is_locked = false
	_apply_visual_state()
	# Si el jugador ya está dentro cuando se abre, mostrar el prompt
	if player_inside:
		_show_prompt()

func _apply_visual_state() -> void:
	if visual == null:
		return
	if visual is ColorRect:
		visual.color = Color.RED if is_locked else Color.GREEN
	else:
		# AnimatedSprite2D del portal: mismo lenguaje visual (rojizo=bloqueado,
		# verdoso=abierto) pero conservando el sprite real en vez de un color plano.
		visual.modulate = Color(1.6, 0.35, 0.35) if is_locked else Color(0.55, 1.6, 0.6)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_inside = true
		if not is_locked:
			_show_prompt()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_inside = false
		_hide_prompt()

func _show_prompt() -> void:
	if is_instance_valid(prompt_label):
		prompt_label.show()

func _hide_prompt() -> void:
	if is_instance_valid(prompt_label):
		prompt_label.hide()
