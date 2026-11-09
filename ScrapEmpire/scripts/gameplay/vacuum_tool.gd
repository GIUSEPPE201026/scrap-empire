extends Node3D
var player: Node3D
var target: Node3D
var elapsed: float=0.0

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.beveled_box(self,Vector3(0.20,0.22,0.42),Vector3.ZERO,art.MINT)
	art.beam(self,Vector3.ZERO,Vector3(0,-0.04,-0.7),0.09,art.STEEL)
	art.beveled_box(self,Vector3(0.34,0.09,0.14),Vector3(0,-0.04,-0.73),art.GRAPHITE)

static func eligible(user: Node3D, item: Node3D) -> bool:
	if not is_instance_valid(item) or not item.is_in_group("scrap") or item.is_queued_for_deletion(): return false
	if int(GameState.workshop_modules.get("vacuum",0))<1: return false
	var id: String=user._scrap_type_to_material_id(item.scrap_type)
	if id not in GameState.logistics_def.vacuum.materials or float(item.mass)>float(GameState.logistics_def.vacuum.max_piece_kg): return false
	var point: Vector3=item.global_position+Vector3.UP*0.33
	var offset: Vector3=point-user.camera.global_position
	if offset.length()>GameState.module_effect("vacuum") or offset.normalized().dot(-user.camera.global_basis.z)<0.92: return false
	return user.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(user.camera.global_position,point,1,[user.get_rid(),item.get_rid()])).is_empty()

static func recover(user: Node3D, item: Node3D) -> bool:
	if not eligible(user,item): return false
	if not GameState.recover_world_scrap(user.owner_peer_id,item.entity_id,user._scrap_type_to_material_id(item.scrap_type),user._active_tool()): return false
	GameState.ops.record_discovery(int(item.scrap_type),preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(item.entity_id))
	user._collection_fx(item)
	item.collect()
	return true

func _physics_process(delta: float) -> void:
	visible=player._vacuum_active and not player._is_paused and not is_instance_valid(player._mounted_vehicle)
	if not visible or not Input.is_action_pressed("collect"):
		if player._vacuum_active: player._collect_progress_bar.visible=false
		target=null
		elapsed=0
		return
	var nearest: Node3D
	var distance: float=INF
	for item in get_tree().get_nodes_in_group("scrap"):
		if eligible(player,item) and player.camera.global_position.distance_squared_to(item.global_position)<distance:
			nearest=item
			distance=player.camera.global_position.distance_squared_to(item.global_position)
	if nearest!=target:
		target=nearest
		elapsed=0
	if not is_instance_valid(target):
		player._collect_progress_bar.visible=false
		return
	elapsed+=delta
	player._collect_progress_bar.visible=true
	player._collect_progress_bar.value=100.0*elapsed/float(GameState.logistics_def.vacuum.seconds_per_piece)
	if elapsed>=float(GameState.logistics_def.vacuum.seconds_per_piece):
		if not recover(player,target): player._notify(Localization.text("Aspiratore · controlla spazio e attrezzo richiesto"))
		target=null
		elapsed=0
		player._collect_progress_bar.visible=false
