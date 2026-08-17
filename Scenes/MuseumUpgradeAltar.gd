# MuseumUpgradeAltar.gd
# Altar de mejora del museo, en el Lobby. Cada nivel (1→2→3) habilita un
# pedestal más de reliquia equipable. Los niveles/costos ya viven en
# RunManager (museum_level, MUSEUM_MAX_LEVEL, MUSEUM_UPGRADE_COSTS) — este
# script solo es la interfaz en el mundo para gastar el oro y subir.
extends Node2D

var _player_in_range: bool = false
var _visual:         ColorRect
var _label_title:    Label
var _label_status:   Label
var _label_prompt:   Label
var _feedback_label: Label


func _ready() -> void:
	_build_altar()
	RunManager.museum_upgraded.connect(_on_museum_upgraded)
	RunManager.gold_changed.connect(_on_gold_changed)
	_refresh_visuals()


func _build_altar() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	shape.shape   = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

	_visual = ColorRect.new()
	_visual.size     = Vector2(170, 96)
	_visual.position = Vector2(-85, -106)
	add_child(_visual)

	_label_title = Label.new()
	_label_title.text                 = "Altar Ancestral"
	_label_title.size                 = Vector2(166, 20)
	_label_title.position             = Vector2(-83, -104)
	_label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_title.add_theme_font_size_override("font_size", 12)
	add_child(_label_title)

	_label_status = Label.new()
	_label_status.size                 = Vector2(162, 44)
	_label_status.position             = Vector2(-81, -80)
	_label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_status.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_label_status.modulate             = Color(0.85, 0.85, 0.85)
	_label_status.add_theme_font_size_override("font_size", 10)
	add_child(_label_status)

	_label_prompt = Label.new()
	_label_prompt.text                 = "[E] Mejorar museo"
	_label_prompt.size                 = Vector2(190, 18)
	_label_prompt.position             = Vector2(-95, -14)
	_label_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_prompt.modulate             = Color(1.0, 1.0, 0.5)
	_label_prompt.add_theme_font_size_override("font_size", 11)
	_label_prompt.hide()
	add_child(_label_prompt)

	_feedback_label = Label.new()
	_feedback_label.size                 = Vector2(190, 18)
	_feedback_label.position             = Vector2(-95, 8)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 11)
	_feedback_label.hide()
	add_child(_feedback_label)


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if Input.is_action_just_pressed("interact"):
		_try_upgrade()


func _try_upgrade() -> void:
	if not RunManager.can_upgrade_museum():
		_show_feedback("Museo al nivel máximo", Color(0.7, 0.7, 0.7))
		return

	var cost: int = RunManager.get_museum_upgrade_cost()
	if RunManager.get_display_gold() < cost:
		_show_feedback("Oro insuficiente (%d)" % cost, Color(1.0, 0.4, 0.4))
		return

	if RunManager.upgrade_museum():
		_show_feedback("¡Museo mejorado!", Color(0.4, 1.0, 0.6))
	# Si upgrade_museum() falla acá (no debería, ya validamos arriba) no
	# hace falta feedback extra — el fallo silencioso simplemente no sube
	# el nivel y el próximo refresh de visuales lo va a reflejar igual.


# ── Reacciones a cambios de estado (RunManager es la fuente de verdad) ─────
func _on_museum_upgraded(_new_level: int) -> void:
	_refresh_visuals()
	var lobby := get_tree().current_scene
	if lobby and lobby.has_method("_populate_pedestals"):
		lobby._populate_pedestals()
	if lobby and lobby.has_method("_update_hud"):
		lobby._update_hud()


func _on_gold_changed(_amount: int) -> void:
	_refresh_visuals()


func _refresh_visuals() -> void:
	if _visual == null:
		return
	var level: int = RunManager.museum_level

	if RunManager.can_upgrade_museum():
		var cost: int = RunManager.get_museum_upgrade_cost()
		_visual.color      = Color(0.3, 0.22, 0.08, 0.9)
		_label_status.text = "Nivel %d / %d\nMejorar: %d oro (+1 slot de reliquia)" \
			% [level, RunManager.MUSEUM_MAX_LEVEL, cost]
	else:
		_visual.color      = Color(0.2, 0.28, 0.12, 0.9)
		_label_status.text = "Nivel %d / %d\nNivel máximo alcanzado" % [level, RunManager.MUSEUM_MAX_LEVEL]


func _show_feedback(text: String, color: Color) -> void:
	_feedback_label.text       = text
	_feedback_label.modulate   = color
	_feedback_label.modulate.a = 1.0
	_feedback_label.show()

	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_feedback_label.hide)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_label_prompt.show()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_label_prompt.hide()
