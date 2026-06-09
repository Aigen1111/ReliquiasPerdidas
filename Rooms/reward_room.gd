# reward_room.gd — Sala de recompensa (reliquia/item)
# ─────────────────────────────────────────────────────────────────────────────
# Al entrar la sala hay un pedestal en el centro con una reliquia aleatoria.
# El jugador se acerca y presiona E para recogerla.
#
# Si la reliquia NO ha sido descubierta antes:
#   → Se desbloquea en RunManager.unlocked_relics (permanente)
#   → Se activa para este run
#   → El pedestal muestra "¡Nueva reliquia descubierta!"
#
# Si ya fue descubierta:
#   → Se activa para este run con efecto boosteado (+25%)
#   → El pedestal muestra "Reliquia conocida — poder aumentado"
#
# La puerta se desbloquea desde el inicio (el jugador puede ignorar el pedestal).
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var door: Node = get_node_or_null("Door")

# ── Estado ────────────────────────────────────────────────────────────────
var _relic_id:         String = ""
var _relic_data:       Dictionary = {}
var _collected:        bool = false
var _player_in_range:  bool = false
var _pedestal_node:    Node = null


func _ready() -> void:
	if door and door.has_method("unlock"):
		door.unlock()
	if door:
		door.player_entered_door.connect(_on_player_entered_door)

	await get_tree().process_frame
	_setup_pedestal()


func _process(_delta: float) -> void:
	if _player_in_range and not _collected:
		if Input.is_action_just_pressed("interact"):
			_collect_relic()


# ── Setup del pedestal ────────────────────────────────────────────────────

func _setup_pedestal() -> void:
	# Elegir reliquia aleatoria del pool disponible en MuseumData
	var all_ids: Array = MuseumData.get_all_relic_ids()
	_relic_id   = all_ids[randi() % all_ids.size()]
	_relic_data = MuseumData.get_relic(_relic_id)

	_pedestal_node = get_node_or_null("Pedestal")
	if _pedestal_node == null:
		_pedestal_node = _build_placeholder_pedestal()
		add_child(_pedestal_node)

	# Actualizar label del pedestal con nombre y estado
	_refresh_pedestal_label()

	if _pedestal_node.has_signal("body_entered"):
		_pedestal_node.body_entered.connect(_on_pedestal_entered)
	if _pedestal_node.has_signal("body_exited"):
		_pedestal_node.body_exited.connect(_on_pedestal_exited)


func _build_placeholder_pedestal() -> Area2D:
	var area := Area2D.new()
	area.name = "Pedestal"
	area.position = Vector2(0, -40)
	area.collision_layer = 0
	area.collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	area.add_child(shape)

	# Color dorado para pedestal
	var rect := ColorRect.new()
	rect.name = "Visual"
	rect.color = Color(1.0, 0.8, 0.1, 0.9)
	rect.size = Vector2(28, 28)
	rect.position = Vector2(-14, -14)
	area.add_child(rect)

	# Label nombre reliquia
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(-70, -56)
	name_lbl.add_theme_font_size_override("font_size", 12)
	area.add_child(name_lbl)

	# Label estado (nueva / conocida)
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.position = Vector2(-70, -40)
	status_lbl.add_theme_font_size_override("font_size", 11)
	area.add_child(status_lbl)

	# Label prompt E
	var prompt_lbl := Label.new()
	prompt_lbl.name = "PromptLabel"
	prompt_lbl.text = "[E] Recoger"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.position = Vector2(-50, -24)
	prompt_lbl.hide()
	area.add_child(prompt_lbl)

	return area


func _refresh_pedestal_label() -> void:
	if _pedestal_node == null:
		return

	var name_lbl  := _pedestal_node.get_node_or_null("NameLabel")
	var status_lbl := _pedestal_node.get_node_or_null("StatusLabel")

	var display_name: String = _relic_data.get("name", _relic_id)
	var is_known: bool = _relic_id in RunManager.unlocked_relics

	if name_lbl:
		name_lbl.text = display_name

	if status_lbl:
		if is_known:
			status_lbl.text = "★ Poder aumentado"
			status_lbl.modulate = Color(0.9, 0.75, 0.1)
		else:
			status_lbl.text = "✦ Desconocida"
			status_lbl.modulate = Color(0.8, 0.8, 1.0)


# ── Recolección ───────────────────────────────────────────────────────────

func _collect_relic() -> void:
	_collected = true

	var is_new: bool = _relic_id not in RunManager.unlocked_relics

	# Desbloquear permanentemente si es nueva
	if is_new:
		RunManager.unlock_relic(_relic_id)

	# Activar para este run
	if _relic_id not in RunManager.active_relics:
		RunManager.active_relics.append(_relic_id)

	# Feedback visual
	var visual    := _pedestal_node.get_node_or_null("Visual") if _pedestal_node else null
	var name_lbl  := _pedestal_node.get_node_or_null("NameLabel") if _pedestal_node else null
	var status_lbl := _pedestal_node.get_node_or_null("StatusLabel") if _pedestal_node else null
	var prompt_lbl := _pedestal_node.get_node_or_null("PromptLabel") if _pedestal_node else null

	if visual:
		visual.color = Color(0.5, 0.5, 0.5, 0.4)
	if prompt_lbl:
		prompt_lbl.hide()
	if status_lbl:
		if is_new:
			status_lbl.text = "¡Reliquia descubierta!"
			status_lbl.modulate = Color(0.4, 1.0, 0.4)
		else:
			status_lbl.text = "Poder activado (+25%)"
			status_lbl.modulate = Color(1.0, 0.85, 0.2)
	if name_lbl:
		name_lbl.text = _relic_data.get("name", _relic_id)


# ── Señales de área ────────────────────────────────────────────────────────

func _on_pedestal_entered(body: Node) -> void:
	if body.is_in_group("player") and not _collected:
		_player_in_range = true
		var lbl := _pedestal_node.get_node_or_null("PromptLabel") if _pedestal_node else null
		if lbl:
			lbl.show()


func _on_pedestal_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		var lbl := _pedestal_node.get_node_or_null("PromptLabel") if _pedestal_node else null
		if lbl:
			lbl.hide()


func _on_player_entered_door() -> void:
	RunManager.advance_room()
