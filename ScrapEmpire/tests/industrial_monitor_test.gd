extends "res://tests/crafting_test.gd"
func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/industrial_monitor_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player=get_tree().get_first_node_in_group("players")
	player._open_development()
	var monitor=get_tree().get_first_node_in_group("upgrade_monitor")
	monitor.active_page="modules"
	monitor._set_module_category("vehicles")
	await frames(4)
	var labels=monitor.display_viewport.find_children("*","Label",true,false)
	for name in ["Idraulica industriale","Trasmissione industriale","Ciclistica moto","Kit traino rinforzato"]:
		check(labels.any(func(label):return label.text.begins_with(name)),"vehicle monitor exposes "+name)
	check(labels.any(func(label):return label.text=="Controllo +15%"),"motorcycle handling shows control improvement rather than negative collection time")
	check(not labels.any(func(label):return label.text.contains("−-")),"new module effects never display double-negative time labels")
	await capture("industrial_upgrade_monitor")
	monitor._set_module_category("recovery")
	await frames(4)
	labels=monitor.display_viewport.find_children("*","Label",true,false)
	check(labels.any(func(label):return label.text.begins_with("Aspiratore portatile")),"recovery monitor exposes vacuum with safe icon fallback")
	await capture("vacuum_upgrade_monitor")
	monitor.close()
	print("INDUSTRIAL_MONITOR_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
