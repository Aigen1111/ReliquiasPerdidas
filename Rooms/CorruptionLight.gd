# CorruptionLight.gd
# Punto de luz placeholder (glow con pulso), generado por código
class_name CorruptionLight
extends RefCounted

static func spawn(parent: Node2D, pos: Vector2, color: Color = Color(0.7, 0.3, 1.0),
		energy: float = 1.2, texture_scale: float = 2.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.position      = pos
	light.color         = color
	light.energy        = energy
	light.texture_scale = texture_scale
	light.texture       = _build_glow_texture()
	parent.add_child(light)

	var tween := light.create_tween()
	tween.set_loops()
	tween.tween_property(light, "energy", energy * 0.6, 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "energy", energy, 1.2).set_trans(Tween.TRANS_SINE)

	return light


static func _build_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))

	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width     = 256
	tex.height    = 256
	return tex
