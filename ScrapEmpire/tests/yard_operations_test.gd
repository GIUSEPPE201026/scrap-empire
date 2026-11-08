extends Node
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	SaveService.SAVE_DIR = "res://test_logs/operations_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.is_host = true
	GameState.mission_phase = "MISSIONE"
	GameState.team_credits = 5000
	GameState.yard_level = 2
	GameState.vehicle_level = 2
	GameState.press_owned = true
	GameState.press_remaining = 0
	GameState.press_bales = 0
	GameState.operations = GameState.ops.empty_state()
	GameState.workshop_modules = {"workbench":1}
	GameState.player_inventories[1] = GameState.team_deposit_counts.duplicate()
	for id in GameState.team_deposit_counts:
		GameState.team_deposit_counts[id] = 0
		GameState.player_inventories[1][id] = 0
	check(GameState.ops.begin_expedition(), "first logistics epoch saves")
	GameState.ops.seed_field_parts()
	check(GameState.operations.field.size() == GameState.bulk_defs.size(), "owned lots expose all unique bulky salvage objects")
	GameState.ops.seed_field_parts()
	check(GameState.operations.field.size() == GameState.bulk_defs.size(), "world refresh cannot duplicate bulky identities")
	GameState.player_inventories[1].metal = 6
	check(GameState.ops.transfer_bag_to_cargo(1) and GameState.get_inventory_mass(1) == 0 and GameState.ops.cargo_mass() == 12, "bag transfers exact material mass into distinct buggy cargo")
	check(not GameState.ops.transfer_bag_to_cargo(1), "empty bag cannot repeat cargo transfer")
	var engine_id: String = "e1_base_engine"
	check(GameState.ops.pickup_part(engine_id) and not GameState.ops.pickup_part(engine_id), "single carried component removes its world identity once")
	check(GameState.ops.load_held() and GameState.ops.cargo_mass() == 60, "48kg engine loads beside 12kg raw cargo")
	var frame_id: String = "e1_dunes_frame"
	check(GameState.ops.pickup_part(frame_id) and not GameState.ops.load_held() and GameState.operations.held.id == frame_id, "overflow preserves carried frame and existing cargo")
	check(GameState.ops.drop_part(Vector3(0,0,10)) and GameState.operations.field[frame_id].dropped, "dropping persists a real recoverable component")
	check(not GameState.ops.begin_expedition(true), "new expedition cannot discard a component deliberately left on ground")
	check(GameState.ops.unload_cargo() and GameState.team_deposit_counts.metal == 6 and GameState.operations.stored_parts.size() == 1, "cargo unload preserves materials and component identity separately")
	check(not GameState.ops.unload_cargo(), "empty cargo unload cannot duplicate")
	GameState.team_deposit_counts.electronics = 1
	check(GameState.ops.repair_part(engine_id) and GameState.operations.stored_parts[0].quality == 1 and GameState.team_deposit_counts.metal == 4 and GameState.team_deposit_counts.electronics == 0, "repair consumes exact materials and improves stored component")
	check(not GameState.ops.repair_part(engine_id), "working component cannot consume repair materials again")
	var balance: int = GameState.team_credits
	check(GameState.ops.sell_part(engine_id) and GameState.team_credits == balance+360, "individual component sale credits its condition value")
	check(not GameState.ops.sell_part(engine_id) and GameState.team_credits == balance+360, "component sale cannot credit twice")
	check(GameState.ops.pickup_part(frame_id) and GameState.ops.store_held(), "ground component can be recovered to warehouse")
	GameState.team_deposit_counts.metal = 0
	check(GameState.ops.recycle_part(frame_id) and GameState.team_deposit_counts.metal == 40, "recycling 80kg frame yields exactly 80kg of raw metal")
	check(not GameState.ops.recycle_part(frame_id), "recycling identity is consumed once")
	GameState.team_deposit_counts.metal = 50
	check(GameState.ops.enqueue_press(3) and GameState.team_deposit_counts.metal == 35 and GameState.operations.press_queue == 2 and GameState.press_remaining == 6, "queue reserves three complete batches atomically")
	check(not GameState.ops.enqueue_press(30) and GameState.team_deposit_counts.metal == 35, "queue rejects excessive batches without reserving stock")
	check(SaveService.save_checkpoint(81), "queued production checkpoint saves")
	GameState._process(6.1)
	check(GameState.press_bales == 1 and GameState.operations.press_queue == 1 and GameState.press_remaining > 0, "press advances automatically to next reserved batch")
	check(GameState.ops.cancel_press_queue() and GameState.team_deposit_counts.metal == 40 and GameState.operations.press_queue == 0, "cancelling waiting batch refunds its exact reserved metal")
	GameState._process(6)
	check(GameState.press_bales == 2 and GameState.press_remaining == 0, "active batch still completes once after cancelling waiting jobs")
	GameState._process(10)
	check(GameState.press_bales == 2, "idle press cannot duplicate completed queue")
	check(SaveService.load_save(81) and GameState.operations.press_queue == 2 and GameState.team_deposit_counts.metal == 35 and GameState.press_bales == 0, "load resumes queue with inputs already reserved")
	GameState.operations.press_queue = 0
	GameState.press_remaining = 0
	GameState.workshop_modules.press_drive = 1
	check(not GameState.ops.set_autofeed(true), "automatic hopper requires upgraded hydraulics")
	GameState.workshop_modules.press_drive = 2
	check(GameState.ops.set_autofeed(true), "second hydraulics level and dune lot unlock automatic feeder")
	GameState.team_deposit_counts.metal = 5
	GameState._process(0.1)
	check(GameState.team_deposit_counts.metal == 0 and GameState.press_remaining > 0, "enabled feeder reserves one batch directly from depot")
	GameState.ops.set_autofeed(false)
	GameState._process(4)
	check(GameState.press_remaining == 0 and GameState.press_bales == 1, "feeder stops at empty stock without creating material")
	GameState.operations.field.clear()
	GameState.operations.held.clear()
	GameState.operations.cargo.clear()
	GameState.operations.cargo_parts.clear()
	GameState.completed_orders.clear()
	check(not GameState.ops.accept_delivery("garage_spares"), "recurring work waits for initial certification")
	for definition in GameState.order_defs:
		GameState.completed_orders.append(definition.id)
	check(GameState.ops.accept_delivery("garage_spares"), "certified yard chooses recurring supply job")
	var ticket: int = GameState.operations.active_delivery.ticket
	check(not GameState.ops.accept_delivery("municipal_load"), "one active supply job prevents hidden stacking")
	GameState.team_deposit_counts.electronics = 2
	for spec in [["battery",1],["wheel",1],["wheel",0]]:
		GameState.operations.serial += 1
		GameState.operations.stored_parts.append({"id":"part_%d" % GameState.operations.serial,"kind":spec[0],"quality":spec[1]})
	check(not GameState.ops.complete_delivery(ticket), "damaged part cannot satisfy working-spares supply")
	GameState.operations.stored_parts[2].quality = 1
	check(GameState.ops.delivery_ready(), "working parts and stock satisfy actual supply needs")
	balance = GameState.team_credits
	check(GameState.ops.complete_delivery(ticket) and GameState.team_credits == balance+520 and GameState.operations.stored_parts.is_empty() and GameState.team_deposit_counts.electronics == 0, "supply delivery consumes exact parts and materials for single reward")
	check(not GameState.ops.complete_delivery(ticket), "completed supply ticket cannot replay")
	check(GameState.ops.accept_delivery("garage_spares") and not GameState.ops.complete_delivery(ticket), "new repeat job has a different receipt identity")
	var snapshot: Dictionary = GameState.serialize().duplicate(true)
	check(SaveService.save_checkpoint(82) and SaveService.load_save(82) and GameState.operations.deliveries == 1, "cargo parts queue and recurring-work state roundtrip")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.erase("operations")
	check(GameState.deserialize(legacy) and GameState.operations.cargo.is_empty() and GameState.operations.deliveries == 0, "legacy checkpoint receives empty logistics without losing money or upgrades")
	check(SaveService.load_save(82), "new operations checkpoint restores after compatibility test")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed.operations.cargo = {"metal":1000}
	check(not SaveService._validate_save_schema(malformed), "cargo beyond capacity rejected on load")
	malformed = snapshot.duplicate(true)
	malformed.operations.stored_parts = [{"id":"same","kind":"engine","quality":1},{"id":"same","kind":"wheel","quality":1}]
	check(not SaveService._validate_save_schema(malformed), "duplicate component identities rejected on load")
	malformed = snapshot.duplicate(true)
	malformed.operations.field = {"bad":{"id":"bad","kind":"engine","quality":1,"position":[INF,0,0],"dropped":true}}
	check(not SaveService._validate_save_schema(malformed), "nonfinite component position rejected on load")
	GameState.player_inventories[1].metal = 1
	var save_dir: String = SaveService.SAVE_DIR
	SaveService.SAVE_DIR = "res://project.godot/"
	var error_output: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var failed_transfer: bool = GameState.ops.transfer_bag_to_cargo(1)
	Engine.print_error_messages = error_output
	SaveService.SAVE_DIR = save_dir
	check(not failed_transfer and GameState.player_inventories[1].metal == 1 and GameState.operations.cargo.is_empty(), "failed transfer checkpoint restores bag and cargo together")
	malformed = snapshot.duplicate(true)
	malformed.workshop_modules = "invalid"
	check(not SaveService._validate_save_schema(malformed), "malformed module collection rejects safely before validating cargo capacity")
	GameState.team_upgrade_levels.tool = 2
	GameState.operations.held.clear()
	check(not GameState.ops.claim_component("transaction_car","car",2,1,1,true).success, "engine remains inaccessible until its cover is removed")
	check(GameState.ops.claim_component("transaction_car","car",1,1,1,true).success and GameState.operations.held.kind == "wheel", "independent wheel can be recovered before the body panels")
	check(not GameState.ops.claim_component("transaction_car","car",1,1,1,false).success, "same component cannot pay both intact and raw rewards")
	check(GameState.ops.store_held(), "recovered wheel deposits before next component")
	var before_claim: Dictionary = GameState.operations.duplicate(true)
	var before_bag: Dictionary = GameState.player_inventories[1].duplicate()
	SaveService.SAVE_DIR = "res://project.godot/"
	Engine.print_error_messages = false
	var failed_claim: Dictionary = GameState.ops.claim_component("transaction_car","car",0,1,1,true)
	Engine.print_error_messages = error_output
	SaveService.SAVE_DIR = save_dir
	check(not failed_claim.success and GameState.operations == before_claim and GameState.player_inventories[1] == before_bag and GameState.ops.completed_components("transaction_car") == [1], "failed component checkpoint rolls back item identity and component receipt together")
	var before_cancel: Dictionary = GameState.team_deposit_counts.duplicate()
	check(GameState.ops.cancel_delivery() and GameState.team_deposit_counts == before_cancel, "cancelling an unreserved supply job preserves all stock")
	check(not GameState.ops.cancel_delivery(), "empty supply cancellation is harmless")
	print("OPERATIONS_TEST_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
