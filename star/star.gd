extends Area

var collected = false

func _ready():
	connect("body_entered", self, "_on_body_entered")
	
	# Set up collision
	collision_layer = 2
	collision_mask = 1
	
	# Yellow material
	var mesh = $MeshInstance
	if mesh:
		var material = SpatialMaterial.new()
		material.albedo_color = Color(1, 0.8, 0)
		mesh.set_surface_material(0, material)

func _process(delta):
	rotate_y(delta * 3.0)  # Just spin

func _on_body_entered(body):
	if collected:
		return
	
	if body.name == "Player":
		collected = true
		body.add_score(100)
		body.collect_star()
		queue_free()
