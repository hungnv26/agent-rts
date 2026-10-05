extends MeshInstance3D

# The unexplored-area shroud (shroud.gdshader) as a full-screen quad on the camera.


func _init():
	var quad = QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	var noise = FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var tex = NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	var mat = ShaderMaterial.new()
	mat.shader = load("res://source/agent/shroud.gdshader")
	mat.set_shader_parameter("noise_tex", tex)
	mat.render_priority = -10  # under the name plates and labels, over the world
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0  # the quad is placed in the vertex shader; never cull it
	position = Vector3(0, 0, -1)


func set_area(centre: Vector2, half_size: Vector2):
	material_override.set_shader_parameter("centre", centre)
	material_override.set_shader_parameter("half_size", half_size)
