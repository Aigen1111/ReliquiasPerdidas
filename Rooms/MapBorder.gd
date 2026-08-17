# MapBorder.gd
# Las clases base de sala (portal_room.gd, TutorialBase.gd, boss_room.gd) la
# llaman solas en su _ready(), así que cualquier sala nueva la hereda gratis.
class_name MapBorder
extends RefCounted

const TILE_SIZE: float = 16.0


## Arma el marco de oscuridad completo como hijos de `parent`.
## `tilemap` puede ser null (si no se encontró ninguno) — en ese caso no
## arma nada, para no reventar con un Rect2 vacío en una sala sin piso pintado.
static func build(parent: Node2D, tilemap: TileMapLayer,
		thickness: float = 500.0, edge_overlap: float = 16.0,
		color: Color = Color(0, 0, 0, 1)) -> void:
	if tilemap == null:
		return
	tilemap.z_index = -20
	
	var decor := _find_descendant_named(parent, "TileMapLayer_Decoraciones")
	if decor is TileMapLayer:
		decor.z_index = -5   # decoraciones: atrás del player/enemies, adelante del piso

	var r := _resolve_play_area(tilemap)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	r = r.grow(-edge_overlap)

	_build_piece(parent, Rect2(r.position.x - thickness, r.position.y - thickness, r.size.x + thickness * 2.0, thickness), color)          # arriba
	_build_piece(parent, Rect2(r.position.x - thickness, r.position.y + r.size.y, r.size.x + thickness * 2.0, thickness), color)            # abajo
	_build_piece(parent, Rect2(r.position.x - thickness, r.position.y, thickness, r.size.y), color)                                          # izquierda
	_build_piece(parent, Rect2(r.position.x + r.size.x, r.position.y, thickness, r.size.y), color)                                           # derecha



static func find_floor_tilemap(parent: Node) -> TileMapLayer:
	var by_name := _find_descendant_named(parent, "TileMapLayer_Pisos")
	if by_name is TileMapLayer:
		return by_name
	var plain := _find_descendant_named(parent, "TileMapLayer")
	if plain is TileMapLayer:
		return plain
	return _find_first_tilemaplayer(parent)


static func _find_descendant_named(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found := _find_descendant_named(child, target_name)
		if found != null:
			return found
	return null


static func _find_first_tilemaplayer(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			return child
		var found := _find_first_tilemaplayer(child)
		if found != null:
			return found
	return null


## Devuelve el área jugable en el mismo sistema de coordenadas locales que
## usa build() para levantar las paredes (Rect2 vacío si no hay tilemap de
## piso). Se usa para no dejar caer spawns fuera del mapa o dentro de un
## muro — no arma nada, solo calcula.
static func get_play_area(parent: Node) -> Rect2:
	var tilemap := find_floor_tilemap(parent)
	if tilemap == null:
		return Rect2()
	return _resolve_play_area(tilemap)


static func _resolve_play_area(tilemap: TileMapLayer) -> Rect2:
	var used := tilemap.get_used_rect()
	return Rect2(
		used.position.x * TILE_SIZE,
		used.position.y * TILE_SIZE,
		used.size.x * TILE_SIZE,
		used.size.y * TILE_SIZE
	)


static func _build_piece(parent: Node2D, rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	parent.add_child(body)

	var visual := ColorRect.new()
	visual.color = color
	visual.size = rect.size
	visual.position = -rect.size * 0.5
	visual.z_index = -10
	body.add_child(visual)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	body.add_child(col)
