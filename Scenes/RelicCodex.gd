# RelicCodex.gd
# ─────────────────────────────────────────────────────────────────────────────
# Códex de reliquias. Dos modos:
#   LOBBY    → abre desde un pedestal, permite seleccionar reliquia para equipar
#   RUN      → abre desde pausa (Escape), solo lectura, muestra reliquias activas
#              con conteo de duplicados (x2, x3...)
# ─────────────────────────────────────────────────────────────────────────────
extends CanvasLayer

enum Mode { LOBBY, RUN }

signal relic_selected(relic_id: String, slot_idx: int)   # emitida en modo LOBBY al elegir

const CELL_SIZE:    Vector2 = Vector2(64, 64)
const COLS:         int     = 5
const GRID_PADDING: Vector2 = Vector2(12, 12)

var _mode:          Mode    = Mode.LOBBY
var _slot_idx:      int     = 0          # pedestal que abrió el códex
var _selected_id:   String  = ""
var _all_ids:       Array   = []

# Nodos principales
var _backdrop:      ColorRect
var _panel:         ColorRect
var _grid_container: Control
var _detail_panel:  Control
var _close_btn:     Button
var _mode_label:    Label
var _detail_name:   Label
var _detail_desc:   Label
var _detail_effect: Label
var _detail_count:  Label
var _confirm_btn:   Button


func _ready() -> void:
	add_to_group("relic_codex")
	layer = 10   # por encima del HUD, sin depender del orden del árbol
	_all_ids = MuseumData.get_all_relic_ids()
	_build_ui()
	hide()


func open_lobby(slot_idx: int) -> void:
	_mode     = Mode.LOBBY
	_slot_idx = slot_idx
	_selected_id = ""
	_refresh_grid()
	_clear_detail()
	_mode_label.text    = "Elegir reliquia para el slot %d" % (slot_idx + 1)
	_confirm_btn.show()
	_confirm_btn.text   = "Equipar"
	_confirm_btn.disabled = true
	_set_hud_visible(false)
	get_tree().paused   = true
	process_mode        = Node.PROCESS_MODE_ALWAYS
	show()


func open_run() -> void:
	_mode        = Mode.RUN
	_selected_id = ""
	_refresh_grid()
	_clear_detail()
	_mode_label.text  = "Reliquias activas en este run"
	_confirm_btn.hide()
	_set_hud_visible(false)
	get_tree().paused = true
	process_mode      = Node.PROCESS_MODE_ALWAYS
	show()


func _close() -> void:
	get_tree().paused = false
	_set_hud_visible(true)
	hide()


func _set_hud_visible(value: bool) -> void:
	var parent_hud := get_parent()
	if parent_hud == null:
		return
	var lbl := parent_hud.get_node_or_null("RelicsLabel")
	if lbl:
		lbl.visible = value


# ── Construcción de UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo semitransparente
	_backdrop = ColorRect.new()
	_backdrop.color             = Color(0, 0, 0, 0.65)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Panel principal centrado ~780×520
	_panel = ColorRect.new()
	_panel.color    = Color(0.08, 0.09, 0.12, 0.97)
	_panel.size     = Vector2(780, 520)
	_panel.position = Vector2(50, 40)  # ajustar si la resolución cambia
	add_child(_panel)

	# Label de modo (título)
	_mode_label = Label.new()
	_mode_label.size                 = Vector2(760, 28)
	_mode_label.position             = Vector2(60, 48)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 16)
	_mode_label.modulate             = Color(1.0, 0.85, 0.2)
	add_child(_mode_label)

	# Botón cerrar
	_close_btn = Button.new()
	_close_btn.text     = "✕ Cerrar"
	_close_btn.size     = Vector2(100, 30)
	_close_btn.position = Vector2(720, 48)
	_close_btn.pressed.connect(_close)
	add_child(_close_btn)

	# Grid de reliquias (izquierda)
	_grid_container = Control.new()
	_grid_container.size     = Vector2(360, 440)
	_grid_container.position = Vector2(62, 82)
	add_child(_grid_container)

	# Panel de detalle (derecha)
	_detail_panel = ColorRect.new()
	_detail_panel.color    = Color(0.05, 0.06, 0.1, 0.9)
	_detail_panel.size     = Vector2(330, 440)
	_detail_panel.position = Vector2(440, 82)
	add_child(_detail_panel)

	_detail_name = _make_label(Vector2(450, 90), Vector2(310, 28), 15)
	_detail_name.modulate = Color(1.0, 0.85, 0.2)

	_detail_count = _make_label(Vector2(450, 120), Vector2(310, 22), 13)
	_detail_count.modulate = Color(0.5, 1.0, 0.5)

	_detail_effect = _make_label(Vector2(450, 148), Vector2(310, 40), 12)
	_detail_effect.modulate = Color(0.75, 0.95, 0.75)
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_detail_desc = _make_label(Vector2(450, 196), Vector2(310, 200), 11)
	_detail_desc.modulate    = Color(0.7, 0.7, 0.7)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Botón confirmar (solo lobby)
	_confirm_btn = Button.new()
	_confirm_btn.size     = Vector2(200, 36)
	_confirm_btn.position = Vector2(490, 450)
	_confirm_btn.pressed.connect(_on_confirm)
	add_child(_confirm_btn)


func _make_label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", font_size)
	add_child(lbl)
	return lbl


# ── Grid ──────────────────────────────────────────────────────────────────

func _refresh_grid() -> void:
	for child in _grid_container.get_children():
		child.queue_free()

	var unlocked: Array = RunManager.unlocked_relics

	for i in range(_all_ids.size()):
		var id: String    = _all_ids[i]
		var known: bool   = id in unlocked
		var cell          := _build_cell(id, known, i)
		_grid_container.add_child(cell)


func _build_cell(id: String, known: bool, idx: int) -> Control:
	var col: int = idx % COLS
	var row: int = idx / COLS

	var cell := ColorRect.new()
	cell.size     = Vector2(CELL_SIZE.x - 4, CELL_SIZE.y - 4)
	cell.position = Vector2(col * CELL_SIZE.x + GRID_PADDING.x,
							row * CELL_SIZE.y + GRID_PADDING.y)
	cell.color    = _cell_color(id, known)
	cell.name     = id

	# Letra inicial como placeholder visual hasta tener sprites
	var lbl := Label.new()
	lbl.size                 = cell.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	if known:
		var data: Dictionary = MuseumData.get_relic(id)
		lbl.text    = data.get("name", id).substr(0, 1).to_upper()
		lbl.modulate = Color.WHITE
	else:
		lbl.text    = "?"
		lbl.modulate = Color(0.3, 0.3, 0.3)
	cell.add_child(lbl)

	# Borde dorado si está equipada
	if id in RunManager.active_relics:
		var border := ColorRect.new()
		border.color    = Color(1.0, 0.8, 0.1, 0.4)
		border.size     = cell.size
		border.position = Vector2.ZERO
		cell.add_child(border)

	# Contador de duplicados en runs
	if _mode == Mode.RUN:
		var count: int = RunManager.active_relics.count(id)
		if count > 1:
			var count_lbl := Label.new()
			count_lbl.text                 = "x%d" % count
			count_lbl.modulate             = Color(1.0, 0.9, 0.1)
			count_lbl.position             = Vector2(cell.size.x - 24, cell.size.y - 18)
			count_lbl.add_theme_font_size_override("font_size", 11)
			cell.add_child(count_lbl)

	# Input — usar _input global o Button invisible encima
	var btn := Button.new()
	btn.flat          = true
	btn.size          = cell.size
	btn.position      = Vector2.ZERO
	btn.modulate      = Color(1, 1, 1, 0)  # invisible pero clickeable
	btn.pressed.connect(_on_cell_pressed.bind(id, known))
	cell.add_child(btn)

	return cell


func _cell_color(id: String, known: bool) -> Color:
	if not known:
		return Color(0.1, 0.1, 0.12)
	if id in RunManager.active_relics:
		return Color(0.35, 0.28, 0.06)
	return Color(0.18, 0.2, 0.25)


# ── Detalle ───────────────────────────────────────────────────────────────

func _on_cell_pressed(id: String, known: bool) -> void:
	if not known:
		_show_mystery()
		return
	_selected_id = id
	var data: Dictionary = MuseumData.get_relic(id)
	_detail_name.text   = data.get("name", id)
	_detail_effect.text = "⚡ " + data.get("effect", "")
	_detail_desc.text   = data.get("description", "")

	if _mode == Mode.RUN:
		var count: int = RunManager.active_relics.count(id)
		_detail_count.text = "Copias activas: %d" % count if count > 0 else "No equipada en este run"
	else:
		_detail_count.text = "★ Equipada" if id in RunManager.active_relics else ""
		_confirm_btn.disabled = false

	# Actualizar colores de celdas
	_refresh_grid()


func _show_mystery() -> void:
	_selected_id        = ""
	_detail_name.text   = "Reliquia desconocida"
	_detail_name.modulate = Color(0.4, 0.4, 0.4)
	_detail_effect.text = ""
	_detail_desc.text   = "Encuéntrala en una run para descubrirla."
	_detail_count.text  = ""
	if _mode == Mode.LOBBY:
		_confirm_btn.disabled = true


func _clear_detail() -> void:
	_detail_name.text   = ""
	_detail_effect.text = ""
	_detail_desc.text   = ""
	_detail_count.text  = ""
	_detail_name.modulate = Color(1.0, 0.85, 0.2)


# ── Confirmar selección (lobby) ───────────────────────────────────────────

func _on_confirm() -> void:
	if _selected_id == "" or _mode != Mode.LOBBY:
		return
	emit_signal("relic_selected", _selected_id, _slot_idx)
	_close()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
