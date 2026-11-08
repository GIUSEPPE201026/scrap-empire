extends RefCounted

static var _cloud_texture: ImageTexture

static func install(environment: Environment) -> void:
	if DisplayServer.get_name()=="headless":
		return
	var sky = Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	var material = ShaderMaterial.new()
	material.shader=preload("res://assets/materials/yard_sky.gdshader")
	if _cloud_texture==null:
		var noise = FastNoiseLite.new()
		noise.seed=73427
		noise.frequency=0.025
		noise.fractal_octaves=4
		_cloud_texture=ImageTexture.create_from_image(noise.get_seamless_image(256,256))
	material.set_shader_parameter("cloud_noise",_cloud_texture)
	sky.sky_material=material
	environment.sky=sky
	environment.background_mode=Environment.BG_SKY

static func update(environment: Environment, sun: DirectionalLight3D, elevation: float, seconds: float) -> void:
	if environment.sky==null or not environment.sky.sky_material is ShaderMaterial:
		return
	var material = environment.sky.sky_material as ShaderMaterial
	var daylight: float = clampf((elevation+0.1)/0.32,0,1)
	daylight=daylight*daylight*(3.0-2.0*daylight)
	var warmth: float = 1.0-clampf(absf(elevation)*3.2,0,1)
	material.set_shader_parameter("zenith_color",Color("#071321").lerp(Color("#487ea8"),daylight))
	material.set_shader_parameter("horizon_color",Color("#263341").lerp(Color("#c4c7c9").lerp(Color("#e3ad7c"),warmth),daylight))
	material.set_shader_parameter("cloud_color",Color("#39465b").lerp(Color("#f6e5cd"),daylight))
	material.set_shader_parameter("sun_direction",sun.global_basis.z.normalized())
	material.set_shader_parameter("daylight",daylight)
	material.set_shader_parameter("world_seconds",seconds)
