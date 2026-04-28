extends KinematicBody

enum Anim {
	FLOOR,
	AIR,
}

const SHOOT_TIME = 1.5
const SHOOT_SCALE = 2
const CHAR_SCALE = Vector3(0.3, 0.3, 0.3)
const MAX_SPEED = 5
const SPRINT_SPEED = 8.0
const TURN_SPEED = 40
const JUMP_VELOCITY = 8.5
const BULLET_SPEED = 20
const AIR_IDLE_DEACCEL = false

const ACCEL = 20.0
const DEACCEL = 20.0
const AIR_ACCEL_FACTOR = 0.6
const SPRINT_ACCEL = 25.0

const SHARP_TURN_THRESHOLD = 140
const FRONT_FLIP_SPEED = 12.0
const FRONT_FLIP_TIME = 0.8

var movement_dir = Vector3()
var linear_velocity = Vector3()
var jumping = false
var prev_shoot = false
var shoot_blend = 0
var backflip_angle = 0.0
var frontflip_angle = 0.0
var is_frontflipping = false
var frontflip_timer = 0.0
var frontflip_dir = Vector3()

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

	var vv = linear_velocity.y
	var hv = Vector3(linear_velocity.x, 0, linear_velocity.z)

	var hdir = hv.normalized()
	var hspeed = hv.length()

	# Player input
	var cam_basis = get_node("Target/Camera").get_global_transform().basis
	var movement_vec2 = Vector2()
	
	if Input.is_action_pressed("move_left"):
		movement_vec2.x -= 1
	if Input.is_action_pressed("move_right"):
		movement_vec2.x += 1
	if Input.is_action_pressed("move_forward"):
		movement_vec2.y -= 1
	if Input.is_action_pressed("move_back"):
		movement_vec2.y += 1
	
	var dir = cam_basis * Vector3(movement_vec2.x, 0, movement_vec2.y)
	dir.y = 0
	if dir.length() > 0:
		dir = dir.normalized()

	var jump_attempt = Input.is_action_pressed("jump")
	var shoot_attempt = Input.is_action_pressed("shoot")
	var sprint_attempt = Input.is_action_pressed("move_forward") and Input.is_action_pressed("sprint")
	var frontflip_attempt = Input.is_action_just_pressed("frontflip")

	if is_on_floor():
		# Handle front flip
		if frontflip_attempt and not is_frontflipping:
			is_frontflipping = true
			frontflip_timer = FRONT_FLIP_TIME
			frontflip_angle = 0.0
			frontflip_dir = -get_node("Armature").get_global_transform().basis.z.normalized()
			frontflip_dir.y = 0
			if frontflip_dir.length() > 0:
				frontflip_dir = frontflip_dir.normalized()
			else:
				frontflip_dir = Vector3(0, 0, 1)
			vv = JUMP_VELOCITY * 0.5
			jumping = true
			get_node("SoundJump").play()
		
		var current_max_speed = SPRINT_SPEED if sprint_attempt else MAX_SPEED
		var current_accel = SPRINT_ACCEL if sprint_attempt else ACCEL
		
		var sharp_turn = hspeed > 0.1 and dir.length() > 0 and rad2deg(acos(dir.dot(hdir))) > SHARP_TURN_THRESHOLD

		if dir.length() > 0.1 and not sharp_turn and not is_frontflipping:
			if hspeed > 0.001:
				hdir = adjust_facing(hdir, dir, delta, 1.0 / hspeed * TURN_SPEED, Vector3.UP)
			else:
				hdir = dir

			if hspeed < current_max_speed:
				hspeed += current_accel * delta
			else:
				hspeed = current_max_speed
		else:
			hspeed -= DEACCEL * delta
			if hspeed < 0:
				hspeed = 0

		hv = hdir * hspeed

		var mesh_xform = get_node("Armature").get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - Vector3.UP * facing_mesh.dot(Vector3.UP)).normalized()

		if hspeed > 0 and not is_frontflipping:
			if dir.length() > 0.1:
				facing_mesh = adjust_facing(facing_mesh, dir, delta, 1.0 / hspeed * TURN_SPEED, Vector3.UP)
		
		var m3 = Basis(-facing_mesh, Vector3.UP, -facing_mesh.cross(Vector3.UP).normalized())
		
		# Apply front flip
		if is_frontflipping:
			frontflip_timer -= delta
			frontflip_angle += delta * (TAU / FRONT_FLIP_TIME)
			
			if frontflip_timer <= 0:
				is_frontflipping = false
				frontflip_angle = 0.0
			else:
				hv = frontflip_dir * FRONT_FLIP_SPEED
				vv = JUMP_VELOCITY * 0.3
				var flip_axis = frontflip_dir.cross(Vector3.UP).normalized()
				if flip_axis.length() > 0:
					var flip_basis = Basis(flip_axis, frontflip_angle)
					m3 = flip_basis * m3
		
		m3 = m3.scaled(CHAR_SCALE)
		get_node("Armature").set_transform(Transform(m3, mesh_xform.origin))

		if not jumping and jump_attempt and not is_frontflipping:
			vv = JUMP_VELOCITY
			jumping = true
			backflip_angle = 0.0
			get_node("SoundJump").play()
		
		if not is_frontflipping:
			backflip_angle = 0.0
	else:
		anim = Anim.AIR

		# Continue front flip in air
		if is_frontflipping:
			frontflip_timer -= delta
			frontflip_angle += delta * (TAU / FRONT_FLIP_TIME)
			
			if frontflip_timer <= 0:
				is_frontflipping = false
				frontflip_angle = 0.0
			else:
				hv = frontflip_dir * FRONT_FLIP_SPEED
		else:
			# Backflip
			backflip_angle += delta * 6.0
			if backflip_angle > TAU:
				backflip_angle -= TAU
			
			if dir.length() > 0.1:
				hv += dir * (ACCEL * AIR_ACCEL_FACTOR * delta)
				if hv.length() > MAX_SPEED:
					hv = hv.normalized() * MAX_SPEED
			elif AIR_IDLE_DEACCEL:
				hspeed = hspeed - (DEACCEL * AIR_ACCEL_FACTOR * delta)
				if hspeed < 0:
					hspeed = 0
				hv = hdir * hspeed
		
		# Apply visual rotation
		var mesh_xform = get_node("Armature").get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - Vector3.UP * facing_mesh.dot(Vector3.UP)).normalized()
		
		var m3 = Basis(-facing_mesh, Vector3.UP, -facing_mesh.cross(Vector3.UP).normalized())
		
		if is_frontflipping:
			var flip_axis = frontflip_dir.cross(Vector3.UP).normalized()
			if flip_axis.length() > 0:
				var flip_basis = Basis(flip_axis, frontflip_angle)
				m3 = flip_basis * m3
		else:
			m3 = m3.rotated(facing_mesh.normalized(), backflip_angle)
		
		m3 = m3.scaled(CHAR_SCALE)
		get_node("Armature").set_transform(Transform(m3, mesh_xform.origin))

	if jumping and vv < 0 and is_on_floor():
		jumping = false

	linear_velocity = hv + Vector3.UP * vv

	if is_on_floor():
		movement_dir = linear_velocity

	linear_velocity = move_and_slide(linear_velocity, -gravity.normalized())

	if shoot_blend > 0:
		shoot_blend -= delta * SHOOT_SCALE
		if shoot_blend < 0:
			shoot_blend = 0

	if shoot_attempt and not prev_shoot:
		shoot_blend = SHOOT_TIME
		var bullet = preload("res://player/bullet/bullet.tscn").instance()
		bullet.set_transform(get_node("Armature/Bullet").get_global_transform().orthonormalized())
		get_parent().add_child(bullet)
		bullet.set_linear_velocity(get_node("Armature/Bullet").get_global_transform().basis[2].normalized() * BULLET_SPEED)
		bullet.add_collision_exception_with(self)
		get_node("SoundShoot").play()

	prev_shoot = shoot_attempt

	if is_on_floor():
		$AnimationTree["parameters/walk/blend_amount"] = hspeed / MAX_SPEED

	$AnimationTree["parameters/state/current"] = anim
	$AnimationTree["parameters/air_dir/blend_amount"] = clamp(-linear_velocity.y / 4 + 0.5, 0, 1)
	$AnimationTree["parameters/gun/blend_amount"] = min(shoot_blend, 1.0)


func adjust_facing(p_facing: Vector3, p_target: Vector3, p_step: float, p_adjust_rate: float, current_gn: Vector3) -> Vector3:
	var n = p_target
	var t = n.cross(current_gn).normalized()

	var x = n.dot(p_facing)
	var y = t.dot(p_facing)

	var ang = atan2(y, x)
	
	if abs(ang) > 3.14:
		var result = p_facing
		result.z = 0
		return result.normalized() * p_facing.length()

	if abs(ang) < 0.001:
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
