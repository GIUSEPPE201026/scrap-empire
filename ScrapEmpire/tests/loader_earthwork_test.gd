extends "res://tests/crafting_test.gd"
const WORK=preload("res://scripts/gameplay/loader_earthwork.gd")
func run() -> void:
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/earthwork_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(10)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	GameState.yard_level=2
	GameState.team_credits=5000
	check(preload("res://scripts/economy/extra_mobility.gd").purchase("loader"),"earthwork uses purchased loader")
	get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
	var machine=get_tree().get_nodes_in_group("yard_vehicles").filter(func(v):return v.vehicle_kind=="loader")[0]
	var player=get_tree().get_first_node_in_group("players")
	machine.position=Vector3(43,0.08,35)
	player.position=machine.position+Vector3(1.4,0,0)
	check(player._mount_vehicle(machine),"operator boards loader")
	await frames(20)
	var pile=StaticBody3D.new()
	pile.position=Vector3(43,0,32.8)
	get_tree().current_scene.add_child(pile)
	var piece=MeshInstance3D.new()
	piece.mesh=BoxMesh.new()
	piece.mesh.size=Vector3.ONE*0.3
	piece.position=Vector3(0,0.3,0)
	pile.add_child(piece)
	var source=preload("res://scripts/gameplay/heap_fragments.gd").new()
	source.owner_pile=pile
	source.owner_id="fixture_loader_earthwork"
	get_tree().current_scene.add_child(source)
	source.register_extra(piece,0)
	await frames(3)
	var credits: int=GameState.team_credits
	var command=InputEventKey.new()
	command.physical_keycode=KEY_H
	command.pressed=true
	inject_input(command)
	await frames(2)
	command=command.duplicate()
	command.pressed=false
	inject_input(command)
	check(source.taken.has(source.records[0].id),"H with low bucket promotes and displaces an actual heap fragment")
	var fragment: Node3D=source.taken[source.records[0].id]
	var position: Vector3=fragment.global_position
	check(position.z<32 and GameState.operations.loose_positions.has(fragment.entity_id),"earthwork persists displaced fragment identity and position")
	check(GameState.team_credits==credits and GameState.get_inventory_mass(1)==0,"moving debris creates no money or material reward")
	await snapshot_prop(player,machine,"loader_earthwork")
	var directory: String=SaveService.SAVE_DIR
	SaveService.SAVE_DIR="res://project.godot/"
	var errors: bool=Engine.print_error_messages
	Engine.print_error_messages=false
	var failed: bool=WORK.stroke(machine,player)
	Engine.print_error_messages=errors
	SaveService.SAVE_DIR=directory
	check(not failed and fragment.global_position==position,"failed earthwork checkpoint leaves physical fragment in place")
	var wall=StaticBody3D.new()
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(3,3,0.2)
	wall.add_child(shape)
	get_tree().current_scene.add_child(wall)
	wall.position=position+Vector3(0,1,-0.65)
	await frames(3)
	check(not WORK.stroke(machine,player) and fragment.global_position==position,"bucket cannot shove debris through wall")
	wall.queue_free()
	machine.lift=0.8
	check(not WORK.stroke(machine,player),"raised bucket cannot perform ground clearing")
	check(SaveService.save_checkpoint(108) and SaveService.load_save(108),"earthwork positions pass disk roundtrip")
	print("LOADER_EARTHWORK_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
