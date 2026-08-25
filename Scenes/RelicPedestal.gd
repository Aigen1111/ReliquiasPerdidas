# RelicPedestal.gd
# Pedestal en el lobby. Al presionar E abre el RelicCodex en modo selección.
# Muestra la reliquia actualmente equipada en este slot.
extends Node2D

var slot_idx:   int        = 0   # índice de este pedestal (0, 1, 2...)
var relic_id:   String     = ""
var relic_data: Dictionary = {}

var _player_in_range: bool    = false
var _codex:           Node    = null
var _visual:          TextureRect
var _label_name:      Label
var _label_effect:    Label
var _label_prompt:    Label

# Ajustá esta ruta a donde termine viviendo el archivo en tu proyecto.
const PEDESTAL_TEXTURE_PATH := "res://Assets/Paid/Museum_Black_Shadow_Singles_64.png"


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

	# Colisión sólida — sin esto el pedestal es solo un cartel, el jugador
	# camina encima como si no estuviera. Layer 1 = World (misma capa que
	# las paredes de MapBorder), así que el player ya la detecta sin
	# necesitar tocar nada de su collision_mask.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size       = Vector2(56, 36)
	body_shape.shape     = body_rect
	body_shape.position  = Vector2(0, -25)   # base del pedestal, no todo el cartel de arriba
	body.add_child(body_shape)
	add_child(body)

	_visual = TextureRect.new()
	var tex: Texture2D = load(PEDESTAL_TEXTURE_PATH)
	if tex != null:
		_visual.texture = tex
		_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_visual.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_visual.size     = Vector2(96, 96)
		_visual.position = Vector2(-48, -95)
	else:
		push_warning("RelicPedestal: no se encontró la textura en " + PEDESTAL_TEXTURE_PATH)
		_visual.size     = Vector2(96, 96)
		_visual.position = Vector2(-48, -95)
	add_child(_visual)

	_label_name = Label.new()
	_label_name.size                 = Vector2(136, 22)
	_label_name.position             = Vector2(-68, -93)
	_label_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_name.clip_text            = true
	_label_name.add_theme_font_size_override("font_size", 12)
	_label_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_name.add_theme_constant_override("outline_size", 5)
	add_child(_label_name)

	_label_effect = Label.new()
	_label_effect.size                 = Vector2(132, 36)
	_label_effect.position             = Vector2(-66, -70)
	_label_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_effect.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_label_effect.modulate             = Color(0.75, 0.75, 0.75)
	_label_effect.add_theme_font_size_override("font_size", 10)
	_label_effect.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_effect.add_theme_constant_override("outline_size", 4)
	add_child(_label_effect)

	var slot_lbl := Label.new()
	slot_lbl.text                 = "Slot %d" % (slot_idx + 1)
	slot_lbl.size                 = Vector2(136, 16)
	slot_lbl.position             = Vector2(-68, -30)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.modulate             = Color(0.5, 0.5, 0.5)
	slot_lbl.add_theme_font_size_override("font_size", 10)
	slot_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	slot_lbl.add_theme_constant_override("outline_size", 4)
	add_child(slot_lbl)

	_label_prompt = Label.new()
	_label_prompt.text                 = "[E] Cambiar reliquia"
	_label_prompt.size                 = Vector2(160, 18)
	_label_prompt.position             = Vector2(-80, -12)
	_label_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_prompt.modulate             = Color(1.0, 1.0, 0.5)
	_label_prompt.add_theme_font_size_override("font_size", 11)
	_label_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_prompt.add_theme_constant_override("outline_size", 4)
	_label_prompt.hide()
	add_child(_label_prompt)

	_refresh_visuals()


func _find_or_create_codex() -> void:
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
		_visual.modulate     = Color(0.55, 0.55, 0.65, 0.85)
		_label_name.text     = "Vacío"
		_label_name.modulate = Color(0.4, 0.4, 0.4)
		_label_effect.text   = "Selecciona una reliquia"
	else:
		_visual.modulate     = Color(1.15, 1.05, 0.75, 1.0)
		_label_name.text     = relic_data.get("name", relic_id)
		_label_name.modulate = Color(1.0, 0.85, 0.2)
		_label_effect.text   = relic_data.get("effect", "")


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if Input.is_action_just_pressed("interact"):
		if _codex and _codex.has_method("open_lobby"):
			_codex.open_lobby(slot_idx)


func _on_relic_selected(selected_id: String, slot_idx_selected: int) -> void:
	# El códex es compartido por los 3 pedestales — sin este guard, los 3
	# reaccionaban a la vez a cualquier selección, sin importar cuál lo abrió.
	if slot_idx_selected != slot_idx:
		return

	while RunManager.equipped_relics.size() <= slot_idx:
		RunManager.equipped_relics.append("")

	# Si esa reliquia ya estaba equipada en otro pedestal, la sacamos de ahí
	# — no tiene sentido tenerla dos veces, y así el jugador "mueve" una
	# reliquia de un slot a otro con un solo clic en vez de que se bloquee.
	for i in range(RunManager.equipped_relics.size()):
		if i != slot_idx and RunManager.equipped_relics[i] == selected_id:
			RunManager.equipped_relics[i] = ""

	RunManager.equipped_relics[slot_idx] = selected_id
	while not RunManager.equipped_relics.is_empty() and RunManager.equipped_relics.back() == "":
		RunManager.equipped_relics.pop_back()

	# Notificar a TODOS los pedestales (incluido este) para que relean el
	# estado real desde RunManager — si le robamos la reliquia a otro slot,
	# ese pedestal necesita enterarse y refrescar su propio cartel.
	var container := get_parent()
	if container:
		for sibling in container.get_children():
			if sibling.has_method("setup"):
				sibling.setup(sibling.slot_idx)

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
