extends KinematicBody


enum Anim {
	FLOOR,
	AIR,
}

const SHOOT_TIME = 1.5
const SHOOT_SCALE = 2
const CHAR_SCALE = Vector3(0.3, 0.3, 0.3)
const MAX_SPEED = 5
const TURN_SPEED = 40
const JUMP_VELOCITY = 8.5
const BULLET_SPEED = 20
const AIR_IDLE_DEACCEL = false
const ACCEL = 20.0
const DEACCEL = 20.0
const AIR_ACCEL_FACTOR = 0.6
const SHARP_TURN_THRESHOLD = 140

var movement_dir = Vector3()
var linear_velocity = Vector3()
var jumping = false
var prev_shoot = false
var shoot_blend = 0

var red_coins = 0
var total_red_coins_needed = 8
var star_spawned = false

var score = 0

onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")


func _ready():
	get_node("AnimationTree").set_active(true)


func _physics_process(delta):
	linear_velocity += gravity * delta

	var anim = Anim.FLOOR

	var vv = linear_velocity.y # Vertical velocity.
	var hv = Vector3(linear_velocity.x, 0, linear_velocity.z) # Horizontal velocity.

	var hdir = hv.normalized() # Horizontal direction.
	var hspeed = hv.length() # Horizontal speed.

	# Player input.
	var cam_basis = get_node("Target/Camera").get_global_transform().basis
	var movement_vec2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir = cam_basis * Vector3(movement_vec2.x, 0, movement_vec2.y)
	dir.y = 0
	dir = dir.normalized()

	var jump_attempt = Input.is_action_pressed("jump")
	var shoot_attempt = Input.is_action_pressed("shoot")

	if is_on_floor():
		var sharp_turn = hspeed > 0.1 and rad2deg(acos(dir.dot(hdir))) > SHARP_TURN_THRESHOLD

		if dir.length() > 0.1 and not sharp_turn:
			if hspeed > 0.001:
				hdir = adjust_facing(hdir, dir, delta, 1.0 / hspeed * TURN_SPEED, Vector3.UP)
			else:
				hdir = dir

			if hspeed < MAX_SPEED:
				hspeed += ACCEL * delta
		else:
			hspeed -= DEACCEL * delta
			if hspeed < 0:
				hspeed = 0

		hv = hdir * hspeed

		var mesh_xform = get_node("Armature").get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - Vector3.UP * facing_mesh.dot(Vector3.UP)).normalized()

		if hspeed > 0:
			facing_mesh = adjust_facing(facing_mesh, dir, delta, 1.0 / hspeed * TURN_SPEED, Vector3.UP)
		var m3 = Basis(-facing_mesh, Vector3.UP, -facing_mesh.cross(Vector3.UP).normalized()).scaled(CHAR_SCALE)

		get_node("Armature").set_transform(Transform(m3, mesh_xform.origin))

		if not jumping and jump_attempt:
			vv = JUMP_VELOCITY
			jumping = true
			get_node("SoundJump").play()
	else:
		anim = Anim.AIR

		if dir.length() > 0.1:
			hv += dir * (ACCEL * AIR_ACCEL_FACTOR * delta)
			if hv.length() > MAX_SPEED:
				hv = hv.normalized() * MAX_SPEED
		elif AIR_IDLE_DEACCEL:
			hspeed = hspeed - (DEACCEL * AIR_ACCEL_FACTOR * delta)
			if hspeed < 0:
				hspeed = 0
			hv = hdir * hspeed

	if jumping and vv < 0:
		jumping = false

	linear_velocity = hv + Vector3.UP * vv

	if is_on_floor():
		movement_dir = linear_velocity

	linear_velocity = move_and_slide(linear_velocity, -gravity.normalized())

	if shoot_blend > 0:
		shoot_blend -= delta * SHOOT_SCALE
		if (shoot_blend < 0):
			shoot_blend = 0

	if shoot_attempt and not prev_shoot:
		shoot_blend = SHOOT_TIME
		var bullet = preload("res://player/bullet/bullet.tscn").instance()
		bullet.set_transform(get_node("Armature/Bullet").get_global_transform().orthonormalized())
		get_parent().add_child(bullet)
		bullet.set_linear_velocity(get_node("Armature/Bullet").get_global_transform().basis[2].normalized() * BULLET_SPEED)
		bullet.add_collision_exception_with(self) # Add it to bullet.
		get_node("SoundShoot").play()

	prev_shoot = shoot_attempt

	if is_on_floor():
		$AnimationTree["parameters/walk/blend_amount"] = hspeed / MAX_SPEED

	$AnimationTree["parameters/state/current"] = anim
	$AnimationTree["parameters/air_dir/blend_amount"] = clamp(-linear_velocity.y / 4 + 0.5, 0, 1)
	$AnimationTree["parameters/gun/blend_amount"] = min(shoot_blend, 1.0)


func adjust_facing(p_facing, p_target, p_step, p_adjust_rate, current_gn):
	var n = p_target # Normal.
	var t = n.cross(current_gn).normalized()

	var x = n.dot(p_facing)
	var y = t.dot(p_facing)

	var ang = atan2(y,x)

	if abs(ang) < 0.001: # Too small.
		return p_facing

	var s = sign(ang)
	ang = ang * s
	var turn = ang * p_adjust_rate * p_step
	var a
	if ang < turn:
		a = ang
	else:
		a = turn
	ang = (ang - a) * s

	return (n * cos(ang) + t * sin(ang)) * p_facing.length()

func collect_red_coin():
	red_coins += 1
	print("Red Coins: ", red_coins)  # Debug output
	update_red_coin_display()
	if red_coins >= total_red_coins_needed and not star_spawned:
		spawn_star()

func update_red_coin_display():
	# Find or create the UI label
	var ui = get_node("/root/Stage/UI")  # Adjust path as needed
	if ui and ui.has_node("RedCoinCounter"):
		ui.get_node("RedCoinCounter").text = "Red coins:" + str(red_coins) + '/8'

func spawn_star():
	star_spawned = true
	print("All red coins collected! Star appearing!")
	
	# Load and spawn the star
	var star_scene = preload("res://star/star.tscn")
	var star = star_scene.instance()
	
	# Spawn above the player
	var spawn_position = global_transform.origin + Vector3(0, 5, 0)
	star.global_transform.origin = spawn_position
	
	# Add to the world (get_parent() gets the level/main scene)
	get_parent().add_child(star)
	
	# Optional: Play fanfare sound
	play_star_appear_sound()

func play_star_appear_sound():
	var audio = AudioStreamPlayer.new()
	var sound = preload("res://star/star.mp3")  # Use your sound path
	if sound:
		audio.stream = sound
		audio.volume_db = -5
		get_parent().add_child(audio)
		audio.play()
		yield(audio, "finished")
		audio.queue_free()

func collect_star():
	print("STAR COLLECTED! Level complete!")
	update_star_display()
	show_victory_message()
	
func update_star_display():
	# Find or create the UI label
	var ui = get_tree().get_root().find_node("UI", true, false)
	if ui and ui.has_node("StarCounter"):
		ui.get_node("StarCounter").text = "Star:" + "Yes"

func add_score(amount):
	score += amount
	print("Score: ", score)  # Debug output
	update_score_display()

func update_score_display():
	var ui = get_tree().get_root().find_node("UI", true, false)
	if ui and ui.has_node("ScoreCounter"):
		ui.get_node("ScoreCounter").text = "Score: " + str(score)

func show_victory_message():
	# Create the UI layer
	var canvas = CanvasLayer.new()
	get_tree().get_root().add_child(canvas)
	
	# Create label
	var label = Label.new()
	label.text = "YOU WON!"
	label.align = Label.ALIGN_CENTER
	
	# Apply your font
	var font = preload("res://VictoryFont.tres")
	label.add_font_override("font", font)
	
	# Center the label
	label.rect_size = Vector2(400, 100)
	label.rect_position = Vector2(
		get_viewport().size.x / 2 - 200,
		get_viewport().size.y / 2 - 50
	)
	
	# Add to screen
	canvas.add_child(label)
	
	# Wait 3 seconds then remove
	yield(get_tree().create_timer(3.0), "timeout")
	canvas.queue_free()
