# Lobby.gd
extends Node2D

const PEDESTAL_SCRIPT  := "res://Scenes/RelicPedestal.gd"
const ALTAR_SCRIPT      := "res://Scenes/MuseumUpgradeAltar.gd"

const PEDESTAL_ORIGIN:  Vector2 = Vector2(0, 80)
const PEDESTAL_SPACING: float   = 200.0

# Colores del menú
const PANEL_COLOR  := Color(0.04, 0.04, 0.09, 0.94)
const HEADER_COLOR := Color(0.85, 0.75, 0.3)
const BTN_NORMAL   := Color(0.15, 0.15, 0.25)
const BTN_HOVER    := Color(0.28, 0.25, 0.45)

@onready var relics_label: Label = $HUD/RelicsLabel

var _lobby_menu: Control = null
var _menu_open: bool = false


func _ready() -> void:
	call_deferred("_disable_gun")
	_populate_pedestals()
	_setup_museum_altar()
	_update_hud()
	call_deferred("_build_lobby_menu")

	# Nivel de museo = cantidad de slots equipables. Si el jugador bajó de
	# nivel por alguna razón (no debería pasar, pero por las dudas) se
	# recorta en vez de dejar slots equipados "fantasma".
	if RunManager.equipped_relics.size() > RunManager.museum_level:
		RunManager.equipped_relics = RunManager.equipped_relics.slice(0, RunManager.museum_level)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu_open:
			_close_lobby_menu()
		else:
			_open_lobby_menu()
		get_viewport().set_input_as_handled()


# ── Menú del Lobby ────────────────────────────────────────────────────────

func _build_lobby_menu() -> void:
	# CanvasLayer para que quede sobre todo
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_lobby_menu = Control.new()
	_lobby_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_lobby_menu.visible = false
	layer.add_child(_lobby_menu)

	# Fondo oscuro
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_menu.add_child(bg)

	# Panel
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(280, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left   = 28
	style.content_margin_right  = 28
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	_lobby_menu.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = "MENÚ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.3, 0.2)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	_add_menu_button(vbox, "← Volver",              _close_lobby_menu)
	_add_menu_button(vbox, "💾  Guardar",           _open_save_picker)
	_add_menu_button(vbox, "🏠  Menú Principal",    _go_to_main_menu)
	_add_menu_button(vbox, "✕  Salir del juego",    _quit_game)

	# Centrar el panel tras un frame
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or get_tree() == null:
		return
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(vp.x - panel.size.x) * 0.5,
		(vp.y - panel.size.y) * 0.5
	)


func _add_menu_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_NORMAL
	normal.set_corner_radius_all(6)
	normal.content_margin_left  = 12
	normal.content_margin_right = 12

	var hover := StyleBoxFlat.new()
	hover.bg_color = BTN_HOVER
	hover.set_corner_radius_all(6)
	hover.content_margin_left  = 12
	hover.content_margin_right = 12

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _open_lobby_menu() -> void:
	if _lobby_menu == null:
		return
	_menu_open = true
	_lobby_menu.visible = true


func _close_lobby_menu() -> void:
	_menu_open = false
	if _lobby_menu:
		_lobby_menu.visible = false


func _go_to_main_menu() -> void:
	_close_lobby_menu()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _quit_game() -> void:
	get_tree().quit()


func _disable_gun() -> void:
	var player := get_node_or_null("Player")
	if player == null:
		return
	var gun := player.get_node_or_null("Gun")
	if gun:
		gun.process_mode = Node.PROCESS_MODE_DISABLED
		if gun.has_method("_cancel_reload"):
			gun._cancel_reload()


func _update_hud() -> void:
	var total:    int = RunManager.unlocked_relics.size()
	var equipped: int = 0
	for r in RunManager.active_relics:
		if r != "":
			equipped += 1

	var lines: Array = []
	lines.append("🪙 Oro: %d" % RunManager.get_display_gold())
	lines.append("Reliquias descubiertas: %d / %d" % [total, MuseumData.get_all_relic_ids().size()])
	lines.append("Slots equipados: %d / %d" % [equipped, RunManager.museum_level])

	if RunManager.last_run_floor > 0:
		var result: String = "Victoria ✓" if RunManager.last_run_victory else "Derrota ✗"
		lines.append("Último run: %s (sala %d)" % [result, RunManager.last_run_floor])

	relics_label.text = "\n".join(lines)


func _populate_pedestals() -> void:
	var container := get_node_or_null("RelicPedestals")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	var script: Script = load(PEDESTAL_SCRIPT)

	for i in range(RunManager.museum_level):
		var pedestal := Node2D.new()
		pedestal.set_script(script)
		pedestal.position = PEDESTAL_ORIGIN + Vector2(i * PEDESTAL_SPACING, 0)
		container.add_child(pedestal)
		pedestal.call_deferred("setup", i)


# El altar es un Node2D vacío que el usuario coloca a mano en Lobby.tscn
# (mismo criterio que RelicPedestals: la posición la decide quien arma la
# escena, el script se pega solo). Si no existe todavía en la escena, no
# rompe nada — simplemente no hay forma de mejorar el museo hasta que se
# agregue el nodo.
func _setup_museum_altar() -> void:
	var altar := get_node_or_null("MuseumUpgradeAltar")
	if altar == null:
		return
	if altar.get_script() == null:
		altar.set_script(load(ALTAR_SCRIPT))

func _open_save_picker() -> void:
	if _lobby_menu == null:
		return
	var panel := _lobby_menu.get_node_or_null("Panel")
	if panel == null:
		return
	var vbox := panel.get_child(0) as VBoxContainer
	for child in vbox.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "GUARDAR EN..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	vbox.add_child(title)

	for meta in SaveManager.MANUAL_SLOT_META:
		var slot_id: String = meta["slot"]
		var info: Dictionary = SaveManager.get_slot_info(slot_id)
		var suffix := " (vacío)" if info.is_empty() else " — %s" % _format_unix(int(info.get("saved_at_unix", 0)))
		_add_menu_button(vbox, "%s%s" % [meta["label"], suffix], func(): _save_to_slot(slot_id))

	_add_menu_button(vbox, "← Volver", _rebuild_lobby_menu_default)


func _save_to_slot(slot_name: String) -> void:
	var ok := SaveManager.save_slot(slot_name)
	_show_save_feedback(ok)
	_rebuild_lobby_menu_default()


func _rebuild_lobby_menu_default() -> void:
	if _lobby_menu == null:
		return
	var layer := _lobby_menu.get_parent()
	_lobby_menu.queue_free()
	call_deferred("_build_lobby_menu")


func _show_save_feedback(ok: bool) -> void:
	if _lobby_menu == null:
		return
	var panel := _lobby_menu.get_node_or_null("Panel")
	if panel == null:
		return
	var lbl := Label.new()
	lbl.text = "Partida guardada" if ok else "No se pudo guardar"
	lbl.modulate = Color(0.4, 1.0, 0.6) if ok else Color(1.0, 0.4, 0.4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	panel.add_child(lbl)

	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free)


func _format_unix(unix_time: int) -> String:
	if unix_time <= 0:
		return "sin fecha"
	var dt := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d/%02d %02d:%02d" % [dt.day, dt.month, dt.hour, dt.minute]
