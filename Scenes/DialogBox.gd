# DialogBox.gd


extends CanvasLayer

signal dialog_finished

const C_BOX_BG      := Color(0.04, 0.04, 0.09, 0.93)
const C_BOX_BORDER  := Color(0.7, 0.6, 0.2)
const C_NAME        := Color(0.9, 0.78, 0.2)
const C_NAME_HIDDEN := Color(0.5, 0.5, 0.5)
const C_TEXT        := Color(1.0, 1.0, 1.0)
const C_HINT        := Color(0.5, 0.5, 0.6)
const C_SIBU_HIDDEN := Color(0.05, 0.05, 0.05)   # silueta casi negra (mismo sprite, oscurecido)
const C_SIBU_SHOWN  := Color(1.0, 1.0, 1.0)      # colores reales del sprite

const BOX_H  := 160
const BOX_PAD := 20
const SIBU_W  := 180
const SIBU_H  := 220

const SIBU_TEXTURE_PATH := "res://Assets/Paid/UI/SiboMascara.png"

var _lines:     Array    = []
var _current:   int      = 0
var _on_finish: Callable = Callable()
var _active:    bool     = false
var _sibu_revealed: bool = false   # false = silueta oscura, true = revelado

var _backdrop:   ColorRect
var _panel:      ColorRect
var _border:     PanelContainer
var _name_label: Label
var _text_label: Label
var _hint_label: Label
var _sibu_rect:  TextureRect
var _sibu_label: Label


func _ready() -> void:
	layer        = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.45)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_panel = ColorRect.new()
	_panel.color = C_BOX_BG
	add_child(_panel)

	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color     = Color(0, 0, 0, 0)
	bstyle.border_color = C_BOX_BORDER
	bstyle.set_border_width_all(2)
	bstyle.set_corner_radius_all(6)
	_border = PanelContainer.new()
	_border.add_theme_stylebox_override("panel", bstyle)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_name_label.add_theme_constant_override("outline_size", 3)
	add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 14)
	_text_label.add_theme_color_override("font_color", C_TEXT)
	add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", C_HINT)
	add_child(_hint_label)

	_sibu_rect = TextureRect.new()
	var sibu_tex: Texture2D = load(SIBU_TEXTURE_PATH)
	if sibu_tex != null:
		_sibu_rect.texture      = sibu_tex
		_sibu_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sibu_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		push_warning("DialogBox: no se encontró el sprite de Sibö en " + SIBU_TEXTURE_PATH)
	add_child(_sibu_rect)

	_sibu_label = Label.new()
	_sibu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sibu_label.add_theme_font_size_override("font_size", 13)
	_sibu_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(_sibu_label)

	_apply_sibu_state()


func _layout() -> void:
	var vp    := get_viewport().get_visible_rect().size
	var box_y := vp.y - BOX_H - 20
	var box_x := float(BOX_PAD)
	var box_w := vp.x - BOX_PAD * 2

	_panel.position = Vector2(box_x, box_y)
	_panel.size     = Vector2(box_w, BOX_H)
	_border.position          = Vector2(box_x, box_y)
	_border.size              = Vector2(box_w, BOX_H)
	_border.custom_minimum_size = Vector2(box_w, BOX_H)

	var sibu_x := vp.x - SIBU_W - BOX_PAD * 2
	var sibu_y := box_y - SIBU_H + BOX_H
	_sibu_rect.position  = Vector2(sibu_x, sibu_y)
	_sibu_rect.size      = Vector2(SIBU_W, SIBU_H)
	_sibu_label.position = Vector2(sibu_x, sibu_y + 8)
	_sibu_label.size     = Vector2(SIBU_W, 24)

	var text_x := box_x + BOX_PAD
	var text_w := box_w - SIBU_W - BOX_PAD * 3
	_name_label.position = Vector2(text_x, box_y + 12)
	_name_label.size     = Vector2(text_w, 24)
	_text_label.position = Vector2(text_x, box_y + 36)
	_text_label.size     = Vector2(text_w, BOX_H - 72)
	_hint_label.position = Vector2(text_x, box_y + BOX_H - 24)
	_hint_label.size     = Vector2(text_w, 20)


# ── Estado silueta / revelado ─────────────────────────────────────────────

func reveal_sibu() -> void:
	_sibu_revealed = true
	_apply_sibu_state()


func _apply_sibu_state() -> void:
	if _sibu_revealed:
		_sibu_rect.modulate = C_SIBU_SHOWN
		_sibu_label.text  = "SIBÖ"
		_name_label.text  = "Sibö"
		_name_label.add_theme_color_override("font_color", C_NAME)
	else:
		_sibu_rect.modulate = C_SIBU_HIDDEN
		_sibu_label.text  = "???"
		_name_label.text  = "???"
		_name_label.add_theme_color_override("font_color", C_NAME_HIDDEN)


# ── API pública ───────────────────────────────────────────────────────────

func show_lines(lines: Array, on_finish: Callable = Callable()) -> void:
	_lines     = lines
	_current   = 0
	_on_finish = on_finish
	_active    = true
	visible    = true
	_set_player_movement_locked(true)
	_layout()
	_show_current()


func hide_dialog() -> void:
	_active  = false
	visible  = false
	_lines   = []
	_current = 0
	_set_player_movement_locked(false)
	
func _set_player_movement_locked(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	if players[0].has_method("set_movement_locked"):
		players[0].set_movement_locked(locked)


# ── Navegación ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		_advance()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func _advance() -> void:
	_current += 1
	if _current >= _lines.size():
		hide_dialog()
		emit_signal("dialog_finished")
		if _on_finish.is_valid():
			_on_finish.call()
	else:
		_show_current()


func _show_current() -> void:
	var entry = _lines[_current]
	var text: String = entry if entry is String else entry.get("text", "")
	_text_label.text = text
	_hint_label.text = "[E] Continuar" if _current < _lines.size() - 1 else "[E] Cerrar"
