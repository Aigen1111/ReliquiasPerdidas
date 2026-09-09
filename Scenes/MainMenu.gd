# MainMenu.gd
# Menú de inicio: Nueva Partida / Cargar Partida (con selector y borrado de slots) / Salir.
extends Control

const PANEL_COLOR  := Color(0.04, 0.04, 0.09, 0.94)
const HEADER_COLOR := Color(0.85, 0.75, 0.3)
const BTN_NORMAL   := Color(0.15, 0.15, 0.25)
const BTN_HOVER    := Color(0.28, 0.25, 0.45)
const DEL_NORMAL   := Color(0.35, 0.12, 0.12)
const DEL_HOVER    := Color(0.55, 0.18, 0.18)

const TUTORIAL_SCENE := "res://Scenes/Tutorial/Tutorial_Intro.tscn"
const LOBBY_SCENE    := "res://Scenes/Lobby.tscn"

var _status_label:   Label         = null
var _main_menu_box:  VBoxContainer = null
var _load_menu_box:  VBoxContainer = null
var _confirm_box:    VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(340, 0)

	var style := StyleBoxFlat.new()
	style.bg_color     = PANEL_COLOR
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left   = 30
	style.content_margin_right  = 30
	style.content_margin_top    = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(root_vbox)

	var title := Label.new()
	title.text = "RELIQUIAS PERDIDAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	root_vbox.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.3, 0.2)
	sep.custom_minimum_size = Vector2(0, 1)
	root_vbox.add_child(sep)

	# ── Pantalla principal ──
	_main_menu_box = VBoxContainer.new()
	_main_menu_box.add_theme_constant_override("separation", 16)
	root_vbox.add_child(_main_menu_box)

	_add_button(_main_menu_box, "🗡  Nueva Partida",  _on_new_game)
	_add_button(_main_menu_box, "💾  Cargar Partida", _open_load_screen)
	_add_button(_main_menu_box, "✕  Salir del Juego", _on_quit)

	# ── Pantalla de selección de slot ──
	_load_menu_box = VBoxContainer.new()
	_load_menu_box.add_theme_constant_override("separation", 10)
	_load_menu_box.visible = false
	root_vbox.add_child(_load_menu_box)

	# ── Pantalla de confirmación de borrado ──
	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 14)
	_confirm_box.visible = false
	root_vbox.add_child(_confirm_box)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.modulate = Color(1.0, 0.5, 0.5)
	_status_label.visible = false
	root_vbox.add_child(_status_label)

	_center_panel.call_deferred()


func _center_panel() -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(vp.x - panel.size.x) * 0.5,
		(vp.y - panel.size.y) * 0.5
	)


# ── Pantalla de carga ────────────────────────────────────────────────────

func _open_load_screen() -> void:
	_status_label.visible = false
	_populate_load_menu()
	_main_menu_box.visible = false
	_confirm_box.visible   = false
	_load_menu_box.visible = true


func _show_main_screen() -> void:
	_status_label.visible  = false
	_load_menu_box.visible = false
	_confirm_box.visible   = false
	_main_menu_box.visible = true


func _populate_load_menu() -> void:
	for child in _load_menu_box.get_children():
		child.queue_free()

	var any_slot := false

	for meta in SaveManager.MANUAL_SLOT_META:
		var slot_id: String = meta["slot"]
		var info: Dictionary = SaveManager.get_slot_info(slot_id)
		if info.is_empty():
			continue
		any_slot = true
		var date_str := _format_unix(int(info.get("saved_at_unix", 0)))
		var label_text: String = meta["label"]
		_add_slot_row(_load_menu_box, "%s — %s" % [label_text, date_str],
			func(): _load_specific_slot(slot_id),
			func(): _confirm_delete_slot(slot_id, label_text))

	for meta in SaveManager.AUTOSAVE_SLOT_META:
		var slot_id: String = meta["slot"]
		var info: Dictionary = SaveManager.get_slot_info(slot_id)
		if info.is_empty():
			continue
		any_slot = true
		var date_str := _format_unix(int(info.get("saved_at_unix", 0)))
		var label_text: String = meta["label"]
		_add_button(_load_menu_box, "%s — %s" % [label_text, date_str],
			func(): _load_specific_slot(slot_id))

	if not any_slot:
		var lbl := Label.new()
		lbl.text = "No hay partidas guardadas todavía."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.7, 0.7, 0.7)
		_load_menu_box.add_child(lbl)

	_add_button(_load_menu_box, "← Volver", _show_main_screen)


func _load_specific_slot(slot_name: String) -> void:
	var ok := SaveManager.load_slot(slot_name)
	if not ok:
		_show_status("No se pudo cargar ese guardado.")
		return
	var target := LOBBY_SCENE if RunManager.tutorial_done else TUTORIAL_SCENE
	get_tree().change_scene_to_file(target)


# ── Confirmación de borrado ───────────────────────────────────────────────

func _confirm_delete_slot(slot_id: String, label_text: String) -> void:
	for child in _confirm_box.get_children():
		child.queue_free()

	var msg := Label.new()
	msg.text = "¿Eliminar \"%s\"?\nEsta acción no se puede deshacer." % label_text
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 13)
	_confirm_box.add_child(msg)

	_add_button(_confirm_box, "Sí, eliminar", func(): _do_delete_slot(slot_id))
	_add_button(_confirm_box, "Cancelar",     _cancel_delete)

	_load_menu_box.visible = false
	_confirm_box.visible   = true


func _do_delete_slot(slot_id: String) -> void:
	SaveManager.delete_slot(slot_id)
	_confirm_box.visible = false
	_open_load_screen()


func _cancel_delete() -> void:
	_confirm_box.visible   = false
	_load_menu_box.visible = true


func _format_unix(unix_time: int) -> String:
	if unix_time <= 0:
		return "sin fecha"
	var dt := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d/%02d/%04d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]


# ── Botones ────────────────────────────────────────────────────────────────

func _style_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.set_corner_radius_all(6)
	normal.content_margin_left  = 12
	normal.content_margin_right = 12

	var hover := StyleBoxFlat.new()
	hover.bg_color = hover_color
	hover.set_corner_radius_all(6)
	hover.content_margin_left  = 12
	hover.content_margin_right = 12

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE
	_style_button(btn, BTN_NORMAL, BTN_HOVER)
	btn.pressed.connect(callback)
	parent.add_child(btn)


## Fila con el botón principal (cargar) + un botón chico de borrar al lado.
func _add_slot_row(parent: Control, text: String, on_load: Callable, on_delete: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	_style_button(btn, BTN_NORMAL, BTN_HOVER)
	btn.pressed.connect(on_load)
	row.add_child(btn)

	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.add_theme_font_size_override("font_size", 15)
	del_btn.custom_minimum_size = Vector2(44, 44)
	del_btn.focus_mode = Control.FOCUS_NONE
	_style_button(del_btn, DEL_NORMAL, DEL_HOVER)
	del_btn.pressed.connect(on_delete)
	row.add_child(del_btn)

	parent.add_child(row)


func _on_new_game() -> void:
	RunManager.gold                   = 0
	RunManager.unlocked_areas         = ["bribri"]
	RunManager.unlocked_relics        = []
	RunManager.equipped_relics        = []
	RunManager.active_relics          = []
	RunManager.tutorial_done          = false
	RunManager.tutorial_sibu_revealed = false
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _on_quit() -> void:
	get_tree().quit()


func _show_status(text: String) -> void:
	if _status_label == null:
		return
	_status_label.text    = text
	_status_label.visible = true
