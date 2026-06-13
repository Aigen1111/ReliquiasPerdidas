# portal_room.gd — Base compartida para todas las salas con portales dobles
# Extender este script en room.gd, rest_room.gd y reward_room.gd
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

const PORTAL_TYPES: Dictionary = {
	"combat": { "label": "⚔ Combate",  "color": Color(0.85, 0.2,  0.2,  0.9) },
	"rest":   { "label": "♥ Descanso", "color": Color(0.2,  0.75, 0.3,  0.9) },
	"reward": { "label": "★ Reliquia", "color": Color(0.9,  0.75, 0.1,  0.9) },
	"boss":   { "label": "💀 Boss",    "color": Color(0.6,  0.0,  0.8,  0.9) },
}

const PORTAL_SPREAD: float = 110.0

var is_cleared:     bool    = false
var _door_base_pos: Vector2 = Vector2.ZERO


# Llamar en _ready() de la subclase después de hacer lo propio
func _setup_portal_base() -> void:
	var door := get_node_or_null("Door")
	if door:
		_door_base_pos = door.global_position
		door.hide()


# Abre los dos portales. Llamar cuando la sala esté lista para salir.
func _open_portals() -> void:
	is_cleared = true
	var options: Array = _pick_two_options()
	var left_pos:  Vector2 = _door_base_pos + Vector2(-PORTAL_SPREAD, 0)
	var right_pos: Vector2 = _door_base_pos + Vector2( PORTAL_SPREAD, 0)
	add_child(_build_portal(left_pos,  options[0]))
	add_child(_build_portal(right_pos, options[1]))


func _pick_two_options() -> Array:
	var sequence:      Array  = RunManager.run_sequence
	var remaining_idx: int    = RunManager.current_room_index + 1
	var current_scene: String = sequence[RunManager.current_room_index] if RunManager.current_room_index < sequence.size() else ""
	var current_type:  String = _type_from_scene(current_scene)
	var streak:        int    = RunManager.non_combat_streak()

	# Solo queda el boss
	if remaining_idx >= sequence.size() - 1:
		var boss: String = sequence[sequence.size() - 1] if sequence.size() > 0 else ""
		return [
			{ "type": "boss", "scene": boss },
			{ "type": "boss", "scene": boss },
		]

	# Si el jugador lleva 2+ salas seguidas sin combate, ambos portales son combate
	if streak >= 2:
		var cs: String = _find_combat_scene(sequence, remaining_idx)
		return [
			{ "type": "combat", "scene": cs },
			{ "type": "combat", "scene": cs },
		]

	# Si lleva 1 sala sin combate, al menos una opción es combate
	if streak == 1:
		var cs:     String = _find_combat_scene(sequence, remaining_idx)
		var other:  String = _get_scene_of_different_type(sequence, remaining_idx, "combat")
		var tother: String = _type_from_scene(other)
		return [
			{ "type": "combat", "scene": cs },
			{ "type": tother,   "scene": other },
		]

	# Flujo normal: opción A diferente a la sala actual
	var scene_a: String = _get_scene_of_different_type(sequence, remaining_idx, current_type)
	var type_a:  String = _type_from_scene(scene_a)

	# Opción B: diferente de A y de la sala actual
	var scene_b: String = ""
	var type_b:  String = ""
	for i in range(remaining_idx, min(remaining_idx + 8, sequence.size())):
		var t: String = _type_from_scene(sequence[i])
		if t != type_a and t != current_type and t != "boss":
			scene_b = sequence[i]
			type_b  = t
			break

	if scene_b.is_empty():
		var pool: Array = ["combat", "rest", "reward"]
		pool.erase(type_a)
		pool.erase(current_type)
		if pool.is_empty():
			pool = ["combat"]
		type_b  = pool[randi() % pool.size()]
		scene_b = _get_alternate_scene(type_b)["scene"]

	return [
		{ "type": type_a, "scene": scene_a },
		{ "type": type_b, "scene": scene_b },
	]


func _find_combat_scene(sequence: Array, from_idx: int) -> String:
	for i in range(from_idx, sequence.size()):
		if _type_from_scene(sequence[i]) == "combat":
			return sequence[i]
	return _get_alternate_scene("combat")["scene"]

# Devuelve la primera escena en sequence desde start_idx que NO sea del tipo excluido.
# Si no encuentra ninguna, devuelve un fallback generado.
func _get_scene_of_different_type(sequence: Array, start_idx: int, exclude_type: String) -> String:
	for i in range(start_idx, sequence.size()):
		var t: String = _type_from_scene(sequence[i])
		if t != exclude_type and t != "boss":
			return sequence[i]
	# Fallback: elegir tipo distinto del excluido
	var options: Array = ["combat", "rest", "reward"]
	options.erase(exclude_type)
	return _get_alternate_scene(options[randi() % options.size()])["scene"]


func _get_alternate_scene(prefer_type: String) -> Dictionary:
	var zone: int = clamp(RunManager.current_zone_index, 0, 2)
	var prefix: String = "Z%d" % (zone + 1)
	var type_map: Dictionary = {
		"combat": "res://Rooms/Bribri/%s_Combat_A.tscn" % prefix,
		"rest":   "res://Rooms/Bribri/%s_Rest_A.tscn"   % prefix,
		"reward": "res://Rooms/Bribri/%s_Reward_A.tscn" % prefix,
	}
	return { "type": prefer_type, "scene": type_map.get(prefer_type, type_map["combat"]) }


func _type_from_scene(scene_path: String) -> String:
	if "Combat" in scene_path: return "combat"
	if "Rest"   in scene_path: return "rest"
	if "Reward" in scene_path: return "reward"
	if "Museum" in scene_path: return "museum"
	if "Boss"   in scene_path: return "boss"
	return "combat"


func _build_portal(world_pos: Vector2, option: Dictionary) -> Area2D:
	var room_type:  String = option["type"]
	var scene_path: String = option.get("scene", "")
	var info: Dictionary   = PORTAL_TYPES.get(room_type, PORTAL_TYPES["combat"])

	var area := Area2D.new()
	area.global_position = world_pos
	area.collision_layer = 0
	area.collision_mask  = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 32.0
	shape.shape = circle
	area.add_child(shape)

	var rect := ColorRect.new()
	rect.color    = info["color"]
	rect.size     = Vector2(44, 44)
	rect.position = Vector2(-22, -22)
	area.add_child(rect)

	var type_lbl := Label.new()
	type_lbl.text                    = info["label"]
	type_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.position                = Vector2(-55, -46)
	type_lbl.add_theme_font_size_override("font_size", 14)
	area.add_child(type_lbl)

	var prompt_lbl := Label.new()
	prompt_lbl.name                   = "PromptLabel"
	prompt_lbl.text                   = "[E] Entrar"
	prompt_lbl.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.position               = Vector2(-38, 26)
	prompt_lbl.add_theme_font_size_override("font_size", 12)
	prompt_lbl.hide()
	area.add_child(prompt_lbl)

	area.set_meta("scene_path", scene_path)
	area.set_meta("player_inside", false)
	area.body_entered.connect(_on_portal_body_entered.bind(area))
	area.body_exited.connect(_on_portal_body_exited.bind(area))

	return area


func _on_portal_body_entered(body: Node2D, portal: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	portal.set_meta("player_inside", true)
	var lbl: Label = portal.get_node_or_null("PromptLabel")
	if lbl:
		lbl.show()


func _on_portal_body_exited(body: Node2D, portal: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	portal.set_meta("player_inside", false)
	var lbl: Label = portal.get_node_or_null("PromptLabel")
	if lbl:
		lbl.hide()


func _process(_delta: float) -> void:
	if not is_cleared:
		return
	if not Input.is_action_just_pressed("interact"):
		return
	for child in get_children():
		if child is Area2D and child.has_meta("scene_path") and child.get_meta("player_inside", false):
			var scene: String = child.get_meta("scene_path", "")
			if not scene.is_empty():
				RunManager.choose_room(scene)
			return
