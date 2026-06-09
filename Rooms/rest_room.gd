# rest_room.gd — Sala de descanso
# ─────────────────────────────────────────────────────────────────────────────
# La curación NO es automática al entrar. El jugador debe acercarse a la
# fuente/altar (Area2D llamado "HealSource") y presionar E para activarla.
# Si no existe ese nodo, se crea un placeholder en el centro de la sala.
#
# Bonus reliquia "vasija_cacao": +30% más de curación.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

@export var heal_percent: float = 0.30   # % de vida máxima que restaura

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var door: Node = get_node_or_null("Door")

# ── Estado ────────────────────────────────────────────────────────────────
var _healed:         bool  = false
var _player_in_range: bool = false
var _source_node:    Node  = null


func _ready() -> void:
	if door and door.has_method("unlock"):
		door.unlock()
	if door:
		door.player_entered_door.connect(_on_player_entered_door)

	await get_tree().process_frame
	_setup_heal_source()


func _process(_delta: float) -> void:
	if _player_in_range and not _healed:
		if Input.is_action_just_pressed("interact"):
			_apply_heal()


# ── Setup de la fuente ────────────────────────────────────────────────────

func _setup_heal_source() -> void:
	_source_node = get_node_or_null("HealSource")

	if _source_node == null:
		# Crear placeholder: Area2D con ColorRect azul y Label
		_source_node = _build_placeholder_source()
		add_child(_source_node)

	# Conectar señales de área
	if _source_node.has_signal("body_entered"):
		_source_node.body_entered.connect(_on_source_entered)
	if _source_node.has_signal("body_exited"):
		_source_node.body_exited.connect(_on_source_exited)


func _build_placeholder_source() -> Area2D:
	var area := Area2D.new()
	area.name = "HealSource"
	# Posición central de la sala (ajustar según tu layout)
	area.position = Vector2(0, -40)
	area.collision_layer = 0
	area.collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	area.add_child(shape)

	# Visual placeholder: rectángulo azul
	var rect := ColorRect.new()
	rect.color = Color(0.2, 0.5, 1.0, 0.85)
	rect.size = Vector2(32, 32)
	rect.position = Vector2(-16, -16)
	area.add_child(rect)

	# Label de instrucción
	var lbl := Label.new()
	lbl.name = "PromptLabel"
	lbl.text = "[E] Descansar"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-50, -48)
	lbl.hide()
	area.add_child(lbl)

	return area


# ── Curación ──────────────────────────────────────────────────────────────

func _apply_heal() -> void:
	_healed = true

	var base_amount: float = RunManager.player_max_health * heal_percent

	# Bonus reliquia vasija_cacao
	var relic := MuseumData.get_relic("vasija_cacao")
	if RunManager.has_active_relic("vasija_cacao") and relic.has("bonus_value"):
		base_amount *= (1.0 + float(relic["bonus_value"]))

	var amount: int = int(base_amount)

	var player := _get_player()
	if player and player.has_method("heal"):
		player.heal(amount)
	RunManager.player_current_health = minf(
		RunManager.player_current_health + float(amount),
		RunManager.player_max_health
	)

	# Feedback: cambiar color del placeholder y ocultar prompt
	var rect := _source_node.get_node_or_null("ColorRect") if _source_node else null
	if rect:
		rect.color = Color(0.4, 0.4, 0.4, 0.5)
	var lbl := _source_node.get_node_or_null("PromptLabel") if _source_node else null
	if lbl:
		lbl.text = "+%d vida" % amount
		lbl.show()


# ── Señales de área ────────────────────────────────────────────────────────

func _on_source_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if not _healed:
			var lbl := _source_node.get_node_or_null("PromptLabel") if _source_node else null
			if lbl:
				lbl.show()


func _on_source_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if not _healed:
			var lbl := _source_node.get_node_or_null("PromptLabel") if _source_node else null
			if lbl:
				lbl.hide()


func _on_player_entered_door() -> void:
	RunManager.advance_room()


func _get_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D
