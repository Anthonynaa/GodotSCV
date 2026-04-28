extends Node

func _ready():
	# Make game render at N64 resolution (320x240)
	get_viewport().size = Vector2(320, 240)
	
	# Make it stretch to fill your window
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP, Vector2(320, 240))
	
	
	Engine.target_fps = 30
