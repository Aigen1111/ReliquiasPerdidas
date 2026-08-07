# EnemyLoadout.gd
# Utilidad estática máscara y arma como capas placeholder sobre el cuerpo
# base del enemigo. Geometría simple + emoji de referencia, para reemplazar
# por sprites reales más adelante sin tocar la lógica de combate.
class_name EnemyLoadout
extends RefCounted

const MASKS := {
	"jaguar":   {"color": Color(0.85, 0.5, 0.1),   "label": "🐆"},
	"danta":    {"color": Color(0.5, 0.4, 0.35),   "label": "🦌"},
	"zopilote": {"color": Color(0.15, 0.15, 0.15), "label": "🦅"},
	"harpia":   {"color": Color(0.75, 0.75, 0.78), "label": "🦅"},
}

const WEAPONS := {
	"lanza":     {"color": Color(0.6, 0.4, 0.2),   "size": Vector2(4, 30)},
	"escudo":    {"color": Color(0.4, 0.3, 0.15),  "size": Vector2(16, 22)},
	"cerbatana": {"color": Color(0.3, 0.2, 0.1),   "size": Vector2(3, 24)},
	"arco":      {"color": Color(0.55, 0.35, 0.15),"size": Vector2(4, 26)},
}


static func attach(enemy: Node2D, mask_id: String, weapon_id: String) -> void:
	_attach_mask(enemy, mask_id)
	_attach_weapon(enemy, weapon_id)


static func _attach_mask(enemy: Node2D, mask_id: String) -> void:
	if not MASKS.has(mask_id):
		return
	var data: Dictionary = MASKS[mask_id]

	var mask := ColorRect.new()
	mask.name = "MaskPlaceholder"
	mask.size = Vector2(14, 10)
	mask.position = Vector2(-7, -30)   # sobre la cabeza — ajustar cuando haya sprite real
	mask.color = data["color"]
	mask.z_index = 5
	enemy.add_child(mask)

	var lbl := Label.new()
	lbl.name = "MaskLabel"
	lbl.text = data.get("label", "")
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.position = Vector2(-8, -46)
	lbl.z_index = 6
	enemy.add_child(lbl)


static func _attach_weapon(enemy: Node2D, weapon_id: String) -> void:
	if not WEAPONS.has(weapon_id):
		return
	var data: Dictionary = WEAPONS[weapon_id]
	var sz: Vector2 = data["size"]

	var weapon := ColorRect.new()
	weapon.name = "WeaponPlaceholder"
	weapon.size = sz
	weapon.position = Vector2(10, -sz.y * 0.5)   # al costado del cuerpo
	weapon.color = data["color"]
	weapon.z_index = 5
	enemy.add_child(weapon)
