## sector_script.gd
## Gestisce spawn player e coordinamento missione nel sector

extends Node3D

func _prepare_single_player_yard() -> void:
	for child in get_children():
		if child.name not in ["SpawnPoints", "DepositZone", "WorldEnvironment", "DirectionalLight3D_Sun"]:
			remove_child(child)
			child.queue_free()
	get_node("DirectionalLight3D_Sun").rotation_degrees = Vector3(-48, -32, 0)
	get_node("DirectionalLight3D_Sun").light_energy = 0.95
	get_node("DirectionalLight3D_Sun").shadow_enabled = true
	get_node("DirectionalLight3D_Sun").light_color = Color("#fff1df")
	var environment: Environment = get_node("WorldEnvironment").environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.82, 0.95)
	environment.ambient_light_energy = 0.35
	environment.ambient_light_sky_contribution = 0.0
	environment.adjustment_enabled = false
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = false
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9eb8c4")
	preload("res://scripts/gameplay/yard_sky.gd").install(environment)
	var clock = preload("res://scripts/gameplay/yard_clock.gd").new()
	add_child(clock)
	clock.refresh_visuals()
	spawn_points.get_child(0).position = preload("res://scripts/gameplay/arrival_area.gd").SPAWN
	var depot = get_node("DepositZone")
	depot.position = Vector3(0, 0.05, 14)
	depot.collision_layer = 0
	depot.get_node("DepositZoneCrates").queue_free()
	depot.get_node("DepositZonePad").hide()
	deposit_zone_glow.hide()
	var sign_label = Label3D.new()
	sign_label.text = "BILANCIA / SCARICO"
	sign_label.pixel_size = 0.0035
	sign_label.position = Vector3(0, 2.4, 1.5)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 44
	depot.add_child(sign_label)
	_yard_box("Floor", Vector3(160, 1, 160), Vector3(0, -0.5, 0), Color("#c79869"))
	preload("res://scripts/gameplay/yard_fence.gd").build(self)
	preload("res://scripts/gameplay/desert_world.gd").build(self)
	for side in [-1, 1]:
		_yard_box("WorldEdgeX%d" % side, Vector3(2, 45, 1280), Vector3(side * 639, 15, 0), Color("#bc9268"))
		_yard_box("WorldEdgeZ%d" % side, Vector3(1280, 45, 2), Vector3(0, 15, side * 639), Color("#bc9268"))
	preload("res://scripts/gameplay/landfill_layout.gd").build(self)
	_yard_box("GarageShellBack", Vector3(13, 4.5, 0.2), Vector3(4, 2.25, 28), Color("#467568"))
	_yard_box("GarageShellLeft", Vector3(0.2, 4.5, 6), Vector3(-2.5, 2.25, 25), Color("#467568"))
	_yard_box("GarageShellRight", Vector3(0.2, 4.5, 6), Vector3(10.5, 2.25, 25), Color("#467568"))
	_yard_box("GarageShellFrontLeft", Vector3(4, 4.5, 0.2), Vector3(-0.5, 2.25, 22), Color("#467568"))
	_yard_box("GarageShellFrontRight", Vector3(4, 4.5, 0.2), Vector3(8.5, 2.25, 22), Color("#467568"))
	_yard_box("GarageShellRoof", Vector3(13, 0.2, 6), Vector3(4, 4.5, 25), Color("#467568"))
	preload("res://scripts/gameplay/hub_layout.gd").build(self)
	preload("res://scripts/gameplay/arrival_area.gd").build(self)
	var identity=StaticBody3D.new()
	identity.set_script(preload("res://scripts/gameplay/entrance_identity.gd"))
	identity.position=Vector3(9,0,76)
	add_child(identity)
	var milestones = Node3D.new()
	milestones.set_script(preload("res://scripts/gameplay/yard_milestone_board.gd"))
	milestones.position = Vector3(-28, 0, 15)
	add_child(milestones)
	_yard_box("Barrier", Vector3(3, 2, 1), Vector3(12, 1, 12), Color(0.65, 0.43, 0.2))
	if DisplayServer.get_name() != "headless":
		var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.build(self)
		preload("res://scripts/gameplay/garage_workshop.gd").build(self)
		preload("res://scripts/gameplay/hub_refinements.gd").build(self)
		preload("res://scripts/gameplay/hub_refinements.gd").recovery_sites(self)
	var press = Node3D.new()
	press.name = "IndustrialPress"
	press.set_script(preload("res://scripts/gameplay/industrial_press.gd"))
	press.position = preload("res://scripts/gameplay/hub_layout.gd").PRESS
	add_child(press)
	for service in [{"id":"tools", "position":preload("res://scripts/gameplay/hub_layout.gd").TOOLS, "title":"MONITOR / UPGRADE"}, {"id":"vehicles", "position":preload("res://scripts/gameplay/hub_layout.gd").VEHICLES, "title":"GARAGE / VEICOLI"}, {"id":"land", "position":preload("res://scripts/gameplay/hub_layout.gd").LAND, "title":"PLANIMETRIA / TERRENI"}, {"id":"journal", "position":preload("res://scripts/gameplay/hub_layout.gd").JOURNAL, "title":"ALBUM DELLE CURIOSITÀ"}]:
		var terminal = Node3D.new()
		terminal.name = "Terminal_" + service.id
		terminal.position = service.position
		terminal.set_meta("service", service.id)
		terminal.add_to_group("service_terminal")
		if service.id == "tools":
			terminal.add_to_group("garage_terminal")
		if service.id == "tools":
			terminal.set_script(preload("res://scripts/gameplay/upgrade_monitor.gd"))
		add_child(terminal)
		if DisplayServer.get_name() != "headless" and service.id != "tools":
			var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
			if service.id == "journal":
				art.box(terminal, Vector3(0.08, 1.4, 1.4), Vector3(-1.78, 1.8, 0.5), Color("#8b7757"))
				for index in 3:
					art.box(terminal, Vector3(0.02, 0.55, 0.32), Vector3(-1.72, 1.8, 0.08 + index * 0.42), [art.MINT, art.YELLOW, art.STEEL][index])
			elif service.id == "land":
				for side in [-1, 1]:
					art.box(terminal, Vector3(0.08, 1.1, 0.7), Vector3(side * 0.65, 0.55, 0), art.GRAPHITE)
				art.box(terminal, Vector3(1.8, 0.12, 1.1), Vector3(0, 1.1, 0), Color("#384f54"))
				for index in 3:
					art.box(terminal, Vector3(0.43, 0.025, 0.7), Vector3(-0.55 + index * 0.54, 1.18, 0), art.MINT if index == 0 or GameState.yard_level >= index else art.STEEL)
			else:
				art.box(terminal, Vector3(0.65, 1.1, 0.55), Vector3(0, 0.55, 0), art.GRAPHITE)
				art.box(terminal, Vector3(0.9, 0.65, 0.1), Vector3(0, 1.45, 0), art.YELLOW)
				art.box(terminal, Vector3(0.75, 0.42, 0.02), Vector3(0, 1.45, -0.06), Color("#315b60"))
	for index in 6:
		var assembly = StaticBody3D.new()
		assembly.set_script(preload("res://scripts/gameplay/salvage_assembly.gd"))
		assembly.definition_id = ["car", "generator", "appliance"][index % 3]
		assembly.entity_id = "assembly_%d" % index
		assembly.position = Vector3(-12 + (index % 3) * 8, 0, -10 - (index / 3) * 27)
		add_child(assembly)
	for index in 3:
		var assembly = StaticBody3D.new()
		assembly.set_script(preload("res://scripts/gameplay/salvage_assembly.gd"))
		assembly.definition_id = ["generator", "car", "appliance"][index]
		assembly.entity_id = "buried_assembly_%d" % index
		var center: Vector3 = preload("res://scripts/gameplay/landfill_layout.gd").CENTERS[3 + index]
		var angle: float = index * 0.45
		assembly.position = center + Vector3(cos(angle) * 5.7, 0.55, sin(angle) * 5.7)
		assembly.position.y = preload("res://scripts/gameplay/landfill_layout.gd").surface_height(assembly.position-center,3+index)-0.25
		assembly.add_to_group("buried_assemblies")
		add_child(assembly)
	spawn_owned_vehicles()
	var logistics = Node3D.new()
	logistics.set_script(preload("res://scripts/gameplay/logistics_world.gd"))
	add_child(logistics)
	var construction = Node3D.new()
	construction.set_script(preload("res://scripts/gameplay/crafting_world.gd"))
	add_child(construction)
	var audio = Node.new()
	audio.set_script(preload("res://scripts/gameplay/yard_audio.gd"))
	add_child(audio)
	var career = Node3D.new()
	career.set_script(preload("res://scripts/gameplay/career_world.gd"))
	add_child(career)
	var town = preload("res://scripts/gameplay/town_projects.gd").new()
	add_child(town)
	var warehouse = Node3D.new()
	warehouse.set_script(preload("res://scripts/gameplay/stock_yard.gd"))
	add_child(warehouse)
	preload("res://scripts/gameplay/world_secrets.gd").build(self)
	preload("res://scripts/gameplay/exploration_sites.gd").build(self)
	var discoveries=preload("res://scripts/gameplay/desert_landmarks.gd").new()
	add_child(discoveries)
	var leisure=Node3D.new()
	leisure.set_script(preload("res://scripts/gameplay/leisure_sites.gd"))
	add_child(leisure)
	if DisplayServer.get_name()!="headless":
		preload("res://scripts/gameplay/heap_fragments.gd").register_scenery(self)
		preload("res://scripts/gameplay/static_art_batch.gd").build(self)
	GameState.land_unlocked.connect(_on_land_unlocked)

func spawn_owned_vehicles() -> void:
	for level in range(1, GameState.vehicle_level + 1):
		var found: bool = false
		for vehicle in get_tree().get_nodes_in_group("yard_vehicles"):
			if vehicle.level == level:
				found = true
		if not found:
			var vehicle = Node3D.new()
			vehicle.set_script(preload("res://scripts/gameplay/yard_vehicle.gd"))
			vehicle.level = level
			vehicle.position = Vector3(14 + level * 4, 0, 30)
			if level==2:
				var parking: Array = GameState.logistics_def.buggy_parking
				vehicle.position=Vector3(parking[0],parking[1],parking[2])
			add_child(vehicle)
			if level == 1:
				vehicle.hide()
				vehicle.body.collision_layer = 0
	for kind in GameState.operations.get("mobility",{}).get("owned",[]):
		if get_tree().get_nodes_in_group("yard_vehicles").any(func(node):return node.vehicle_kind==kind): continue
		var extra=preload("res://scripts/gameplay/industrial_machine.gd").new() if kind in ["crane","loader"] else (preload("res://scripts/gameplay/forklift.gd").new() if kind=="forklift" else preload("res://scripts/gameplay/extra_vehicle.gd").new())
		extra.vehicle_kind=kind
		extra.level={"skateboard":1,"dirtbike":3,"forklift":4,"crane":5,"loader":6}[kind]
		extra.position=Vector3(24+(extra.level-4)*6,0,25) if extra.level>=4 else Vector3(18,0,25)
		add_child(extra)
		if kind=="skateboard":
			extra.hide()
			extra.body.collision_layer=0

func _yard_box(node_name: String, dimensions: Vector3, location: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = location
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = dimensions
	body.add_child(shape)
	if DisplayServer.get_name() == "headless" or node_name.begins_with("GarageShell"):
		add_child(body)
		return
	var visual = MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.mesh.size = dimensions
	visual.material_override = StandardMaterial3D.new()
	visual.material_override.albedo_color = color
	if node_name.begins_with("Office") or node_name.begins_with("GarageShell"):
		visual.material_override = preload("res://scripts/gameplay/scrapyard_art.gd").new().surface_material(color, "rubble" if node_name.begins_with("Office") else "steel")
	if node_name == "Floor":
		visual.material_override = ShaderMaterial.new()
		visual.material_override.shader = preload("res://assets/materials/yard_ground.gdshader")
		visual.material_override.set_shader_parameter("sand_detail", load("res://assets/textures/surfaces/sand_albedo.png"))
	body.add_child(visual)
	add_child(body)

func _spawn_single_player_scrap() -> void:
	var index: int = 0
	var random = RandomNumberGenerator.new()
	random.seed = 23490
	var types: Dictionary = {"metal": 0, "plastic": 1, "electronics": 2, "copper": 3, "aluminum": 4, "glass": 5, "rubber": 6}
	for material_id in GameState.base_sector_counts:
		for count in int(GameState.base_sector_counts[material_id]):
			var scrap = _scrap_scene.instantiate()
			scrap.scrap_type = types[material_id]
			scrap.entity_id = "%s_%03d" % [material_id, count]
			scrap.mass = GameState.material_defs[material_id].mass_kg
			scrap.value = GameState.material_defs[material_id].credits
			scrap.position = preload("res://scripts/gameplay/landfill_layout.gd").scrap_position(index)
			scrap.position += Vector3(random.randf_range(-0.4, 0.4), 0, random.randf_range(-0.4, 0.4))
			if scrap.position.y > 0.1:
				scrap.add_to_group("hidden_salvage")
				var layout = preload("res://scripts/gameplay/landfill_layout.gd")
				var local: Vector3 = scrap.position-layout.CENTERS[index%layout.CENTERS.size()]
				scrap.position.y = layout.surface_height(local,index%layout.CENTERS.size())+0.2
			else:
				scrap.position.y = 0.3 if material_id == "plastic" else 0.07
			if count == 8:
				scrap.position = Vector3(-9.2 + types[material_id]*1.2,0.77,7)
				scrap.add_to_group("starter_salvage")
			var layout_profile = preload("res://scripts/gameplay/landfill_layout.gd")
			for pile in get_tree().get_nodes_in_group("landfill_piles")+get_tree().get_nodes_in_group("landfill_scenery"):
				var height: float = layout_profile.surface_height(scrap.position-pile.global_position,int(pile.get_meta("profile_zone",0)))
				scrap.position.y = maxf(scrap.position.y,pile.global_position.y+height+0.12)
			scrap.rotation.y = random.randf_range(-PI, PI)
			if scrap.entity_id in GameState.sector_consumed_ids:
				scrap.free()
			else:
				add_child(scrap)
			index += 1
	apply_land_expansions()

func _init() -> void:
	pass

@onready var spawn_points: Node3D = get_node("SpawnPoints")
@onready var deposit_zone_glow: MeshInstance3D = get_node("DepositZone/DepositZoneGlow")

# Autoload sono accessibili globalmente
# NetworkGateway e ReplicationService sono autoload

var _spawned_players: Dictionary = {}  # peer_id -> Node3D
var _player_scene: PackedScene
var _scrap_scene: PackedScene
var _glow_time: float = 0.0

func _ready() -> void:
	pass
	# Preload player scene
	_player_scene = preload("res://scenes/player.tscn")
	if not _player_scene:
		print('[SECTOR] ERROR: Failed to preload player scene')
		return

	# Preload scrap item scene
	_scrap_scene = preload("res://scenes/scrap_item.tscn")
	if not _scrap_scene:
		print('[SECTOR] ERROR: Failed to preload scrap item scene')
		return

	# Controlla se siamo in modalità single player
	# In single player: is_host=true, current_state è LOADING o MISSION, non network connected
	var is_single_player = SessionState.is_host and not NetworkGateway.is_network_connected()
	if is_single_player:
		_prepare_single_player_yard()

	# Connetti sempre mission_starting per spawnare il player (PRIMA di on_scene_loaded!)
	SessionState.mission_starting.connect(_on_mission_starting)

	# Connetti segnali di rete solo se in multiplayer
	if not is_single_player:
		NetworkGateway.peer_connected.connect(_on_peer_connected)
		NetworkGateway.peer_disconnected.connect(_on_peer_disconnected)

		# Client: ascolta entity_spawned/entity_despawned per creare/rimuovere i player locali
		if not NetworkGateway.is_host() and ReplicationService:
			ReplicationService.entity_spawned.connect(_on_entity_spawned)
			ReplicationService.entity_despawned.connect(_on_entity_despawned)

	# Spawn scrap items (120 total: 60 metal, 40 plastic, 20 electronic)
	_spawn_scrap_items()

	# Notifica che la scena è caricata
	SessionState.on_scene_loaded()

func _process(delta: float) -> void:
	# Animazione pulsante per il glow della zona deposito
	_glow_time += delta
	if deposit_zone_glow and deposit_zone_glow.material_override:
		var mat = deposit_zone_glow.material_override as StandardMaterial3D
		if mat.emission_enabled:
			var pulse = sin(_glow_time * 2.0) * 0.5 + 0.5  # 0.0 to 1.0
			mat.emission_energy_multiplier = lerp(0.5, 1.5, pulse)
			mat.emission = Color(1.0, 0.85, 0.3, 1).lerp(Color(1.0, 1.0, 0.5, 1), pulse)

func _on_mission_starting() -> void:
	# Controlla se siamo in modalità single player
	# In single player: is_host=true, non network connected
	var is_single_player = SessionState.is_host and not NetworkGateway.is_network_connected()

	if is_single_player:
		# Single player: spawna un solo player locale
		_spawn_single_player()
	else:
		# Multiplayer mode - Pattern host-authoritative: l'host spawna tutti i player con authority=host
		if NetworkGateway.is_host():
			var peers = NetworkGateway.get_connected_peers()

			# Host spawna il proprio player (peer 1)
			_spawn_player_for_peer(1)

			# Host spawna i player dei client
			for peer_id in peers:
				_spawn_player_for_peer(peer_id)
		else:
			# Client non fa nulla - attende che l'host spawni i player e assegni via RPC
			pass

func _spawn_single_player() -> void:
	if not _player_scene:
		print('[SECTOR] ERROR: Player scene not loaded')
		return

	# Istanzia il player
	var player = _player_scene.instantiate()
	if not player:
		print('[SECTOR] ERROR: Failed to instantiate single player')
		return

	# Aggiungi alla scena
	add_child(player)

	# Posiziona allo spawn point 1
	var spawn_point = _get_spawn_point(1)
	player.global_position = spawn_point.global_position
	print('[SECTOR] Single player spawned at ', spawn_point.global_position, ' player global_pos: ', player.global_position)

	# Registra localmente
	_spawned_players[1] = player

	# Aggiungi al gruppo per ricerca
	player.add_to_group("players")

	# Configura come player locale (senza networking)
	player.set_as_local_player(1)
	player.set_single_player_mode(true)
	player.local_expedition_epoch=int(GameState.operations.epoch)
	preload("res://scripts/save/travel_snapshot.gd").restore.call_deferred(player)
	var arrival_direction: Vector3 = preload("res://scripts/gameplay/arrival_area.gd").TARGET - player.global_position
	player.look_rotation = Vector2(0,atan2(-arrival_direction.x,-arrival_direction.z))
	if GameState.yard_level > 0:
		var index: int = GameState.yard_level - 1
		player._navigation_target = preload("res://scripts/gameplay/expansion_lots.gd").CENTERS[index] + Vector3(-34, 0, 25)
		player._navigation_label = "LOTTO EST" if index == 0 else "LOTTO DELLE DUNE"

	print('[SECTOR] Single player configured, is_local_player should be true')

	# Test verification for headless test mode - only runs when TestSP autoload is present
	var test_sp = get_node_or_null("/root/TestSP")
	if test_sp:
		_verify_single_player_test(player, test_sp)

func _verify_single_player_test(player: Node3D, test_sp: Node) -> void:
	print("[SECTOR] ENTERED _verify_single_player_test")
	print("[SECTOR] player = ", player)
	# In GDScript, the node IS the script instance when script is attached
	# Access properties directly (variables are accessible as properties)
	var is_local = player.is_local_player
	var cam = player.camera
	var cam_current = cam.current if cam else false
	print("[SECTOR] is_local_player = ", is_local)
	print("[SECTOR] camera = ", cam)
	print("[SECTOR] camera.current = ", cam_current)
	if is_local and cam and cam_current:
		print("[TEST] PASS: Single player spawned with camera.current=true")
		print("[SECTOR] TestSP available: true")
		if test_sp:
			print("[SECTOR] Emitting test_result signal")
			test_sp.test_result.emit(true, "Single player spawned with camera.current=true")
	else:
		print("[TEST] FAIL: Player not configured correctly")
		if test_sp:
			test_sp.test_result.emit(false, "Player not configured correctly: is_local=%s, cam=%s, cam.current=%s" % [is_local, cam, cam_current])

func _on_peer_connected(peer_id: int) -> void:
	# print('[SECTOR] peer_connected: ' + str(peer_id))
	if NetworkGateway.is_host() and SessionState.current_state == SessionState.ConnectionState.MISSION:
		# Host spawna il player per il nuovo peer
		_spawn_player_for_peer(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	# print('[SECTOR] peer_disconnected: ' + str(peer_id))
	if _spawned_players.has(peer_id):
		_spawned_players[peer_id].queue_free()
		_spawned_players.erase(peer_id)
	# Unregister from ReplicationService
	if NetworkGateway.is_host() and ReplicationService:
		var entity_id = "player_" + str(peer_id)
		ReplicationService.unregister_entity(entity_id)
		print('[SECTOR] Unregistered player ' + str(peer_id) + ' from ReplicationService')

func _on_entity_spawned(entity_id: String, def_id: String, transform: Transform3D, owner_peer: int) -> void:
	# Client: crea il player node locale quando l'host registra l'entità
	if NetworkGateway.is_host():
		return  # Host gestisce lo spawn direttamente

	if not def_id == "player":
		return  # Non è un player

	# Estrae peer_id dall'entity_id (formato: "player_<peer_id>")
	var peer_id_str = entity_id.replace("player_", "")
	var peer_id = peer_id_str.to_int()
	if peer_id == 0:
		print('[SECTOR] ERROR: Invalid peer_id in entity_id: ' + entity_id)
		return

	# print('[SECTOR] Client creating local player for peer ' + str(peer_id) + ' (entity: ' + entity_id + ')')

	# Istanzia il player localmente
	var player = _player_scene.instantiate()
	if not player:
		print('[SECTOR] ERROR: Failed to instantiate player for peer ' + str(peer_id))
		return

	# Il client non ha authority sul player (authority = 1 = host)
	# Ma il node deve esistere localmente per ricevere snapshot e renderizzare
	# Non impostiamo authority qui - il node è "locale" per il client

	# Aggiungi alla scena
	add_child(player)

	# Posiziona usando il transform dallo snapshot
	player.global_transform = transform
	# print('[SECTOR] Positioned local player ' + str(peer_id) + ' at ' + str(transform.origin))

	# Registra localmente
	_spawned_players[peer_id] = player

	# Aggiungi al gruppo per ricerca
	player.add_to_group("players")

	# Configura controller
	var local_peer_id = NetworkGateway.get_peer_id()
	if peer_id == local_peer_id:
		# Questo è il NOSTRO player
		player.set_as_local_player(local_peer_id)
		print('[SECTOR] Client assigned local player for peer ' + str(peer_id))
	else:
		# Player di un altro client - configura come remoto
		player.set_as_remote_player(peer_id)
		print('[SECTOR] Client created remote player for peer ' + str(peer_id))

func _on_entity_despawned(entity_id: String) -> void:
	# Client: rimuove il player node locale quando l'host deregistra l'entità
	if NetworkGateway.is_host():
		return  # Host gestisce la rimozione direttamente

	if not entity_id.begins_with("player_"):
		return  # Non è un player

	# Estrae peer_id dall'entity_id
	var peer_id_str = entity_id.replace("player_", "")
	var peer_id = peer_id_str.to_int()
	if peer_id == 0:
		return

	# print('[SECTOR] Client removing local player for peer ' + str(peer_id))

	if _spawned_players.has(peer_id):
		_spawned_players[peer_id].queue_free()
		_spawned_players.erase(peer_id)

func _get_spawn_point(peer_id: int) -> Node3D:
	var points = spawn_points.get_children()
	var idx = (peer_id - 1) % points.size()
	return points[idx]

func _spawn_player_for_peer(peer_id: int) -> void:
	if not _player_scene:
		print('[SECTOR] ERROR: Player scene not loaded')
		return

	# print('[SECTOR] Spawning player for peer ' + str(peer_id))

	# Istanzia il player
	var player = _player_scene.instantiate()
	if not player:
		print('[SECTOR] ERROR: Failed to instantiate player for peer ' + str(peer_id))
		return

	# IMPOSTANTE: Imposta authority PRIMA di aggiungere all'albero
	# Host è peer 1 - l'host ha authority su TUTTI i player
	player.set_multiplayer_authority(1)

	# Aggiungi alla scena
	add_child(player)

	# Posiziona
	var spawn_point = _get_spawn_point(peer_id)
	player.global_position = spawn_point.global_position
	# print('[SECTOR] Positioned player ' + str(peer_id) + ' at ' + str(spawn_point.global_position))

	# Registra con ReplicationService per replica posizione
	if NetworkGateway.is_host() and ReplicationService:
		var entity_id = "player_" + str(peer_id)
		ReplicationService.register_entity(entity_id, "player", player.global_transform)
		# print('[SECTOR] Registered player ' + str(peer_id) + ' with ReplicationService as ' + entity_id)

	# Registra localmente
	_spawned_players[peer_id] = player

	# Aggiungi al gruppo per ricerca
	player.add_to_group("players")

	# Configura controller
	if NetworkGateway.is_host():
		if peer_id == 1:
			# Host's own player
			player.set_as_local_player(1)
		# Per gli altri client: NON inviamo più RPC.
		# Il client creerà il proprio player locale via entity_spawned signal
		# quando l'host registra l'entità in ReplicationService
	else:
		# Client non fa nulla qui - attende entity_spawned signal
		pass

	# print('[SECTOR] Player ' + str(peer_id) + ' spawnato con authority 1 (host)')

func _spawn_scrap_items() -> void:
	if SessionState.is_host and not NetworkGateway.is_network_connected():
		_spawn_single_player_scrap()
		return
	# Genera scrap items da balance.json (9 tipi, totale ~120)
	# Area settore: -50 a 50 in X e Z (evitando mura e zona deposito)
	# Crea cluster/pile invece di distribuzione uniforme per feel discarica
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Carica sector_counts da balance.json
	var file = FileAccess.open("res://data/balance.json", FileAccess.READ)
	if not file:
		push_error("Impossibile caricare balance.json per spawn scrap")
		return
	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance or not balance.has("sector_counts"):
		push_error("sector_counts non trovato in balance.json")
		return

	var sector_counts = balance.sector_counts
	var total_spawned = 0

	# Mapping materiale -> tipo enum (0-8)
	var material_to_type = {
		"metal": 0,
		"plastic": 1,
		"electronics": 2,
		"copper": 3,
		"aluminum": 4,
		"glass": 5,
		"rubber": 6,
		"textile": 7,
		"hazardous": 8
	}

	# Definisci cluster centers per creare pile di rottami
	# Ogni cluster ha un centro, raggio, e bias per certi materiali
	var clusters = [
		# Cluster principali - grandi pile centrali
		{"center": Vector2(-35, -20), "radius": 12.0, "density": 1.8, "material_bias": ["metal", "copper", "aluminum"]},
		{"center": Vector2(30, -15), "radius": 10.0, "density": 1.5, "material_bias": ["plastic", "rubber", "textile"]},
		{"center": Vector2(-25, 30), "radius": 14.0, "density": 2.0, "material_bias": ["metal", "electronics", "hazardous"]},
		{"center": Vector2(20, 40), "radius": 8.0, "density": 1.3, "material_bias": ["glass", "plastic"]},
		{"center": Vector2(-40, 10), "radius": 9.0, "density": 1.6, "material_bias": ["copper", "metal"]},
		{"center": Vector2(40, 5), "radius": 7.0, "density": 1.2, "material_bias": ["rubber", "textile"]},
		# Cluster secondari - cumuli minori sparsi
		{"center": Vector2(-10, -30), "radius": 5.0, "density": 0.8, "material_bias": ["metal", "plastic"]},
		{"center": Vector2(15, -25), "radius": 6.0, "density": 0.9, "material_bias": ["electronics", "copper"]},
		{"center": Vector2(-15, 15), "radius": 4.0, "density": 0.7, "material_bias": ["glass", "aluminum"]},
		{"center": Vector2(5, 25), "radius": 5.0, "density": 0.8, "material_bias": ["hazardous", "metal"]},
		{"center": Vector2(-30, 50), "radius": 6.0, "density": 0.9, "material_bias": ["textile", "rubber"]},
		{"center": Vector2(35, -35), "radius": 5.0, "density": 0.7, "material_bias": ["plastic", "glass"]},
		{"center": Vector2(0, 50), "radius": 8.0, "density": 1.0, "material_bias": ["metal", "copper", "aluminum"]},
		{"center": Vector2(-50, -10), "radius": 7.0, "density": 0.9, "material_bias": ["electronics", "hazardous"]},
		{"center": Vector2(50, 20), "radius": 6.0, "density": 0.8, "material_bias": ["rubber", "glass"]},
	]

	# Crea lista materiali con i loro count
	var materials_list = []
	for material_name in sector_counts:
		var count = sector_counts[material_name]
		var scrap_type = material_to_type.get(material_name, 0)
		for i in range(count):
			materials_list.append({"name": material_name, "type": scrap_type})

	# Shuffle materiali
	for i in materials_list.size():
		var j = rng.randi_range(i, materials_list.size() - 1)
		var temp = materials_list[i]
		materials_list[i] = materials_list[j]
		materials_list[j] = temp

	# Distribuisci materiali nei cluster basandosi su bias e density
	var cluster_materials: Array = []
	for c in clusters:
		cluster_materials.append([])

	# Prima passata: assegna materiali ai cluster preferiti
	for mat in materials_list:
		var assigned = false
		# Prova cluster con bias per questo materiale
		for ci in range(clusters.size()):
			if mat["name"] in clusters[ci]["material_bias"]:
				cluster_materials[ci].append(mat)
				assigned = true
				break
		# Fallback: cluster casuale
		if not assigned:
			var ci = rng.randi_range(0, clusters.size() - 1)
			cluster_materials[ci].append(mat)

	# Spawna items in ogni cluster
	for ci in range(clusters.size()):
		var cluster = clusters[ci]
		var mats = cluster_materials[ci]
		var center = cluster["center"]
		var radius = cluster["radius"]
		var density = cluster["density"]

		for mat in mats:
			# Posizione nel cluster con distribuzione gaussiana-ish (più denso al centro)
			var angle = rng.randf_range(0.0, TAU)
			# Bias verso il centro per densità
			var r = radius * sqrt(rng.randf_range(0.0, 1.0)) * density
			# Clamp al raggio
			r = min(r, radius)

			var x = center.x + cos(angle) * r
			var z = center.y + sin(angle) * r

			# Evita zona deposito (0, -40 raggio 8)
			var dist_from_deposit = Vector2(x, z - (-40)).length()
			if dist_from_deposit < 8.0:
				# Sposta lontano dal deposito
				var away_dir = Vector2(x, z - (-40)).normalized()
				x += away_dir.x * (8.0 - dist_from_deposit)
				z += away_dir.y * (8.0 - dist_from_deposit)

			# Clamp ai bordi settore
			x = clamp(x, -48.0, 48.0)
			z = clamp(z, -48.0, 48.0)

			# Altezza variabile - cumuli più alti al centro
			var dist_from_center = Vector2(x - center.x, z - center.y).length()
			var height_factor = 1.0 - (dist_from_center / radius) * 0.6
			var base_y = 0.8 + rng.randf_range(0.0, 0.4) * height_factor

			var spawn_pos = Vector3(x, base_y, z)

			# Istanzia scrap item
			var scrap = _scrap_scene.instantiate()
			if not scrap:
				continue

			# Imposta tipo
			scrap.scrap_type = mat["type"]

			# Aggiungi alla scena
			add_child(scrap)
			scrap.global_position = spawn_pos

			# Rotazione casuale per variety
			scrap.rotation.y = rng.randf_range(0.0, TAU)

			total_spawned += 1

	# Aggiungi alcuni items "sparsi" tra i cluster per riempire
	var scattered_count = 15
	for i in range(scattered_count):
		var x = rng.randf_range(-45.0, 45.0)
		var z = rng.randf_range(-35.0, 35.0)

		# Evita zona deposito
		var dist_from_deposit = Vector2(x, z - (-40)).length()
		if dist_from_deposit < 8.0:
			continue

		# Evita troppo vicino a cluster esistenti
		var too_close = false
		for cluster in clusters:
			if Vector2(x, z).distance_to(cluster["center"]) < cluster["radius"] + 3.0:
				too_close = true
				break
		if too_close:
			continue

		# Materiale casuale dai rimanenti (o pick random)
		if materials_list.size() == 0:
			break
		var mat = materials_list[rng.randi_range(0, materials_list.size() - 1)]

		var spawn_pos = Vector3(x, 0.8 + rng.randf_range(0.0, 0.3), z)

		var scrap = _scrap_scene.instantiate()
		if not scrap:
			continue
		scrap.scrap_type = mat["type"]
		add_child(scrap)
		scrap.global_position = spawn_pos
		scrap.rotation.y = rng.randf_range(0.0, TAU)
		total_spawned += 1

	print('[SECTOR] Spawned %d scrap items in %d clusters (9 types)' % [total_spawned, clusters.size()])
func _on_land_unlocked(_level: int) -> void:
	apply_land_expansions()

func apply_land_expansions() -> void:
	preload("res://scripts/gameplay/expansion_lots.gd").refresh(self)

func spawn_lot_scrap(material_id: String, id: String, location: Vector3, level: int) -> void:
	if id in GameState.sector_consumed_ids:
		return
	for item in get_tree().get_nodes_in_group("scrap"):
		if item.entity_id == id:
			return
	var scrap = _scrap_scene.instantiate()
	scrap.entity_id = id
	scrap.scrap_type = {"metal":0, "plastic":1, "electronics":2, "copper":3, "aluminum":4, "glass":5, "rubber":6}[material_id]
	scrap.mass = GameState.material_defs[material_id].mass_kg
	scrap.value = GameState.material_defs[material_id].credits
	scrap.position = location + Vector3.UP * 0.3
	scrap.set_meta("lot", level)
	scrap.add_to_group("lot_scrap")
	add_child(scrap)

