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

func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="user://review_smoke_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	var menu=get_tree().current_scene
	check(menu.name=="MainMenu" and menu.btn_single.is_visible_in_tree(),"packaged main menu and play button loaded")
	check(FileAccess.file_exists("res://data/balance.json") and GameState.material_defs.has("metal"),"JSON balance included in exported pack")
	check(preload("res://scripts/ui/salvage_ui.gd").image("metal")!=null,"dynamic item image included in exported pack")
	menu._on_single_pressed()
	await frames(40)
	var players=get_tree().get_nodes_in_group("players")
	check(players.size()==1,"single-player world creates exactly one player")
	check(get_tree().get_nodes_in_group("scrap").size()>=120,"export includes the initial scrap population")
	if players.size()==1:
		check(players[0].camera.current,"first-person camera is active")
		check(GameState.get_inventory_capacity(1)==20,"fresh reviewer starts with 20 kg bag")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var image=get_viewport().get_texture().get_image()
			var screenshot: String=OS.get_environment("SCRAP_REVIEW_SCREENSHOT")
			if not screenshot.is_empty(): image.save_png(screenshot)
		players[0]._open_pause_menu()
		await frames(6)
	get_tree().paused=false
	await SessionState._cleanup_and_return_to_menu()
	await frames(10)
	print("REVIEW_EXPORT_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
