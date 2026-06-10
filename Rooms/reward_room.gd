# reward_room.gd — Sala de recompensa (reliquia)
extends "res://Rooms/portal_room.gd"

@export var pedestal_offset: Vector2 = Vector2(0, -120)

var _relic_id:        String     = ""
var _relic_data:      Dictionary = {}
var _collected:       bool       = false
var _player_in_range: bool       = false
var _pedestal_node:   Node       = null


func _ready() -> void:
	_setup_portal_base()
	for child in get_children():
		if child.is_in_group("Enemy"):
			child.queue_free()
	await get_tree().process_frame
	_setup_pedestal()
	_open_portals()


func _process(delta: float) -> void:
	# Interacción con el pedestal
	if _player_in_range and not _collected and Input.is_action_just_pressed("interact"):
		_collect_relic()
		return
	# Delegar al base para la interacción con portales
	super._process(delta)


func _setup_pedestal() -> void:
	var all_ids: Array = MuseumData.get_all_relic_ids()
	_relic_id   = all_ids[randi() % all_ids.size()]
	_relic_data = MuseumData.get_relic(_relic_id)

	_pedestal_node = get_node_or_null("Pedestal")
	if _pedestal_node == null:
		_pedestal_node = _build_placeholder_pedestal()
		add_child(_pedestal_node)

	_refresh_pedestal_labels()

	if _pedestal_node.has_signal("body_entered"):
		_pedestal_node.body_entered.connect(_on_pedestal_entered)
	if _pedestal_node.has_signal("body_exited"):
		_pedestal_node.body_exited.connect(_on_pedestal_exited)


func _build_placeholder_pedestal() -> Area2D:
	var area := Area2D.new()
	area.name = "Pedestal"
	var player := _get_player()
	area.global_position = player.global_position + pedestal_offset if player else global_position
	area.collision_layer = 0
	area.collision_mask  = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape   = circle
	area.add_child(shape)

	var rect := ColorRect.new()
	rect.name     = "Visual"
	rect.color    = Color(1.0, 0.78, 0.1, 0.9)
	rect.size     = Vector2(32, 32)
	rect.position = Vector2(-16, -16)
	area.add_child(rect)

	var name_lbl := Label.new()
	name_lbl.name                 = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position             = Vector2(-70, -58)
	name_lbl.add_theme_font_size_override("font_size", 13)
	area.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.name                 = "StatusLabel"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.position             = Vector2(-70, -42)
	status_lbl.add_theme_font_size_override("font_size", 11)
	area.add_child(status_lbl)

	var prompt_lbl := Label.new()
	prompt_lbl.name                 = "PromptLabel"
	prompt_lbl.text                 = "[E] Recoger"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.position             = Vector2(-48, -22)
	prompt_lbl.add_theme_font_size_override("font_size", 12)
	prompt_lbl.hide()
	area.add_child(prompt_lbl)

	return area


func _refresh_pedestal_labels() -> void:
	if not _pedestal_node:
		return
	var name_lbl:   Label = _pedestal_node.get_node_or_null("NameLabel")
	var status_lbl: Label = _pedestal_node.get_node_or_null("StatusLabel")
	var is_known: bool = _relic_id in RunManager.unlocked_relics
	if name_lbl:
		name_lbl.text = _relic_data.get("name", _relic_id)
	if status_lbl:
		if is_known:
			status_lbl.text     = "★ Poder aumentado"
			status_lbl.modulate = Color(1.0, 0.8, 0.1)
		else:
			status_lbl.text     = "✦ Desconocida"
			status_lbl.modulate = Color(0.75, 0.75, 1.0)


func _collect_relic() -> void:
	_collected = true
	var is_new: bool = _relic_id not in RunManager.unlocked_relics
	if is_new:
		RunManager.unlock_relic(_relic_id)
	if _relic_id not in RunManager.active_relics:
		RunManager.active_relics.append(_relic_id)

	var visual:     ColorRect = _pedestal_node.get_node_or_null("Visual")     if _pedestal_node else null
	var status_lbl: Label     = _pedestal_node.get_node_or_null("StatusLabel") if _pedestal_node else null
	var prompt_lbl: Label     = _pedestal_node.get_node_or_null("PromptLabel") if _pedestal_node else null

	if visual:
		visual.color = Color(0.45, 0.45, 0.45, 0.4)
	if prompt_lbl:
		prompt_lbl.hide()
	if status_lbl:
		if is_new:
			status_lbl.text     = "¡Reliquia descubierta!"
			status_lbl.modulate = Color(0.3, 1.0, 0.4)
		else:
			status_lbl.text     = "Poder activado (+25%)"
			status_lbl.modulate = Color(1.0, 0.85, 0.2)


func _on_pedestal_entered(body: Node) -> void:
	if body.is_in_group("player") and not _collected:
		_player_in_range = true
		var lbl: Label = _pedestal_node.get_node_or_null("PromptLabel") if _pedestal_node else null
		if lbl:
			lbl.show()


func _on_pedestal_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		var lbl: Label = _pedestal_node.get_node_or_null("PromptLabel") if _pedestal_node else null
		if lbl:
			lbl.hide()


func _get_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] as Node2D if not nodes.is_empty() else null
