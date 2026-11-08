extends Node
## Interactive QA profile. Never loads or grants currency to the owner's save directory.
func _ready() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/manual_%d/" % Time.get_unix_time_from_system()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	DisplayServer.window_set_title("Scrap Empire — QA sandbox")
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
	if OS.get_cmdline_user_args().has("--workshop"):
		# The normal menu initializes persisted input bindings before entering a world.
		for frame in 120:
			await get_tree().physics_frame
			if get_tree().current_scene!=null and get_tree().current_scene.name=="MainMenu" and not InputMap.action_get_events("interact").is_empty():
				break
		# Isolated review fixture: prepare prerequisites, never the owner's progression.
		GameState.completed_orders=GameState.order_defs.slice(0,2).map(func(order):return order.id)
		GameState.team_upgrade_levels.tool=1
		GameState.yard_level=1
		GameState.workshop_modules.workbench=1
		SessionState.start_single_player()
		var player
		for frame in 120:
			await get_tree().physics_frame
			player=get_tree().get_first_node_in_group("players")
			if player!=null:
				break
		if player==null:
			push_error("QA workshop player did not load")
			return
		for frame in 3:
			await get_tree().physics_frame
		player.position=Vector3(4,0.08,24.2)
		player.velocity=Vector3.ZERO
		player.rotation=Vector3.ZERO
		player.camera.rotation=Vector3.ZERO
		player.camera.look_at(Vector3(4,1.3,26.4))
		player.look_rotation=Vector2(player.camera.rotation.x,player.camera.rotation.y)
		player.camera.rotation.y=0
		print("QA_WORKSHOP_READY · isolated profile: "+SaveService.SAVE_DIR)
		return
