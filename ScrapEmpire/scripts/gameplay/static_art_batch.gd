extends RefCounted
## Scenery is spatially grouped; small movable objects are merged only within their own visual root.
static func build(sector: Node3D) -> Dictionary:
	if sector.has_meta("static_art_batches"):
		return sector.get_meta("static_art_batches")
	var totals: Dictionary = {"source_meshes":0,"batches":0}
	for name in ["ScrapyardArt","CentralHubArt","WorkshopInterior","HubArchitecture","ArrivalArt","YardFence","ExplorationArt","DesertDiscoveryArt","UndergroundCave"]:
		var root = sector.get_node_or_null(NodePath(name))
		if root!=null:
			var counts: Dictionary = _merge(root,4,true)
			totals.source_meshes+=counts.source_meshes
			totals.batches+=counts.batches
	for pile in sector.get_tree().get_nodes_in_group("landfill_piles")+sector.get_tree().get_nodes_in_group("landfill_scenery"):
		var counts: Dictionary = _merge(pile,4,false)
		totals.source_meshes+=counts.source_meshes
		totals.batches+=counts.batches
	sector.set_meta("static_art_batches",totals)
	return totals

static func object(root: Node3D) -> Dictionary:
	return _merge(root,3,false)

static func _merge(root: Node3D, minimum: int, spatial: bool) -> Dictionary:
	var totals: Dictionary = {"source_meshes":0,"batches":0}
	if root.has_meta("mesh_batch_complete"):
		return totals
	root.set_meta("mesh_batch_complete",true)
	var groups: Dictionary = {}
	for node in root.find_children("*","MeshInstance3D",true,false):
		if node.has_meta("heap_piece_source") or not node.is_visible_in_tree() or node.mesh==null or node.mesh.get_surface_count()!=1 or node.material_override==null or node.skin!=null or node.visibility_range_end>0:
			continue
		var cell = Vector2i(floori(node.global_position.x/24.0),floori(node.global_position.z/24.0)) if spatial else Vector2i.ZERO
		var format: String = "primitive" if node.mesh is PrimitiveMesh else "array"
		var key: String = "%d:%d:%d:%s:%d:%d" % [cell.x,cell.y,node.material_override.get_instance_id(),format,node.cast_shadow,node.layers]
		if not groups.has(key):
			groups[key]=[]
		groups[key].append(node)
	for group in groups.values():
		if group.size()<minimum:
			continue
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var parent_inverse: Transform3D = root.global_transform.affine_inverse()
		for node in group:
			surface.append_from(node.mesh,0,parent_inverse*node.global_transform)
		var batch = MeshInstance3D.new()
		batch.name="StaticArtBatch"
		batch.mesh=surface.commit()
		batch.material_override=group[0].material_override
		batch.cast_shadow=group[0].cast_shadow
		batch.layers=group[0].layers
		root.add_child(batch)
		for node in group:
			node.queue_free()
		totals.source_meshes+=group.size()
		totals.batches+=1
	return totals
