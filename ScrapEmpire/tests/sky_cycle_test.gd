extends "res://tests/crafting_test.gd"

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/sky_cycle_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(25)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	var clock = get_tree().get_first_node_in_group("yard_clock")
	var environment: Environment = sector.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = sector.get_node("DirectionalLight3D_Sun")
	var camera = Camera3D.new()
	sector.add_child(camera)
	camera.position=Vector3(-14,3,-1)
	camera.look_at(Vector3(0,2,25))
	camera.make_current()
	player.get_node("HUD").hide()
	var day: float = GameState.logistics_def.day_seconds
	GameState.operations.world_seconds=day/6.0
	clock.refresh_visuals()
	await frames(20)
	check(sun.light_energy>0.9 and sun.global_basis.z.y>0,"noon sun illuminates world from above horizon")
	if DisplayServer.get_name()!="headless":
		check(environment.background_mode==Environment.BG_SKY and environment.sky!=null,"rendered environment uses sky instead of flat color")
		var material = environment.sky.sky_material
		check(material is ShaderMaterial and material.get_shader_parameter("daylight")>0.99,"actual sky shader receives daylight and tracked sun")
		await capture("sky_noon")
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		check(image.get_pixel(image.get_width()/2,image.get_height()/10).v>0.25,"daytime sky actually renders visible color instead of black output")
	GameState.operations.world_seconds=day*10.0/24.0
	clock.refresh_visuals()
	await frames(20)
	check(sun.light_energy<0.01 and absf(sun.global_basis.z.y)<0.03,"sunset reaches actual horizon without permanent daytime lighting")
	await capture("sky_sunset")
	GameState.operations.world_seconds=day*16.0/24.0
	clock.refresh_visuals()
	await frames(20)
	check(sun.light_energy==0 and sun.global_basis.z.y<0,"night sun moves below horizon and stops shining through ground")
	if DisplayServer.get_name()!="headless":
		check(environment.sky.sky_material.get_shader_parameter("daylight")<0.01,"night shader enables moon stars and dark colors")
	await capture("sky_night")
	player._open_pause_menu()
	var seconds: float = GameState.operations.world_seconds
	var cloud_seconds: float = float(environment.sky.sky_material.get_shader_parameter("world_seconds")) if environment.sky!=null else seconds
	await frames(30)
	check(is_equal_approx(GameState.operations.world_seconds,seconds),"world clock does not advance while sky or other menu visible in pause")
	if environment.sky!=null:
		check(is_equal_approx(float(environment.sky.sky_material.get_shader_parameter("world_seconds")),cloud_seconds),"cloud wind shares pauseable world time rather than shader wall clock")
	player._close_pause_menu()
	check(SaveService.save_checkpoint(98),"night world time checkpoints")
	GameState.operations.world_seconds=0
	check(SaveService.load_save(98) and GameState.operations.world_seconds>day*0.65,"loading resumes same night with no offline jump")
	clock.refresh_visuals()
	check(sun.light_energy==0,"loaded night restores proper sunlight state")
	print("SKY_CYCLE_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
