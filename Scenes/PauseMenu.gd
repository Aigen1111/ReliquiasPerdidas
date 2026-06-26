# PauseMenu.gd
# Menú de pausa que se abre con Escape durante el run.
# Pausa el árbol de escenas. Opciones: Reanudar, Ver Códex, Salir al Lobby.

extends Control

const PANEL_COLOR    := Color(0.04, 0.04, 0.09, 0.94)
const HEADER_COLOR   := Color(0.85, 0.75, 0.3)
const BTN_NORMAL     := Color(0.15, 0.15, 0.25)
const BTN_HOVER      := Color(0.28, 0.25, 0.45)
const BTN_TEXT       := Color(1.0, 1.0, 1.0)

var _is_paused: bool = false
# Referencia al InventoryPanel para cerrarlo si estaba abierto
var _inventory_panel: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # corre aunque el árbol esté pausado
	_build_ui()


func setup(inventory_panel: Node) -> void:
	_inventory_panel = inventory_panel


func _unhandled_input(event: InputEvent) -> void:
	if not RunManager.is_in_run:
		return
	if event.is_action_pressed("ui_cancel"):   # Escape
		if _is_paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


# ── Pausa / Reanuda ───────────────────────────────────────────────────────

func _pause() -> void:
	# Cerrar inventario si estaba abierto
	if _inventory_panel and _inventory_panel.has_method("close"):
		_inventory_panel.close()

	_is_paused = true
	get_tree().paused = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _resume() -> void:
	_is_paused = false
	get_tree().paused = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ── Construcción de UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Panel de ancho fijo — se centrará en _center_panel() tras conocer su alto real
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(280, 0)

	var style := StyleBoxFlat.new()
	style.bg_color     = PANEL_COLOR
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left   = 28
	style.content_margin_right  = 28
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", HEADER_COLOR)
	vbox.add_child(title)

	# Separador
	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.3, 0.2)
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# Botones
	_add_button(vbox, "▶  Reanudar",      _resume)
	_add_button(vbox, "📖  Ver Códex",    _open_codex)
	_add_button(vbox, "🚪  Salir al Lobby", _exit_to_lobby)

	# Centrar tras un frame para que el panel conozca su tamaño real
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


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE

	# Estilos
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

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", BTN_TEXT)

	btn.pressed.connect(callback)
	parent.add_child(btn)


# ── Acciones de botones ───────────────────────────────────────────────────

func _open_codex() -> void:
	# Primero buscar si ya existe en el árbol por grupo
	var codex: Node = get_tree().get_first_node_in_group("relic_codex")

	# Si no, crearlo dentro de RunHud (nombre exacto del nodo en Room.tscn)
	if codex == null:
		var scene := get_tree().current_scene
		var run_hud: Node = null
		if scene:
			for child in scene.get_children():
				if child.name == "RunHud":
					run_hud = child
					break
		if run_hud:
			codex = CanvasLayer.new()
			codex.name = "RelicCodex"
			codex.set_script(load("res://Scenes/RelicCodex.gd"))
			run_hud.add_child(codex)

	if codex and codex.has_method("open_run"):
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_paused = false
		codex.open_run()
	else:
		push_warning("PauseMenu: no se encontró RunHud en la escena.")


func _exit_to_lobby() -> void:
	_is_paused = false
	get_tree().paused = false
	visible = false
	# Mostrar pantalla de resultado (derrota) en vez de ir directo al lobby
	RunManager._end_run(false)
