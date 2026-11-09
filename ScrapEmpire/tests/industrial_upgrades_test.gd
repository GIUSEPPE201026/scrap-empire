extends "res://tests/crafting_test.gd"
func run() -> void:
	SaveService.SAVE_DIR="res://test_logs/industrial_upgrades_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	GameState.completed_orders=[GameState.order_defs[0].id,GameState.order_defs[1].id,GameState.order_defs[2].id]
	GameState.team_credits=5000
	check(not GameState.purchase_module("hydraulics") and GameState.team_credits==5000,"industrial upgrades require an owned machine")
	GameState.yard_level=1
	GameState.operations.mobility={"owned":["forklift"],"portable":"scooter"}
	check(GameState.purchase_module("hydraulics") and GameState.team_credits==4100,"hydraulics tier one debits configured price")
	check(is_equal_approx(GameState.module_effect("hydraulics"),1.2),"hydraulics supplies explicit lift speed multiplier")
	check(GameState.purchase_module("hydraulics") and GameState.team_credits==2200,"hydraulics second tier purchases separately")
	check(not GameState.purchase_module("hydraulics") and GameState.team_credits==2200,"advanced tier respects campaign and money gates")
	check(GameState.purchase_module("industrial_drive") and GameState.team_credits==1000,"industrial transmission purchase charges once")
	check(SaveService.save_checkpoint(106) and SaveService.load_save(106) and GameState.workshop_modules.hydraulics==2 and GameState.workshop_modules.industrial_drive==1,"industrial upgrades survive disk roundtrip")
	var bad: Dictionary=GameState.serialize().duplicate(true)
	bad.workshop_modules.hydraulics=4
	check(not SaveService._validate_save_schema(bad),"out of range hydraulic upgrade rejected on disk")
	print("INDUSTRIAL_UPGRADES_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
