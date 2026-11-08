extends Node
## Stable per-instance identities and analytical picking keep inactive pieces batched.
var records: Array[Dictionary]=[]
var cells: Dictionary={}
var taken: Dictionary={}
var owner_pile: Node3D
var owner_id: String=""
var scenery_piece: bool=false
var _elapsed: float=0.0

func _key() -> String:
	return owner_id if not owner_id.is_empty() else str(owner_pile.name)

func _process(delta: float) -> void:
	if not scenery_piece or not taken.is_empty(): return
	_elapsed+=delta
	if _elapsed<0.4: return
	_elapsed=0
	var player=get_tree().get_first_node_in_group("players")
	if is_instance_valid(player) and owner_pile.global_position.distance_squared_to(player.global_position)<64: promote(0)

static func register_scenery(root: Node3D) -> void:
	var totals: Dictionary={"source_meshes":0,"batches":0}
	for node in root.find_children("*","Node3D",true,false):
		if not node.has_meta("loose_scenery") or node.has_meta("heap_registered"): continue
		var ancestor: Node=node.get_parent()
		var skip: bool=false
		while ancestor!=root and ancestor!=null:
			if ancestor.is_in_group("salvage_assemblies") or ancestor.is_in_group("yard_vehicles"): skip=true
			ancestor=ancestor.get_parent()
		if skip: continue
		# Merge within the movable object's own frame, never across different props.
		var merged: Dictionary=preload("res://scripts/gameplay/static_art_batch.gd").object(node)
		totals.source_meshes+=merged.source_meshes
		totals.batches+=merged.batches
		var registry=load("res://scripts/gameplay/heap_fragments.gd").new()
		registry.owner_pile=node
		# Anonymous Node names depend on engine allocation order and scene re-entry.
		# Original authored coordinates identify these fixed-seed props consistently.
		var at: Vector3=node.global_position
		registry.owner_id="scenery_%s_%d_%d_%d" % ["car" if str(node.name).begins_with("LooseCar") else "barrel",roundi(at.x*1000),roundi(at.y*1000),roundi(at.z*1000)]
		registry.scenery_piece=true
		root.add_child(registry)
		registry.register_extra(node,0)
	root.set_meta("loose_art_batches",totals)

func _ready() -> void:
	add_to_group("heap_fragment_sources")
	call_deferred("restore")

func register_batch(batch: MultiMeshInstance3D, serial: int) -> void:
	var mesh: Mesh=batch.multimesh.mesh
	for index in batch.multimesh.instance_count:
		var transform: Transform3D=batch.global_transform*batch.multimesh.get_instance_transform(index)
		_register({"id":"heap_%s_%02d_%05d" % [_key(),serial,index],"batch":batch,"index":index,"transform":transform,"bounds":mesh.get_aabb(),"mesh":mesh,"material":batch.material_override,"color":batch.multimesh.get_instance_color(index)})

func register_extra(node: Node3D, serial: int) -> void:
	node.set_meta("heap_registered",true)
	var meshes: Array=[]
	if node is MeshInstance3D: meshes.append(node)
	meshes.append_array(node.find_children("*","MeshInstance3D",true,false))
	if meshes.is_empty(): return
	var box=AABB()
	var first: bool=true
	for mesh in meshes:
		mesh.set_meta("heap_piece_source",true)
		var local: AABB=node.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
		box=local if first else box.merge(local)
		first=false
	_register({"id":"heap_%s_extra_%03d" % [_key(),serial],"node":node,"transform":node.global_transform,"bounds":box})

func _register(record: Dictionary) -> void:
	record.inverse=record.transform.affine_inverse()
	var cell=Vector2i(floori(record.transform.origin.x/2),floori(record.transform.origin.z/2))
	if not cells.has(cell): cells[cell]=[]
	cells[cell].append(records.size())
	records.append(record)

func restore() -> void:
	for index in records.size():
		if GameState.operations.get("loose_positions",{}).has(records[index].id): promote(index)

static func pick(player: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var best: float=from.distance_to(to)
	var result: Dictionary={}
	for source in player.get_tree().get_nodes_in_group("heap_fragment_sources"):
		if source.owner_pile.global_position.distance_squared_to(from)>900: continue
		var begin=Vector2i(floori(minf(from.x,to.x)/2)-2,floori(minf(from.z,to.z)/2)-2)
		var end=Vector2i(floori(maxf(from.x,to.x)/2)+2,floori(maxf(from.z,to.z)/2)+2)
		for x in range(begin.x,end.x+1):
			for z in range(begin.y,end.y+1):
				for index in source.cells.get(Vector2i(x,z),[]):
					var record: Dictionary=source.records[index]
					if source.taken.has(record.id): continue
					if record.has("batch") and record.index>=record.batch.multimesh.visible_instance_count and record.batch.multimesh.visible_instance_count>=0: continue
					var local_hit: Variant=record.bounds.grow(0.025).intersects_segment(record.inverse*from,record.inverse*to)
					if local_hit==null: continue
					var hit: Vector3=record.transform*local_hit
					var distance: float=from.distance_to(hit)
					if distance<best:
						best=distance
						result={"source":source,"index":index,"position":hit,"distance":distance}
	return result

func promote(index: int) -> StaticBody3D:
	var record: Dictionary=records[index]
	if taken.has(record.id): return taken[record.id]
	var body=StaticBody3D.new()
	body.set_script(preload("res://scripts/gameplay/heap_fragment.gd"))
	body.entity_id=record.id
	var scale: Vector3=record.transform.basis.get_scale()
	var local_bounds: AABB=record.bounds
	body.bounds=AABB(local_bounds.position*scale,local_bounds.size*scale)
	body.fragment_mass=clampf(body.bounds.get_volume()*35,1,180)
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=body.bounds.size.max(Vector3.ONE*0.04)
	shape.position=body.bounds.get_center()
	body.add_child(shape)
	get_tree().current_scene.add_child(body)
	body.global_transform=Transform3D(record.transform.basis.orthonormalized(),record.transform.origin)
	if record.has("batch"):
		var mesh=MeshInstance3D.new()
		mesh.mesh=record.mesh
		mesh.scale=scale
		var material: Material=record.material.duplicate()
		if material is StandardMaterial3D: material.albedo_color*=record.color
		mesh.material_override=material
		mesh.visibility_range_end=170
		body.add_child(mesh)
		record.batch.multimesh.set_instance_transform(record.index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
	else:
		record.node.reparent(body)
	var position: Array=GameState.operations.get("loose_positions",{}).get(record.id,[])
	if position.size()==3: body.global_position=Vector3(position[0],position[1],position[2])
	body.rotation.y=float(GameState.operations.get("loose_rotations",{}).get(record.id,body.rotation.y))
	taken[record.id]=body
	return body
