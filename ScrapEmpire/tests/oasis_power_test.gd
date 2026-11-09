extends "res://tests/crafting_test.gd"
func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/oasis_power_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var project=get_tree().get_first_node_in_group("town_projects")
	check(not project.get_meta("completed_projects",[]).has("oasis_power"),"oasis starts without unearned power installation")
	GameState.completed_orders.assign(GameState.order_defs.map(func(spec):return spec.id))
	GameState.team_deposit_counts.electronics=10
	GameState.team_deposit_counts.rubber=10
	GameState.crafting.data().stock.battery_pack=2
	check(GameState.ops.accept_delivery("oasis_power"),"oasis power contract can be accepted after campaign")
	check(not GameState.ops.delivery_ready(),"two accumulators cannot satisfy three-product shipment")
	GameState.crafting.data().stock.battery_pack=3
	var ticket: int=int(GameState.operations.active_delivery.ticket)
	var credits: int=GameState.team_credits
	check(GameState.ops.complete_delivery(ticket) and GameState.team_credits==credits+1450,"completed shipment pays configured reward once")
	check(GameState.crafting.data().stock.battery_pack==0 and GameState.team_deposit_counts.electronics==8 and GameState.team_deposit_counts.rubber==6,"oasis shipment consumes exact products and materials")
	check(not GameState.ops.complete_delivery(ticket) and GameState.team_credits==credits+1450,"replayed shipment receipt cannot pay again")
	check(project.get_meta("completed_projects",[]).has("oasis_power"),"delivery activates persistent world project")
	if DisplayServer.get_name()!="headless":
		var lights=project.find_children("*","OmniLight3D",true,false)
		check(lights.size()>=2,"powered oasis creates actual lights")
		var camera=Camera3D.new()
		get_tree().current_scene.add_child(camera)
		var point: Vector3=preload("res://scripts/gameplay/leisure_sites.gd").OASIS+Vector3(-22,3,-8)
		camera.position=point+Vector3(9,5,12)
		camera.look_at(point+Vector3.UP)
		camera.make_current()
		await capture("oasis_power_completed")
		camera.queue_free()
	check(SaveService.save_checkpoint(107) and SaveService.load_save(107) and GameState.operations.delivery_history.oasis_power==1,"oasis progress and receipt survive disk roundtrip")
	print("OASIS_POWER_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
