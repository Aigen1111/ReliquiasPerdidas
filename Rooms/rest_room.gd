# rest_room.gd — Sala de descanso
extends "res://Rooms/portal_room.gd"

@export var heal_percent: float = 0.30
@export var heal_offset:  Vector2 = Vector2(0, -120)

var _healed:          bool = false
var _player_in_range: bool = false
var _source_node:     Node = null


func _ready() -> void:
	_setup_portal_base()
	# Limpiar enemigos huérfanos por si acaso
	for child in get_children():
		if child.is_in_group("Enemy"):
			child.queue_free()
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or get_tree() == null:
		return
	if not is_instance_valid(self):
		return
	_setup_heal_source()
	# La fuente de curación no bloquea la salida — portales abiertos de entrada
	_open_portals()


func _process(delta: float) -> void:
	# Interacción con la fuente
	if _player_in_range and not _healed and Input.is_action_just_pressed("interact"):
		_apply_heal()
		return
	# Delegar al base para la interacción con portales
	super._process(delta)


func _setup_heal_source() -> void:
	_source_node = get_node_or_null("HealSource")
	if _source_node == null:
		_source_node = _build_placeholder_source()
		add_child(_source_node)
	if _source_node.has_signal("body_entered"):
		_source_node.body_entered.connect(_on_source_entered)
	if _source_node.has_signal("body_exited"):
		_source_node.body_exited.connect(_on_source_exited)


func _build_placeholder_source() -> Area2D:
	var area := Area2D.new()
	area.name = "HealSource"
	var player := _get_player()
	area.global_position = player.global_position + heal_offset if player else global_position
	area.collision_layer = 0
	area.collision_mask  = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape   = circle
	area.add_child(shape)

	var rect := ColorRect.new()
	rect.name     = "Visual"
	rect.color    = Color(0.2, 0.55, 1.0, 0.85)
	rect.size     = Vector2(36, 36)
	rect.position = Vector2(-18, -18)
	area.add_child(rect)

	var lbl := Label.new()
	lbl.name                 = "PromptLabel"
	lbl.text                 = "[E] Descansar"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position             = Vector2(-52, -44)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.hide()
	area.add_child(lbl)

	return area


func _apply_heal() -> void:
	_healed = true
	var base_amount: float = RunManager.player_max_health * heal_percent
	var relic: Dictionary = MuseumData.get_relic("vasija_cacao")
	if RunManager.has_active_relic("vasija_cacao") and relic.has("bonus_value"):
		base_amount *= (1.0 + float(relic["bonus_value"]))
	var amount: int = int(base_amount)
	var player := _get_player()
	if player and player.has_method("heal"):
		player.heal(amount)
	RunManager.player_current_health = minf(RunManager.player_current_health + float(amount), RunManager.player_max_health)

	var rect: ColorRect = _source_node.get_node_or_null("Visual") if _source_node else null
	if rect:
		rect.color = Color(0.3, 0.3, 0.5, 0.5)
	var lbl: Label = _source_node.get_node_or_null("PromptLabel") if _source_node else null
	if lbl:
		lbl.text = "+%d vida ✓" % amount
		lbl.show()


func _on_source_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	if not _healed:
		var lbl: Label = _source_node.get_node_or_null("PromptLabel") if _source_node else null
		if lbl:
			lbl.show()


func _on_source_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	if not _healed:
		var lbl: Label = _source_node.get_node_or_null("PromptLabel") if _source_node else null
		if lbl:
			lbl.hide()


func _get_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] as Node2D if not nodes.is_empty() else null
