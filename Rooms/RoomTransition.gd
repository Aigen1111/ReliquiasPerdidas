extends CanvasLayer
@onready var anim_player = $AnimationPlayer # Asegúrate de crear animaciones "fade_in" y "fade_out"

func fade_out():
	anim_player.play("fade_out")
	await anim_player.animation_finished

func fade_in():
	anim_player.play("fade_in")
	await anim_player.animation_finished
