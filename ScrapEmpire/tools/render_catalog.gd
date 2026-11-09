extends Node
## Offline, original previews from the game's meshes. No save data is touched.
const ART=preload("res://scripts/gameplay/scrapyard_art.gd")
var viewport: SubViewport
var world: Node3D
var camera: Camera3D

func _ready() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	get_window().set_flag(Window.FLAG_MOUSE_PASSTHROUGH,true)
	call_deferred("render_all")

func render_all() -> void:
	viewport=SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)
	world=Node3D.new()
	viewport.add_child(world)
	var environment=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("#dfd9c9")
	environment.environment.ambient_light_energy=0.8
	world.add_child(environment)
	for direction in [Vector3(-45,-30,0),Vector3(-25,135,0)]:
		var light=DirectionalLight3D.new()
		light.rotation_degrees=direction
		light.light_energy=1.5
		world.add_child(light)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/catalog"))
	var items: Array=[]
	items.append_array(GameState.crafting.definitions().keys())
	items.append_array(["hands","screwdriver","hammer","scooter","buggy","metal","plastic","electronics","copper","aluminum","glass","rubber","wheel","panel","battery","engine"])
	if "--field-depot-only" in OS.get_cmdline_user_args(): items=["field_depot"]
	var extra: Array=["press_machine","bale"]
	for secret in GameState.secret_defs: extra.append(secret.id)
	for job in GameState.logistics_def.specific_orders:
		for key in job.items:
			if "variant_"+key not in extra: extra.append("variant_"+key)
	if "--service-panels" in OS.get_cmdline_user_args(): items=extra
	if "--current-models" in OS.get_cmdline_user_args(): items=["buggy","scooter","dirtbike","skateboard","forklift","crane","loader","bale_pallet","battery_pack","yard_wall","yard_canopy","yard_platform"]
	for id in items:
		var model: Node3D=make_model(id)
		world.add_child(model)
		model.process_mode=Node.PROCESS_MODE_DISABLED
		await get_tree().process_frame
		if id in GameState.secret_defs.map(func(secret):return secret.id):
			var original=model.get_child(0)
			original.relic.reparent(model)
			model.remove_child(original)
			original.queue_free()
		for label in model.find_children("*","Label3D",true,false): label.queue_free()
		var bounds=AABB()
		var first: bool=true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree(): continue
			var box: AABB=mesh.global_transform*mesh.get_aabb()
			bounds=box if first else bounds.merge(box)
			first=false
		camera.size=maxf(bounds.size.length()*0.95,0.3)
		var center: Vector3=bounds.get_center()
		camera.position=center+Vector3(3,2.2,-4).normalized()*maxf(8,bounds.size.length()*2)
		camera.look_at(center)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var error: Error=viewport.get_texture().get_image().save_png("res://assets/ui/catalog/%s.png" % id)
		if error!=OK:
			push_error("Preview export failed: "+id)
			get_tree().quit(1)
			return
		world.remove_child(model)
		model.queue_free()
		print("PREVIEW: ",id)
	print("CATALOG_EXPORT_RESULT: ",items.size()," previews")
	get_tree().quit()

func make_model(id: String) -> Node3D:
	var root=Node3D.new()
	var art=ART.new()
	if id=="press_machine":
		GameState.press_owned=true
		var press=Node3D.new()
		press.set_script(preload("res://scripts/gameplay/industrial_press.gd"))
		root.add_child(press)
	elif id=="bale":
		art.box(root,Vector3(1.9,0.95,1.4),Vector3.ZERO,art.MINT,true)
		for x in [-0.6,0.6]: art.box(root,Vector3(0.07,0.98,1.43),Vector3(x,0,0),art.STEEL)
	elif id in GameState.secret_defs.map(func(secret):return secret.id):
		var secret=StaticBody3D.new()
		secret.set_script(preload("res://scripts/gameplay/world_secrets.gd"))
		secret.secret_id=id
		root.add_child(secret)
	elif id.begins_with("variant_"):
		preload("res://scripts/gameplay/scrap_catalog.gd").build(root,id.get_slice("_",1).to_int(),id.get_slice("_",2).to_int(),art)
	elif id in ["handcart","work_lamp","field_depot","bale_pallet","yard_wall","yard_canopy","yard_platform"]:
		var object=CharacterBody3D.new()
		object.set_script(preload("res://scripts/gameplay/crafted_object.gd"))
		object.kind=id
		root.add_child(object)
	elif id in ["dirtbike","skateboard","forklift","crane","loader"]:
		var vehicle=preload("res://scripts/gameplay/industrial_machine.gd").new() if id in ["crane","loader"] else (preload("res://scripts/gameplay/forklift.gd").new() if id=="forklift" else preload("res://scripts/gameplay/extra_vehicle.gd").new())
		vehicle.vehicle_kind=id
		vehicle.level={"dirtbike":3,"skateboard":1,"forklift":4,"crane":5,"loader":6}[id]
		root.add_child(vehicle)
	elif id in ["scooter","buggy"]:
		var vehicle=Node3D.new()
		vehicle.set_script(preload("res://scripts/gameplay/yard_vehicle.gd"))
		vehicle.level=1 if id=="scooter" else 2
		root.add_child(vehicle)
	elif id in ["wheel","panel","battery","engine"]:
		preload("res://scripts/gameplay/haul_part.gd").build_model(root,id,1)
	elif id in ["metal","plastic","electronics","copper","aluminum","glass","rubber"]:
		preload("res://scripts/gameplay/scrap_catalog.gd").build(root,["metal","plastic","electronics","copper","aluminum","glass","rubber"].find(id),0,art)
	elif id in ["desk_lamp","toolbox","restored_radio","bench_compressor","garden_bench","battery_pack"]:
		preload("res://scripts/gameplay/product_models.gd").build(root,id)
	elif id in ["hands","screwdriver","hammer","crowbar","bolt_cutters"]:
		match id:
			"hands":
				for side in [-1,1]:
					art.beveled_box(root,Vector3(0.14,0.2,0.07),Vector3(side*0.1,0,0),art.GRAPHITE)
					for finger in 4: art.beveled_box(root,Vector3(0.025,0.1,0.05),Vector3(side*0.1-0.05+finger*0.033,0.14,0),art.MINT)
			"screwdriver":
				art.cylinder(root,0.05,0.22,Vector3.ZERO,art.RUST,24)
				art.cylinder(root,0.018,0.3,Vector3(0,0.25,0),art.STEEL,24)
				art.beveled_box(root,Vector3(0.04,0.04,0.012),Vector3(0,0.42,0),art.STEEL)
			"hammer":
				art.beveled_box(root,Vector3(0.055,0.42,0.065),Vector3.ZERO,art.RUST)
				art.beveled_box(root,Vector3(0.3,0.12,0.12),Vector3(0,0.23,0),art.STEEL)
				art.beveled_box(root,Vector3(0.05,0.15,0.05),Vector3(-0.12,0.16,0),art.STEEL)
			"crowbar":
				art.beam(root,Vector3(0,-0.3,0),Vector3(0,0.3,0),0.045,art.STEEL)
				art.beam(root,Vector3(0,0.3,0),Vector3(0.14,0.37,0),0.045,art.STEEL)
				art.beam(root,Vector3(0.14,0.37,0),Vector3(0.18,0.29,0),0.035,art.STEEL)
			"bolt_cutters":
				for side in [-1,1]:
					art.beam(root,Vector3(side*0.15,-0.3,0),Vector3(side*0.03,0.12,0),0.055,art.RUST)
					art.beam(root,Vector3(side*0.03,0.12,0),Vector3(side*0.11,0.25,0),0.06,art.STEEL)
		root.rotation.z=-0.35
	else:
		art.beveled_box(root,Vector3(0.55,0.15,0.4),Vector3(0,0.08,0),art.YELLOW,true)
		var part: String={"suspension_kit":"wheel","cargo_kit":"panel","press_kit":"engine","bag_frame":"panel"}.get(id,"")
		if not part.is_empty():
			var object=Node3D.new()
			object.position.y=0.2
			object.scale=Vector3.ONE*0.45
			root.add_child(object)
			preload("res://scripts/gameplay/haul_part.gd").build_model(object,part,1)
		else:
			art.box(root,Vector3(0.15,0.05,0.05),Vector3(0,0.19,0),Color.WHITE)
			art.box(root,Vector3(0.05,0.05,0.15),Vector3(0,0.19,0),Color.WHITE)
	return root
