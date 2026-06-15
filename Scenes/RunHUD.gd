# RunHUD.gd

extends CanvasLayer

@onready var health_bar:     ProgressBar  = $MarginContainer/VBoxContainer/HBoxContainer/HealthBar
@onready var health_label:   Label        = $MarginContainer/VBoxContainer/HBoxContainer/HealthLabel
@onready var ammo_label:     Label        = $MarginContainer/VBoxContainer/HBoxContainer2/AmmoLabel
@onready var reload_label:   Label        = $MarginContainer/VBoxContainer/HBoxContainer2/ReloadLabel
@onready var dash_container: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer3/DashContainer
@onready var gold_label:     Label        = $GoldLabel

var _gun:    Node = null
var _player: Node = null
var _dash_icons: Array = []


func _ready() -> void:
	RunManager.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(RunManager.get_display_gold())
	reload_label.hide()
	call_deferred("_connect_player")


func _connect_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_player = players[0]
	_gun    = _player.get_node_or_null("Gun")

	if _gun and _gun.has_signal("ammo_changed"):
		_gun.ammo_changed.connect(_on_ammo_changed)
		var info: Dictionary = _gun.get_ammo_info()
		_on_ammo_changed(info["current"], info["max"])

	# Crear íconos de dash según las cargas del jugador
	var charges: int = _player._dash_charges if "_dash_charges" in _player else 1
	_build_dash_icons(charges)


func _build_dash_icons(count: int) -> void:
	for child in dash_container.get_children():
		child.queue_free()
	_dash_icons.clear()

	for i in range(count):
		var icon := ColorRect.new()
		icon.size             = Vector2(14, 14)
		icon.custom_minimum_size = Vector2(14, 14)
		icon.color            = Color(0.3, 0.7, 1.0)
		dash_container.add_child(icon)
		_dash_icons.append(icon)


func _process(_delta: float) -> void:
	# Vida
	var hp:     float = RunManager.player_current_health
	var max_hp: float = RunManager.player_max_health
	health_bar.max_value = max_hp
	health_bar.value     = hp
	health_label.text    = "%d / %d" % [int(hp), int(max_hp)]
	var ratio: float = hp / max(max_hp, 1.0)
	health_bar.modulate = Color(0.2, 0.9, 0.2) if ratio > 0.5 else \
						  Color(0.9, 0.7, 0.1) if ratio > 0.25 else \
						  Color(0.9, 0.2, 0.2)

	# Recargando
	if _gun and _gun.has_method("get_ammo_info"):
		reload_label.visible = _gun.get_ammo_info().get("reloading", false)

	# Dash charges
	if _player and "_dash_charges_left" in _player:
		var left:  int = _player._dash_charges_left
		var total: int = _player._dash_charges
		# Reconstruir si cambia el total (ej: Tambor Ceremonial equipado)
		if _dash_icons.size() != total:
			_build_dash_icons(total)
		for i in range(_dash_icons.size()):
			var icon: ColorRect = _dash_icons[i]
			if i < left:
				icon.color = Color(0.3, 0.7, 1.0)      # azul: carga disponible
			else:
				icon.color = Color(0.15, 0.2, 0.3)      # oscuro: en cooldown


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_label.text = "🔹 %d / %d" % [current, max_ammo]


func _on_gold_changed(new_amount: int) -> void:
	gold_label.text = "🪙 %d" % new_amount
