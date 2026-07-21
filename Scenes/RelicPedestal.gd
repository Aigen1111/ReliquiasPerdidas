# RelicPedestal.gd
# Pedestal en el lobby. Al presionar E abre el RelicCodex en modo selección.
# Muestra la reliquia actualmente equipada en este slot.
extends Node2D

var slot_idx:   int        = 0   # índice de este pedestal (0, 1, 2...)
var relic_id:   String     = ""
var relic_data: Dictionary = {}

var _player_in_range: bool    = false
var _codex:           Node    = null
var _visual:          ColorRect
var _label_name:      Label
var _label_effect:    Label
var _label_prompt:    Label


func setup(idx: int) -> void:
	slot_idx = idx
	if idx < RunManager.equipped_relics.size():
		relic_id   = RunManager.equipped_relics[idx]
		relic_data = MuseumData.get_relic(relic_id)
	else:
		relic_id   = ""
		relic_data = {}
	_refresh_visuals()


func _ready() -> void:
	_build_pedestal()
	_find_or_create_codex()


func _build_pedestal() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	shape.shape   = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

	_visual = ColorRect.new()
	_visual.size     = Vector2(140, 80)
	_visual.position = Vector2(-70, -95)
	add_child(_visual)

	_label_name = Label.new()
	_label_name.size                 = Vector2(136, 22)
	_label_name.position             = Vector2(-68, -93)
	_label_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_name.clip_text            = true
	_label_name.add_theme_font_size_override("font_size", 12)
	add_child(_label_name)

	_label_effect = Label.new()
	_label_effect.size                 = Vector2(132, 36)
	_label_effect.position             = Vector2(-66, -70)
	_label_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_effect.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_label_effect.modulate             = Color(0.75, 0.75, 0.75)
	_label_effect.add_theme_font_size_override("font_size", 10)
	add_child(_label_effect)

	var slot_lbl := Label.new()
	slot_lbl.text                 = "Slot %d" % (slot_idx + 1)
	slot_lbl.size                 = Vector2(136, 16)
	slot_lbl.position             = Vector2(-68, -30)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.modulate             = Color(0.5, 0.5, 0.5)
	slot_lbl.add_theme_font_size_override("font_size", 10)
	add_child(slot_lbl)

	_label_prompt = Label.new()
	_label_prompt.text                 = "[E] Cambiar reliquia"
	_label_prompt.size                 = Vector2(160, 18)
	_label_prompt.position             = Vector2(-80, -12)
	_label_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_prompt.modulate             = Color(1.0, 1.0, 0.5)
	_label_prompt.add_theme_font_size_override("font_size", 11)
	_label_prompt.hide()
	add_child(_label_prompt)

	_refresh_visuals()


func _find_or_create_codex() -> void:
	# Buscar el códex en el CanvasLayer HUD del lobby
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		_codex = hud.get_node_or_null("RelicCodex")
		if _codex == null:
			var codex_script: Script = load("res://Scenes/RelicCodex.gd")
			_codex = CanvasLayer.new()
			_codex.name = "RelicCodex"
			_codex.set_script(codex_script)
			hud.add_child(_codex)
	if _codex and _codex.has_signal("relic_selected"):
		if not _codex.relic_selected.is_connected(_on_relic_selected):
			_codex.relic_selected.connect(_on_relic_selected)


func _refresh_visuals() -> void:
	if _visual == null:
		return
	if relic_id == "":
		_visual.color        = Color(0.12, 0.12, 0.18, 0.85)
		_label_name.text     = "Vacío"
		_label_name.modulate = Color(0.4, 0.4, 0.4)
		_label_effect.text   = "Selecciona una reliquia"
	else:
		_visual.color        = Color(0.35, 0.28, 0.06, 0.9)
		_label_name.text     = relic_data.get("name", relic_id)
		_label_name.modulate = Color(1.0, 0.85, 0.2)
		_label_effect.text   = relic_data.get("effect", "")


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if Input.is_action_just_pressed("interact"):
		if _codex and _codex.has_method("open_lobby"):
			_codex.open_lobby(slot_idx)


func _on_relic_selected(selected_id: String) -> void:
	relic_id   = selected_id
	relic_data = MuseumData.get_relic(selected_id)

	while RunManager.equipped_relics.size() <= slot_idx:
		RunManager.equipped_relics.append("")
	RunManager.equipped_relics[slot_idx] = selected_id
	while not RunManager.equipped_relics.is_empty() and RunManager.equipped_relics.back() == "":
		RunManager.equipped_relics.pop_back()

	_refresh_visuals()
	var lobby := get_tree().current_scene
	if lobby and lobby.has_method("_update_hud"):
		lobby._update_hud()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_label_prompt.show()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_label_prompt.hide()
