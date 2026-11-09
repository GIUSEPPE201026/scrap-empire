extends Node
## Explicitly selected QA scene; normal boot never runs this or changes save paths.
var failures: int=0
var checks: int=0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks+=1
	if value: print("REVIEW PASS: "+description)
	else:
		failures+=1
		push_error("REVIEW FAIL: "+description)

func frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func wait_for_scene(scene_name: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.name == scene_name and scene.is_node_ready():
			return true
	return false

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="user://review_smoke_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	Localization.settings_path=SaveService.SAVE_DIR+"settings.cfg"
	Localization.set_language("it")
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	if not await wait_for_scene("MainMenu"):
		check(false,"main menu loads before timeout")
		get_tree().quit(1)
		return
	var menu=get_tree().current_scene
	check(menu.name=="MainMenu" and menu.btn_single.is_visible_in_tree(),"packaged main menu and play button loaded")
	check(FileAccess.file_exists("res://data/balance.json") and GameState.material_defs.has("metal"),"JSON balance included in exported pack")
	check(preload("res://scripts/ui/salvage_ui.gd").image("metal")!=null,"dynamic item image included in exported pack")
	check(ProjectSettings.get_setting("application/config/version","")=="0.2.0","packaged version identifies demo v2")
	check(FileAccess.file_exists("res://data/localization/en.json") and FileAccess.file_exists("res://data/localization/it.json"),"both language catalogs are included")
	Localization.set_language("en")
	check(Localization.text("GIOCA")=="PLAY" and preload("res://scripts/gameplay/scrap_catalog.gd").item_name(0,0)=="Brake disc","English menu and scrap names work in exported build")
	Localization.set_language("it")
	check(Localization.text(GameState.module_defs.motor.description)=="Velocità e ripresa di entrambi i mezzi","Italian legacy text repair included in exported build")
	var models: bool=true
	for key in ["dirtbike","skateboard","forklift","crane","loader","bale_pallet","battery_pack","yard_wall","yard_canopy","yard_platform"]:
		models=models and ResourceLoader.exists("res://assets/ui/catalog/%s.png" % key)
	check(models,"new model previews are exported")
	check(GameState.logistics_def.industrial_jobs.size()==3 and GameState.logistics_def.industrial_jobs.forklift.tiers.size()==3,"industrial job definitions are exported")
	check(GameState.logistics_def.crafting.handcart.towing.dirtbike.capacity_kg==20 and preload("res://scripts/gameplay/cart_hitch.gd").supported(null)==false,"trailer limits and hitch service are exported")
	menu._on_single_pressed()
	await frames(40)
	var players=get_tree().get_nodes_in_group("players")
	check(players.size()==1,"single-player world creates exactly one player")
	check(get_tree().get_nodes_in_group("scrap").size()>=120,"export includes the initial scrap population")
	if players.size()==1:
		check(players[0].camera.current,"first-person camera is active")
		check(GameState.get_inventory_capacity(1)==20,"fresh reviewer starts with 20 kg bag")
		check(GameState.team_credits==0,"download contains no developer currency grant")
		check(SaveService.save_checkpoint(912) and SaveService.load_save(912),"exported game saves and reloads isolated progression")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var image=get_viewport().get_texture().get_image()
			var screenshot: String=OS.get_environment("SCRAP_REVIEW_SCREENSHOT")
			if not screenshot.is_empty(): image.save_png(screenshot)
		players[0]._open_pause_menu()
		await frames(6)
		check(get_tree().paused,"single-player pause stops the world")
	get_tree().paused=false
	await SessionState._cleanup_and_return_to_menu()
	await frames(10)
	check(get_tree().current_scene.name=="MainMenu" and get_tree().get_nodes_in_group("players").is_empty(),"return to menu removes the previous player")
	get_tree().current_scene._on_single_pressed()
	await frames(40)
	check(get_tree().get_nodes_in_group("players").size()==1,"second expedition has exactly one player")
	await SessionState._cleanup_and_return_to_menu()
	await frames(10)
	print("REVIEW_EXPORT_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
