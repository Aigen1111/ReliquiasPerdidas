# TutorialHazardEmitter.gd
# Dispara TutorialHazardBolt en línea recta a intervalo fijo.
# El bolt se instancia por código (sin .tscn aparte), igual que TutorialEnemy.
extends Node2D

const HazardBoltScript := preload("res://Scenes/Tutorial/TutorialHazardBolt.gd")

@export var fire_direction: Vector2 = Vector2.RIGHT
@export var interval: float = 1.5

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.wait_time = interval
	timer.timeout.connect(_on_timer_timeout)


func start() -> void:
	_on_timer_timeout()
	timer.start()


func _on_timer_timeout() -> void:
	var bolt := Area2D.new()
	bolt.set_script(HazardBoltScript)
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position
	bolt.setup(fire_direction)
