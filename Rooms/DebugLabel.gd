# DebugLabel.gd
# Etiqueta de depuración con el nombre del archivo de la escena actual,
# arriba a la izquierda. Solo para debug — no forma parte del HUD real.
class_name DebugLabel
extends RefCounted

static func attach(parent: Node) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	parent.add_child(canvas)

	var lbl := Label.new()
	lbl.text = parent.scene_file_path.get_file() if parent.scene_file_path != "" else parent.name
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(10, 10)
	canvas.add_child(lbl)
