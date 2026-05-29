extends Area2D

signal player_entered_door

@export var next_room_path: String = ""
var is_locked: bool = true
var player_inside: bool = false

@onready var visual = $ColorRect
@onready var prompt_label: Label = $PromptLabel

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	lock()

func _process(_delta: float) -> void:
	if player_inside and not is_locked and Input.is_action_just_pressed("interact"):
		emit_signal("player_entered_door")

func lock():
	is_locked = true
	if visual:
		visual.color = Color.RED
	_hide_prompt()

func unlock():
	is_locked = false
	if visual:
		visual.color = Color.GREEN
	# Si el jugador ya está dentro cuando se abre, mostrar el prompt
	if player_inside:
		_show_prompt()

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
