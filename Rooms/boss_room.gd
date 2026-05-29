extends Node2D

var boss_alive: bool = true

func _ready():
	for child in get_children():
		if child.is_in_group("Enemy"):
			child.died.connect(_on_boss_died)
	var exit_door = get_node_or_null("ExitDoor")
	if exit_door:
		exit_door.body_entered.connect(_on_exit_door_body_entered)

func _on_boss_died():
	boss_alive = false
	var exit_door = get_node_or_null("ExitDoor")
	if exit_door and exit_door.has_method("unlock"):
		exit_door.unlock()

func _on_exit_door_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not boss_alive:
		await get_tree().create_timer(0.5).timeout
		RunManager.complete_run()
