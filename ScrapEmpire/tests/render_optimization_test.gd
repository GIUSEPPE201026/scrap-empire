extends "res://tests/crafting_test.gd"
const Batcher = preload("res://scripts/gameplay/static_art_batch.gd")

func geometry(root: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for node in root.find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree() or node.mesh==null:
			continue
		var transform: Transform3D = root.global_transform.affine_inverse()*node.global_transform
		for vertex in node.mesh.get_faces():
			var point: Vector3 = transform*vertex
			var key: String = "%d:%d:%d:%d" % [node.material_override.get_instance_id(),roundi(point.x*10000),roundi(point.y*10000),roundi(point.z*10000)]
			result[key]=int(result.get(key,0))+1
	return result

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("RENDER_OPTIMIZATION_RESULT: 0 checks, 0 failures")
		get_tree().quit()
		return
	get_tree().current_scene=null
	SaveService.SAVE_DIR="res://test_logs/render_opt_%d/" % Time.get_ticks_usec()
	SaveService._ensure_save_dir()
	SessionState.progression_loaded=true
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(8)
	get_tree().current_scene._on_single_pressed()
	await frames(30)
	var player = get_tree().get_first_node_in_group("players")
	var sector = get_tree().get_first_node_in_group("sector")
	var stats: Dictionary = sector.get_meta("static_art_batches")
	var loose: Dictionary=sector.get_meta("loose_art_batches",{"source_meshes":0,"batches":0})
	print("STATIC_BATCH_METRICS: ",stats)
	print("MOVABLE_BATCH_METRICS: ",loose)
	check(stats.source_meshes+loose.source_meshes>900 and stats.batches+loose.batches<(stats.source_meshes+loose.source_meshes)/2,"static and movable scenery groups many draw objects without merging separate interactive identities")
	check(get_tree().get_nodes_in_group("scrap").size()==120,"all collectible identities remain independent after rendering optimization")
	var node_count: int = sector.find_children("*","MeshInstance3D",true,false).size()
	check(Batcher.build(sector)==stats and sector.find_children("*","MeshInstance3D",true,false).size()==node_count,"repeated scenery batching is idempotent")
	var fixture = Node3D.new()
	fixture.position=Vector3(50,0,30)
	fixture.rotation.y=0.45
	sector.add_child(fixture)
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	for index in 5:
		art.box(fixture,Vector3(0.3,0.4,0.5),Vector3(index*0.6,0.3,0),art.MINT).rotation.z=index*0.13
		art.cylinder(fixture,0.15,0.5,Vector3(index*0.6,0.8,0),art.MINT,24)
	var hidden = Node3D.new()
	hidden.hide()
	fixture.add_child(hidden)
	var hidden_mesh = art.box(hidden,Vector3.ONE,Vector3.ZERO,art.MINT)
	var original: Dictionary = geometry(fixture)
	var grouped: Dictionary = Batcher.object(fixture)
	await frames(3)
	check(grouped.source_meshes==10 and grouped.batches==1,"different primitive shapes sharing a material combine into one object draw")
	var combined: Dictionary = geometry(fixture)
	var before_vertices: int = 0
	var after_vertices: int = 0
	for amount in original.values(): before_vertices+=int(amount)
	for amount in combined.values(): after_vertices+=int(amount)
	check(before_vertices==after_vertices and same_geometry(original,combined),"batch preserves material and triangle positions within 0.2 mm float tolerance")
	check(is_instance_valid(hidden_mesh) and not hidden_mesh.is_visible_in_tree(),"batch never reveals a hidden descendant")
	check(Batcher.object(fixture).source_meshes==0,"movable object batching is idempotent")
	fixture.queue_free()
	var target = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.entity_id=="metal_008")[0]
	var other = get_tree().get_nodes_in_group("scrap").filter(func(node):return node.entity_id=="metal_009")[0]
	target.set_highlighted(true)
	var materials: Array = target.mesh.find_children("*","MeshInstance3D",true,false).map(func(node):return node.material_override)
	check(materials.any(func(material):return material is StandardMaterial3D and material.emission_enabled),"merged collectible retains visual targeting feedback")
	check(not other.mesh.find_children("*","MeshInstance3D",true,false).any(func(node):return node.material_override is StandardMaterial3D and node.material_override.emission_enabled),"highlight remains local to chosen collectible")
	target.set_highlighted(false)
	var before: Vector3 = target.global_position
	var visual_before: Vector3 = target.mesh.global_position
	var collision_before: Vector3 = target.collision.global_position
	target.global_position+=Vector3(1,0,0)
	check(target.mesh.global_position.distance_to(visual_before+Vector3.RIGHT)<0.01 and target.collision.global_position.distance_to(collision_before+Vector3.RIGHT)<0.01,"optimized mesh and collision still move together with individual scrap")
	target.global_position=before
	await aim(player,target)
	var other_position: Vector3 = other.global_position
	other.global_position=player.global_position
	await frames(3)
	Input.action_press("collect")
	await frames(10)
	var progress: float = player._collect_progress
	other.global_position+=Vector3(2,0,0)
	await frames(3)
	check(player._target_scrap==target and player._collect_progress>progress,"nearby scrap proximity changes cannot cancel ray-targeted collection")
	other.global_position=other_position
	await frames(190)
	Input.action_release("collect")
	await frames(3)
	check(GameState.player_inventories[1].metal==1 and not is_instance_valid(target),"optimized scrap can still be gathered through actual hold input")
	var pile = get_tree().get_nodes_in_group("landfill_piles")[0]
	var lod = pile.get_node("HeapDetailLOD")
	var camera = Camera3D.new()
	sector.add_child(camera)
	camera.position=pile.global_position+Vector3.UP*5
	camera.make_current()
	lod._process(1)
	var counts: Array = lod.batches.map(func(batch):return batch.multimesh.visible_instance_count)
	check(lod._level==0 and lod.batches.all(func(batch):return batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON),"close piles retain detailed geometry and fragment shadows")
	camera.position=pile.global_position+Vector3(100,5,0)
	lod._process(1)
	check(lod._level==1 and lod.batches.all(func(batch):return batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"distant tiny fragment shadows are replaced by mound silhouette shadow")
	check(lod.batches.map(func(batch):return batch.multimesh.visible_instance_count)==counts,"distance detail never changes recovered layer count or fragment density")
	check(lod.simplified.any(func(mesh):return mesh is TorusMesh and mesh.rings==12),"distant tyre meshes use bounded lower tessellation")
	player.camera.make_current()
	camera.queue_free()
	await capture("render_optimized_sector")
	print("RENDER_OPTIMIZATION_RESULT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func same_geometry(expected: Dictionary, actual: Dictionary) -> bool:
	var available: Dictionary = actual.duplicate()
	for key in expected:
		var coords: PackedStringArray = key.split(":")
		var amount: int = int(expected[key])
		for x in [0,-1,1]:
			for y in [0,-1,1]:
				for z in [0,-1,1]:
					var neighbor: String = "%s:%d:%d:%d" % [coords[0],coords[1].to_int()+x,coords[2].to_int()+y,coords[3].to_int()+z]
					var used: int = mini(amount,int(available.get(neighbor,0)))
					amount-=used
					available[neighbor]=int(available.get(neighbor,0))-used
		if amount>0:
			return false
	return available.values().all(func(value):return int(value)==0)

