# InventoryPanel.gd
# Panel de inventario estilo Brotato — Tab para abrir/cerrar, juego no pausa.
#
# Layout:
#   Izquierda — grid de reliquias activas (escalable a N reliquias)
#   Derecha   — stats fijos del jugador
#   Tooltip   — aparece al hacer hover sobre una reliquia

extends Control

# ── Colores ───────────────────────────────────────────────────────────────
const C_BG          := Color(0.04, 0.04, 0.08, 0.92)
const C_BORDER      := Color(0.45, 0.35, 0.15)
const C_HEADER      := Color(0.88, 0.78, 0.3)
const C_LABEL       := Color(0.6, 0.6, 0.72)
const C_VALUE       := Color(1.0, 1.0, 1.0)
const C_RELIC_NAME  := Color(0.4, 0.92, 0.6)
const C_RELIC_BG    := Color(0.12, 0.14, 0.2)
const C_RELIC_HOVER := Color(0.22, 0.24, 0.38)
const C_SEPARATOR   := Color(0.28, 0.28, 0.42)
const C_TOOLTIP_BG  := Color(0.06, 0.06, 0.12, 0.97)

# ── Constantes de layout ──────────────────────────────────────────────────
const CELL_SIZE   := Vector2(64, 64)
const CELL_GAP    := 6
const GRID_COLS   := 4
const PANEL_W     := 560   # ancho total del panel
const LEFT_W      := 310   # ancho columna izquierda (grid)
const RIGHT_W     := 210   # ancho columna derecha (stats)

# ── Nodos internos ────────────────────────────────────────────────────────
var _panel_root:  Control
var _grid_area:   Control      # contenedor del grid scrolleable
var _tooltip:     Control      # tooltip flotante
var _tooltip_name:   Label
var _tooltip_effect: Label
var _tooltip_desc:   Label
var _visible_panel: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not RunManager.is_in_run:
		return
	if event.is_action_pressed("inventory"):
		_toggle()
		get_viewport().set_input_as_handled()


# ── Toggle ────────────────────────────────────────────────────────────────

func _toggle() -> void:
	_visible_panel = not _visible_panel
	visible = _visible_panel
	if _visible_panel:
		_tooltip.visible = false
		_refresh()
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func close() -> void:
	_visible_panel = false
	visible = false
	_tooltip.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ── Construcción de UI (una sola vez) ────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro pantalla completa
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Panel principal
	_panel_root = Control.new()
	_panel_root.size = Vector2(PANEL_W, 440)
	add_child(_panel_root)

	var panel_bg := _make_stylebox_rect(Vector2(PANEL_W, 440), C_BG, C_BORDER)
	_panel_root.add_child(panel_bg)

	# ── Título ──
	var title := Label.new()
	title.text = "INVENTARIO"
	title.position = Vector2(0, 12)
	title.size = Vector2(PANEL_W, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", C_HEADER)
	_panel_root.add_child(title)

	var hint := Label.new()
	hint.text = "Tab para cerrar"
	hint.position = Vector2(0, 36)
	hint.size = Vector2(PANEL_W, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", C_LABEL)
	_panel_root.add_child(hint)

	# Separador horizontal
	var sep := ColorRect.new()
	sep.color = C_SEPARATOR
	sep.position = Vector2(16, 56)
	sep.size = Vector2(PANEL_W - 32, 1)
	_panel_root.add_child(sep)

	# ── Columna izquierda: header + grid ──
	var left_header := Label.new()
	left_header.text = "RELIQUIAS ACTIVAS"
	left_header.position = Vector2(16, 64)
	left_header.add_theme_font_size_override("font_size", 11)
	left_header.add_theme_color_override("font_color", C_HEADER)
	_panel_root.add_child(left_header)

	# Área del grid (clip para que no se salga)
	var grid_clip := SubViewportContainer.new() # usamos Control con clip_children
	_grid_area = Control.new()
	_grid_area.position = Vector2(16, 84)
	_grid_area.size = Vector2(LEFT_W, 340)
	_grid_area.clip_contents = true
	_panel_root.add_child(_grid_area)

	# Separador vertical entre columnas
	var vsep := ColorRect.new()
	vsep.color = C_SEPARATOR
	vsep.position = Vector2(LEFT_W + 20, 58)
	vsep.size = Vector2(1, 370)
	_panel_root.add_child(vsep)

	# ── Columna derecha: stats ──
	var stats_x: float = LEFT_W + 30
	var right_header := Label.new()
	right_header.text = "ESTADÍSTICAS"
	right_header.position = Vector2(stats_x, 64)
	right_header.add_theme_font_size_override("font_size", 11)
	right_header.add_theme_color_override("font_color", C_HEADER)
	_panel_root.add_child(right_header)

	# Stats se llenan en _refresh_stats()
	# Guardamos referencia a la zona de stats
	var stats_zone := Control.new()
	stats_zone.name = "StatsZone"
	stats_zone.position = Vector2(stats_x, 84)
	stats_zone.size = Vector2(RIGHT_W, 340)
	_panel_root.add_child(stats_zone)

	# ── Tooltip (encima de todo) ──
	_build_tooltip()

	# Centrar el panel
	_center_panel()


func _build_tooltip() -> void:
	_tooltip = Control.new()
	_tooltip.z_index = 20
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

	# Fondo — ColorRect para poder redimensionar fácil
	var tt_bg := ColorRect.new()
	tt_bg.name = "TooltipBG"
	tt_bg.color = C_TOOLTIP_BG
	tt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(tt_bg)

	# Borde encima del fondo
	var tt_border := PanelContainer.new()
	tt_border.name = "TooltipBorder"
	tt_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0, 0, 0, 0)
	bstyle.border_color = C_BORDER
	bstyle.set_border_width_all(1)
	bstyle.set_corner_radius_all(4)
	tt_border.add_theme_stylebox_override("panel", bstyle)
	_tooltip.add_child(tt_border)

	const TT_W := 260   # ancho fijo generoso
	const PAD  := 10    # padding interior

	_tooltip_name = Label.new()
	_tooltip_name.position = Vector2(PAD, PAD)
	_tooltip_name.size = Vector2(TT_W - PAD * 2, 20)
	_tooltip_name.add_theme_font_size_override("font_size", 13)
	_tooltip_name.add_theme_color_override("font_color", C_RELIC_NAME)
	_tooltip_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_name)

	_tooltip_effect = Label.new()
	_tooltip_effect.position = Vector2(PAD, PAD + 24)
	_tooltip_effect.size = Vector2(TT_W - PAD * 2, 0)   # alto libre
	_tooltip_effect.add_theme_font_size_override("font_size", 11)
	_tooltip_effect.add_theme_color_override("font_color", C_VALUE)
	_tooltip_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_effect)

	_tooltip_desc = Label.new()
	_tooltip_desc.size = Vector2(TT_W - PAD * 2, 0)   # alto libre
	_tooltip_desc.add_theme_font_size_override("font_size", 10)
	_tooltip_desc.add_theme_color_override("font_color", C_LABEL)
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_desc)


# ── Refresh (cada vez que se abre) ────────────────────────────────────────

func _refresh() -> void:
	_refresh_grid()
	_refresh_stats()
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or get_tree() == null:
		return
	_center_panel()


func _refresh_grid() -> void:
	for c in _grid_area.get_children():
		c.queue_free()

	var relics := RunManager.active_relics
	if relics.is_empty():
		var empty := Label.new()
		empty.text = "Ninguna reliquia activa"
		empty.position = Vector2(0, 8)
		empty.size = Vector2(LEFT_W, 24)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", C_LABEL)
		_grid_area.add_child(empty)
		return

	for i in range(relics.size()):
		var relic_id: String = relics[i]
		var data: Dictionary = MuseumData.get_relic(relic_id)
		if data.is_empty():
			continue

		var col: int = i % GRID_COLS
		var row: int = i / GRID_COLS
		var cell_pos := Vector2(
			col * (CELL_SIZE.x + CELL_GAP),
			row * (CELL_SIZE.y + CELL_GAP)
		)

		_build_relic_cell(data, cell_pos)


func _build_relic_cell(data: Dictionary, pos: Vector2) -> void:
	var cell := Control.new()
	cell.position = pos
	cell.size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo celda como ColorRect para poder cambiar color en hover fácilmente
	var cell_bg := ColorRect.new()
	cell_bg.size = CELL_SIZE
	cell_bg.color = C_RELIC_BG
	cell_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(cell_bg)

	# Borde via StyleBoxFlat en un PanelContainer encima (sin bloquear input)
	var border_panel := PanelContainer.new()
	border_panel.size = CELL_SIZE
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0, 0, 0, 0)   # transparente
	bstyle.border_color = C_BORDER
	bstyle.set_border_width_all(1)
	bstyle.set_corner_radius_all(4)
	border_panel.add_theme_stylebox_override("panel", bstyle)
	cell.add_child(border_panel)

	# Letra inicial como placeholder (hasta tener sprites)
	var letter := Label.new()
	letter.text = data.get("name", "?").substr(0, 1).to_upper()
	letter.size = CELL_SIZE
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 26)
	letter.add_theme_color_override("font_color", C_RELIC_NAME)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(letter)

	# Hover: cambiar color del ColorRect y mostrar tooltip
	cell.mouse_entered.connect(_on_cell_hover.bind(data, cell_bg))
	cell.mouse_exited.connect(_on_cell_exit.bind(cell_bg))

	_grid_area.add_child(cell)


func _refresh_stats() -> void:
	var zone := _panel_root.get_node_or_null("StatsZone")
	if zone == null:
		return
	for c in zone.get_children():
		c.queue_free()

	var player := _get_player()
	var y: float = 0.0
	var row_h: float = 28.0

	# Vida
	var hp     := RunManager.player_current_health
	var max_hp := RunManager.player_max_health
	y = _add_stat(zone, y, row_h, "❤  Vida", "%d / %d" % [int(hp), int(max_hp)])

	# Daño
	var dmg_bonus := _get_relic_bonus("projectile_dmg_pct")
	var final_dmg := 10.0 * (1.0 + dmg_bonus)
	var dmg_text  := "%.0f" % final_dmg
	if dmg_bonus > 0.0:
		dmg_text += " (+%.0f%%)" % (dmg_bonus * 100)
	y = _add_stat(zone, y, row_h, "🔹  Daño", dmg_text)

	# Dash
	var dash: int = 1
	if player and "._dash_charges" in player:
		dash = int(player._dash_charges)
	y = _add_stat(zone, y, row_h, "💨  Dash", str(dash))

	# Dodge
	var dodge := _get_relic_bonus("dodge_chance")
	y = _add_stat(zone, y, row_h, "🛡  Esquivar", "%.0f%%" % (dodge * 100))

	# Separador
	var sep := ColorRect.new()
	sep.color = C_SEPARATOR
	sep.position = Vector2(0, y + 4)
	sep.size = Vector2(RIGHT_W, 1)
	zone.add_child(sep)
	y += 14.0

	# Oro
	y = _add_stat(zone, y, row_h, "🪙  Oro", str(RunManager.get_display_gold()))

	# Sala
	var zone_n := RunManager.current_zone_index + 1
	var room_n := RunManager.current_room_index + 1
	_add_stat(zone, y, row_h, "🗺  Sala", "Z%d · %d" % [zone_n, room_n])


func _add_stat(parent: Control, y: float, h: float, label_text: String, value_text: String) -> float:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(0, y)
	lbl.size = Vector2(RIGHT_W * 0.65, h)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_LABEL)
	parent.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.position = Vector2(RIGHT_W * 0.65, y)
	val.size = Vector2(RIGHT_W * 0.35, h)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", C_VALUE)
	parent.add_child(val)

	return y + h


# ── Tooltip ───────────────────────────────────────────────────────────────

func _on_cell_hover(data: Dictionary, bg: ColorRect) -> void:
	bg.color = C_RELIC_HOVER

	const TT_W := 260
	const PAD  := 10

	_tooltip_name.text   = data.get("name", "")
	_tooltip_effect.text = data.get("effect", "")
	_tooltip_desc.text   = data.get("description", "")

	# Esperar dos frames para que Godot calcule el tamaño real del texto con autowrap
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or get_tree() == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(self) or get_tree() == null:
		return

	# Obtener altos reales de cada label
	var effect_h: float = _tooltip_effect.get_minimum_size().y
	var desc_h:   float = _tooltip_desc.get_minimum_size().y

	# Posicionar cada elemento apilado con padding
	_tooltip_effect.position = Vector2(PAD, PAD + 22)
	_tooltip_effect.size     = Vector2(TT_W - PAD * 2, effect_h)

	var desc_y: float = PAD + 22 + effect_h + 6
	_tooltip_desc.position = Vector2(PAD, desc_y)
	_tooltip_desc.size     = Vector2(TT_W - PAD * 2, desc_h)

	var total_h: float = desc_y + desc_h + PAD

	# Redimensionar fondo y borde
	var tt_bg: ColorRect = _tooltip.get_node("TooltipBG")
	var tt_border: PanelContainer = _tooltip.get_node("TooltipBorder")
	tt_bg.size     = Vector2(TT_W, total_h)
	tt_border.size = Vector2(TT_W, total_h)
	tt_border.custom_minimum_size = Vector2(TT_W, total_h)

	# Posicionar tooltip junto al cursor, dentro de la pantalla
	var mp  := get_viewport().get_mouse_position()
	var vp  := get_viewport().get_visible_rect().size
	var tt_x: float = mp.x + 14.0
	var tt_y: float = mp.y + 14.0
	if tt_x + TT_W > vp.x:
		tt_x = mp.x - TT_W - 6.0
	if tt_y + total_h > vp.y:
		tt_y = mp.y - total_h - 6.0
	_tooltip.position = Vector2(tt_x, tt_y)
	_tooltip.visible = true


func _on_cell_exit(bg: ColorRect) -> void:
	bg.color = C_RELIC_BG
	_tooltip.visible = false


# ── Centrado ──────────────────────────────────────────────────────────────

func _center_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel_root.position = Vector2(
		(vp.x - _panel_root.size.x) * 0.5,
		(vp.y - _panel_root.size.y) * 0.5
	)


# ── Helpers ───────────────────────────────────────────────────────────────

func _make_stylebox_rect(sz: Vector2, bg_color: Color, border_color: Color) -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)

	var rect := PanelContainer.new()
	rect.size = sz
	rect.custom_minimum_size = sz
	rect.add_theme_stylebox_override("panel", style)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _get_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


func _get_relic_bonus(bonus_type: String) -> float:
	var total := 0.0
	for relic_id in RunManager.active_relics:
		var data: Dictionary = MuseumData.get_relic(relic_id)
		if data.get("bonus_type", "") == bonus_type:
			total += float(data.get("bonus_value", 0.0))
	return total
