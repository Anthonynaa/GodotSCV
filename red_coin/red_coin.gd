extends Area

var taken = false

func _on_coin_body_enter(body):
	if not taken and body is preload("res://player/player.gd"):
		taken = true
		get_node("Animation").play("take")
		
		body.add_score(20)
		
		# Tell player to increment counter
		body.collect_red_coin()
		
		# Play sound and remove coin immediately
		play_collection_sound()
		
		# Don't wait for sound, just wait for animation
		yield(get_node("Animation"), "animation_finished")
		queue_free()

func play_collection_sound():
	# Create temporary audio player
	var audio = AudioStreamPlayer.new()
	var sound = preload("res://coin/sound_coin.wav")
	if sound:
		audio.stream = sound
		audio.pitch_scale = 1.2
		audio.volume_db = -5
		get_parent().add_child(audio)
		audio.play()
		
		# Auto-remove when done (don't yield here)
		audio.connect("finished", audio, "queue_free")
