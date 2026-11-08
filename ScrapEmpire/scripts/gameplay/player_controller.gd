## PlayerController.gd
## Controllo movimento prima persona, host-authoritative.
## Il client invia input, l'host simula e replica.

class_name PlayerController
extends CharacterBody3D

# Componenti (initialized in _ready)
var camera: Camera3D
var collision: CollisionShape3D
var local_expedition_epoch: int = -1
var _career_current_page: String = "story"
var mesh_local: MeshInstance3D
var mesh_remote: MeshInstance3D
var name_label: Label3D

# Configurazione movimento
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var mouse_sensitivity: float = 0.002
@export var max_pitch: float = 1.5

# Screen shake
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO

# Recupero fuori mappa
@export var fall_threshold_y: float = -20.0
@export var respawn_height: float = 5.0

# Stato input
var input_vec: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var jump_requested: bool = false
var look_rotation: Vector2 = Vector2.ZERO  # x=pitch, y=yaw

# Rete
var input_sequence: int = 0
var last_input_time: float = 0.0
var is_local_player: bool = false
var owner_peer_id: int = 0
var _single_player_mode: bool = false

# Input timeout - se non arrivano input per X secondi, neutralizza movimento
const INPUT_TIMEOUT_MS: int = 500

# Interpolazione per client remoti
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: float = 0.0
var _interpolation_buffer: Array[Dictionary] = []
const INTERPOLATION_MS: int = 100

# Pause menu
var _is_paused: bool = false
var _invert_y: bool = false
var _hint: Label
var _feedback: Label
var _feedback_lifetime: float = 0.0
var _panel_box: VBoxContainer
var _component_selection: String=""
var _material_selection: String = "metal"
var _station_status: Label
var _station_buy: Button
var _station_deposit: Button
var _station_surplus: Button
var _station_all_sale: Button
var _press_start_button: Button
var _extra_inventory: Label
var _bag_meter: ProgressBar
var _mounted_vehicle: Node3D
var _vehicle_heading: float = 0.0
var _vehicle_speed: float = 0.0
var _vehicle_motion = preload("res://scripts/gameplay/vehicle_motion.gd").new()
var _vehicle_entry_time: float=0.0
var _vehicle_entry_side: float=1.0
var _vehicle_exit_time: float=0.0
var _vehicle_exit_from: Transform3D
var _local_avatar: Node3D
var _walking_shape: Shape3D
var _walking_shape_position: Vector3
var _walking_snap: float = 0.1
var _walking_camera_mask: int = 0
var _vehicle_third_person: bool = false
var _career_map_wide: bool = false
var _career_tracking: bool = false
var _career_route_key: String = ""
var _career_hud_step: Dictionary = {}
var _career_hud_frame: int = -100
var _panel_wallet: Label
var _hotbar: Label
var _hotbar_slots: Array[Label] = []
var _field_ui: Control
var auto_workshop_zones: bool = false
var _equipped_tool: int = -1
var _held_tool: Node3D
var _tool_visual_level: int = -2
var _action_clock: float = 0.0
var _interact_prompt: Label3D
var _prompt_backing: MeshInstance3D
var _upgrade_monitor: Node3D
var _target_hit_world: Vector3
var _vehicle_selection: int = -1
var _recover_intact: bool = false
var _carried_visual: Node3D
var _carried_visual_id: String = ""
var _navigation_target: Vector3
var _navigation_label: String = ""
var _world_hint: String = ""
var _pause_menu: PopupPanel = null

# Debug frame counter
var _debug_frame_counter: int = 0

# Raccolta
var _target_scrap = null
var _collecting: bool = false
var _collect_progress: float = 0.0
const COLLECT_RANGE: float = 3.0
const COLLECT_TIME: float = 1.5  # secondi per raccogliere

# Test auto-movement (press T to toggle)
var _test_moving: bool = false
var _test_move_timer: float = 0.0

# Deposito
var _in_deposit_zone: bool = false
var _deposit_prompt_visible: bool = false

# Riferimenti servizi
var _session: SessionState
var _game_state: GameState
var _network: NetworkGateway

# HUD references (initialized in _ready)
var _reticle: Label
var _collect_progress_bar: ProgressBar
var _credits_label: Label
var _weight_label: Label
var _metal_label: Label
var _plastic_label: Label
var _electronics_label: Label
var _copper_label: Label
var _aluminum_label: Label
var _glass_label: Label
var _rubber_label: Label
var _textile_label: Label
var _hazardous_label: Label
var _debug_label: Label

# Deposit detector reference
var _deposit_detector: Area3D = null

# Audio
@onready var _deposit_sound: AudioStreamPlayer3D = get_node_or_null("DepositSound")

func _ready() -> void:
	_session = SessionState
	_game_state = GameState
	if not InputMap.has_action("recovery_mode"):
		InputMap.add_action("recovery_mode")
		var mode_key = InputEventKey.new()
		mode_key.keycode = KEY_R
		InputMap.action_add_event("recovery_mode",mode_key)
	_network = NetworkGateway

	# Initialize component references
	camera = get_node_or_null("Camera3D")
	collision = get_node_or_null("PlayerCollisionShape3D")
	mesh_local = get_node_or_null("MeshInstance3D")
	mesh_remote = get_node_or_null("RemoteMesh")
	name_label = get_node_or_null("NameLabel")

	# Setup camera iniziale
	if camera:
		camera.current = false
	print("[PLAYER] _ready called")
	print("  camera: ", camera, " current: ", camera.current if camera else "null")
	print("  collision: ", collision)
	print("  mesh_local: ", mesh_local)
	print("  mesh_remote: ", mesh_remote)
	print("  name_label: ", name_label)
	print("  is_local_player: ", is_local_player)
	print("  _single_player_mode: ", _single_player_mode)

	# Initialize HUD node references
	_reticle = get_node_or_null("HUD/Reticle")
	_collect_progress_bar = get_node_or_null("HUD/CollectProgress")
	_credits_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/CreditsLabel")
	_weight_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/WeightLabel")
	_metal_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/MetalLabel")
	_plastic_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/PlasticLabel")
	_electronics_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/ElectronicsLabel")
	_copper_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/CopperLabel")
	_aluminum_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/AluminumLabel")
	_glass_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/GlassLabel")
	_rubber_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/RubberLabel")
	_textile_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/TextileLabel")
	_hazardous_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/HazardousLabel")
	_debug_label = get_node_or_null("HUD/InventoryHUD/VBoxContainer/DebugLabel")
	_deposit_detector = get_node_or_null("DepositDetector")

	print("  _reticle: ", _reticle)
	print("  _debug_label: ", _debug_label)
	print("  collision_layer: ", get_collision_layer())
	print("  collision_mask: ", get_collision_mask())

	# Debug: print what we found
	if not _reticle:
		# print("[PLAYER] WARNING: Reticle not found at HUD/Reticle")
		pass
	if not _credits_label:
		# print("[PLAYER] WARNING: CreditsLabel not found at HUD/InventoryHUD/VBoxContainer/CreditsLabel")
		pass

	# Workaround for headless mode bug: DepositDetector Area3D not instantiated from scene
	# Create it programmatically if missing
	if not _deposit_detector:
		_deposit_detector = Area3D.new()
		_deposit_detector.name = "DepositDetector"
		_deposit_detector.position = Vector3(0, 1, 0)
		_deposit_detector.collision_layer = 2
		_deposit_detector.collision_mask = 1
		_deposit_detector.monitorable = false
		_deposit_detector.monitoring = true
		add_child(_deposit_detector)
		# print("[PLAYER] Created DepositDetector programmatically")

	# Add CollisionShape3D to DepositDetector if missing
	var deposit_collision = _deposit_detector.get_node_or_null("DepositDetectorCollisionShape3D")
	if not deposit_collision:
		deposit_collision = CollisionShape3D.new()
		deposit_collision.name = "DepositDetectorCollisionShape3D"
		# Reuse the capsule shape from player collision
		if collision and collision.shape:
			deposit_collision.shape = collision.shape
		deposit_collision.position = Vector3(0, 1.0, 0)
		_deposit_detector.add_child(deposit_collision)
		# print("[PLAYER] Created DepositDetectorCollisionShape3D programmatically")

	# Connect signals
	_deposit_detector.area_entered.connect(_on_area_entered)
	_deposit_detector.area_exited.connect(_on_area_exited)

	# Input sequence per validazione host
	input_sequence = 0

	# Connetti segnali sessione per pause/resume
	_session.state_changed.connect(_on_state_changed)

	# Connetti segnale inventario per aggiornare HUD
	_game_state.inventory_changed.connect(_on_inventory_changed)
	_game_state.machine_message.connect(_notify)

	_hint = Label.new()
	_hint.position = Vector2(20, 20)
	_hotbar = Label.new()
	_hotbar.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_hotbar.text = "[1–4] EQUIPAGGIA    [I] ATTREZZATURA    [E] INTERAGISCI"
	_hotbar.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hotbar.add_theme_constant_override("shadow_offset_x", 2)
	_hotbar.add_theme_constant_override("shadow_offset_y", 2)
	get_node("HUD").add_child(_hotbar)
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal=Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical=Control.GROW_DIRECTION_BEGIN
	_hotbar.offset_left=-350
	_hotbar.offset_right=350
	_hotbar.offset_top=-30
	_hotbar.offset_bottom=-8
	var slots = HBoxContainer.new()
	slots.name="EquipmentSlots"
	slots.add_theme_constant_override("separation", 7)
	get_node("HUD").add_child(slots)
	slots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	slots.grow_horizontal=Control.GROW_DIRECTION_BOTH
	slots.grow_vertical=Control.GROW_DIRECTION_BEGIN
	slots.offset_left=-323.5
	slots.offset_right=323.5
	slots.offset_top=-90
	slots.offset_bottom=-40
	for name_text in ["1 · MANI", "2 · CACCIAVITE", "3 · MARTELLO", "4 · MONO", "5 · LEVA", "6 · CESOIE"]:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(102, 50)
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#14252de8")
		style.border_color = Color("#e9b44f")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", style)
		slots.add_child(panel)
		var item = Label.new()
		item.text = name_text + "\n0"
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(item)
		_hotbar_slots.append(item)
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	get_node("HUD").add_child(_hint)
	_interact_prompt = Label3D.new()
	_interact_prompt.name = "WorldInteractionPrompt"
	_interact_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_prompt.font_size = 36
	_interact_prompt.pixel_size = 0.0027
	_interact_prompt.width = 700
	_interact_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_interact_prompt.modulate = Color("#ffe4aa")
	_interact_prompt.outline_modulate = Color("#10191fee")
	_interact_prompt.outline_size = 5
	_interact_prompt.no_depth_test = false
	_interact_prompt.add_to_group("world_interaction_prompt")
	get_tree().current_scene.add_child(_interact_prompt)
	if DisplayServer.get_name() != "headless":
		_prompt_backing = MeshInstance3D.new()
		_prompt_backing.mesh = QuadMesh.new()
		_prompt_backing.mesh.size = Vector2(2.0, 0.46)
		var prompt_material = StandardMaterial3D.new()
		prompt_material.albedo_color = Color("#101c24ee")
		prompt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		prompt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		prompt_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		prompt_material.render_priority = -2
		_prompt_backing.material_override = prompt_material
		_interact_prompt.add_child(_prompt_backing)
	_interact_prompt.hide()
	_feedback = Label.new()
	_feedback.position = Vector2(20, 150)
	var inventory_panel = get_node("HUD/InventoryHUD")
	inventory_panel.offset_top = -215
	inventory_panel.offset_right = 300
	var inventory_box = get_node("HUD/InventoryHUD/VBoxContainer")
	_bag_meter = ProgressBar.new()
	_bag_meter.show_percentage = false
	_bag_meter.custom_minimum_size = Vector2(280, 8)
	inventory_box.add_child(_bag_meter)
	inventory_box.move_child(_bag_meter, 3)
	_extra_inventory = Label.new()
	_extra_inventory.add_theme_font_size_override("font_size", 14)
	inventory_box.add_child(_extra_inventory)
	_feedback.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	get_node("HUD").add_child(_feedback)
	if _debug_label:
		_debug_label.hide()
	if not SessionState.progression_notice.is_empty():
		_notify(SessionState.progression_notice)
	_field_ui=Control.new()
	_field_ui.set_script(preload("res://scripts/ui/field_hud.gd"))
	_field_ui.player=self
	get_node("HUD").add_child(_field_ui)
	_update_inventory_hud()

func _on_inventory_changed(peer_id: int, _inventory: Dictionary) -> void:
	if peer_id == owner_peer_id:
		_update_inventory_hud()

func _update_inventory_hud() -> void:
	if not _game_state.player_inventories.has(owner_peer_id):
		return

	if is_instance_valid(_panel_wallet):
		_panel_wallet.text = "%d Bulloni" % _game_state.team_credits
	var inv = _game_state.player_inventories[owner_peer_id]
	var mass = _game_state.get_inventory_mass(owner_peer_id)
	var capacity = _game_state.get_inventory_capacity(owner_peer_id)
	var driving_buggy: bool = is_instance_valid(_mounted_vehicle) and _mounted_vehicle.level==2
	_hotbar.visible = not driving_buggy
	var interaction_key: String = InputMap.action_get_events("interact")[0].as_text()
	_hotbar.text = "%s    [%s] INTERAGISCI" % ["[I] ATTREZZATURA" if _shortcut_free(KEY_I) else "PAUSA → ATTREZZATURA",interaction_key]
	_reticle.visible = not driving_buggy
	for slot in _hotbar_slots:
		slot.get_parent().visible = not driving_buggy
	var tool_names = ["MANI", "CACCIAVITE", "MARTELLO", "MONO", "LEVA", "CESOIE"]
	var equipped: int = 3 if is_instance_valid(_mounted_vehicle) and _mounted_vehicle.level == 1 else (_active_tool()+1 if _active_tool()>=3 else _active_tool())
	for index in _hotbar_slots.size():
		var owned: bool = index == 0 or (index < 3 and _game_state.team_upgrade_levels.tool >= index) or (index == 3 and _game_state.vehicle_level >= 1) or (index>=4 and _game_state.owns_tool(index-1))
		_hotbar_slots[index].text = "%s · %s\n%s" % [str(index+1) if _shortcut_free(KEY_1+index) else "—", tool_names[index], "IN USO" if index == equipped else ("PRONTO" if owned else "BLOCCATO")]
		_hotbar_slots[index].modulate = Color("#ffda7d") if index == equipped else (Color.WHITE if owned else Color("#74838a"))
	if _bag_meter:
		_bag_meter.value = mass * 100.0 / capacity
	if _extra_inventory:
		var summary: PackedStringArray = []
		var names = {"copper": "Rame", "aluminum": "Alluminio", "glass": "Vetro", "rubber": "Pneumatici"}
		for material_id in names:
			if inv.get(material_id, 0) > 0:
				summary.append("%s: %d" % [names[material_id], inv[material_id]])
		_extra_inventory.text = "\n".join(summary)
		get_node("HUD/InventoryHUD").offset_top = -165 if summary.is_empty() else -275

	if _credits_label:
		_credits_label.text = "Bulloni: %d" % [_game_state.team_credits]
	if _weight_label:
		_weight_label.text = "Peso: %.1f / %.1f kg" % [mass, capacity]
	if _metal_label:
		_metal_label.text = "Metallo: %d" % [inv.get("metal", 0)]
	if _plastic_label:
		_plastic_label.text = "Plastica: %d" % [inv.get("plastic", 0)]
	if _electronics_label:
		_electronics_label.text = "Elettronica: %d" % [inv.get("electronics", 0)]
	if _copper_label:
		_copper_label.text = "Rame: %d" % [inv.get("copper", 0)]
	if _aluminum_label:
		_aluminum_label.text = "Alluminio: %d" % [inv.get("aluminum", 0)]
	if _glass_label:
		_glass_label.text = "Vetro: %d" % [inv.get("glass", 0)]
	if _rubber_label:
		_rubber_label.text = "Gomma: %d" % [inv.get("rubber", 0)]
	if _textile_label:
		_textile_label.text = "Tessile: %d" % [inv.get("textile", 0)]
	if _hazardous_label:
		_hazardous_label.text = "Pericoloso: %d" % [inv.get("hazardous", 0)]
	if is_instance_valid(_field_ui): _field_ui.refresh()

func _on_state_changed(state_name: String) -> void:
	# Quando si esce dalla missione, rilascia mouse
	if state_name != "MISSION" and _is_paused:
		_close_pause_menu()

func _on_area_entered(area: Area3D) -> void:
	if not is_local_player:
		return
	# Controlla se è la zona deposito
	if area.is_in_group("deposit_zone"):
		_in_deposit_zone = true
		_show_deposit_prompt()

func _on_area_exited(area: Area3D) -> void:
	if not is_local_player:
		return
	if area.is_in_group("deposit_zone"):
		_in_deposit_zone = false
		_hide_deposit_prompt()

func _show_deposit_prompt() -> void:
	if _deposit_prompt_visible:
		return
	_deposit_prompt_visible = true
	# Cambia reticolo per indicare deposito possibile
	if _reticle:
		_reticle.text = "+  [E] Deposita"
		_reticle.add_theme_color_override("font_color", Color(0.2, 1, 0.8, 1))

func _hide_deposit_prompt() -> void:
	if not _deposit_prompt_visible:
		return
	_deposit_prompt_visible = false
	# Ripristina reticolo normale
	if _reticle:
		_reticle.text = "+"
		_reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

func _try_deposit() -> void:
	if not _near_depot():
		return
	var value: int = InventoryService.deposit_all(owner_peer_id)
	_notify("Sacca trasferita: scorte conservate nel deposito." if value>0 else ("Deposito non confermato: materiali ancora nella sacca." if get_inventory_mass()>0 else "Sacca vuota."))
	if value>0:
		_play_feedback("deposit")
	_refresh_station()

func _show_deposit_summary(credits_earned: int) -> void:
	# Crea un popup stilizzato con il riepilogo del deposito
	var popup = PopupPanel.new()
	popup.title = "Deposito Completato"

	# Stile popup
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.5, 0.4, 1)
	popup.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	# Title label
	var title_label = Label.new()
	title_label.text = "DEPOSITO EFFETTUATO"
	title_label.horizontal_alignment = 1
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.3, 1, 0.5, 1))
	title_label.add_theme_color_override("outline_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title_label)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.3, 0.5, 0.4, 0.5))
	vbox.add_child(sep)

	var credits_label = Label.new()
	credits_label.text = "+ %d Bulloni" % [credits_earned]
	credits_label.horizontal_alignment = 1
	credits_label.add_theme_font_size_override("font_size", 28)
	credits_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	credits_label.add_theme_color_override("outline_color", Color(0, 0, 0, 0.8))
	credits_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(credits_label)

	var total_label = Label.new()
	total_label.text = "Totale squadra: %d Bulloni" % [_game_state.team_credits]
	total_label.horizontal_alignment = 1
	total_label.add_theme_font_size_override("font_size", 16)
	total_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 1))
	vbox.add_child(total_label)

	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("separator_color", Color(0.3, 0.5, 0.4, 0.5))
	vbox.add_child(sep2)

	var close_btn = Button.new()
	close_btn.text = "Continua"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.35, 0.3, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_color = Color(0.4, 0.6, 0.5, 0.8)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.45, 0.38, 1)
	close_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.3, 0.25, 1)
	close_btn.add_theme_stylebox_override("pressed", btn_pressed)
	close_btn.pressed.connect(popup.close)
	vbox.add_child(close_btn)

	popup.popup_centered()
	# Auto-chiudi dopo 5 secondi
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(popup.close)
	popup.add_child(timer)
	timer.start()

func _spawn_deposit_particles() -> void:
	# Crea particelle di deposito nella zona deposito
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 1.5
	particles.explosiveness = 0.8
	particles.spread = 90.0
	particles.initial_velocity = 4.0
	particles.gravity = Vector3(0, -3.0, 0)
	particles.scale = 0.4
	particles.scale_curve = PackedFloat32Array([1.0, 0.0])
	# Colore oro/arancio per il deposito
	var gradient = Gradient.new()
	var color1 = Color(1.0, 0.85, 0.2, 1.0)
	var color2 = Color(1.0, 0.6, 0.1, 0.6)
	var color3 = Color(1.0, 0.4, 0.0, 0.0)
	gradient.set_color_at_offset(0.0, color1)
	gradient.set_color_at_offset(0.5, color2)
	gradient.set_color_at_offset(1.0, color3)
	particles.color_ramp = gradient
	particles.local_coords = false
	# Posiziona sopra la zona deposito (approssimativamente a 0, 0.5, -80)
	particles.global_position = Vector3(0, 2, -80) + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	get_tree().root.add_child(particles)
	# Auto-remove after lifetime
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(particles.queue_free.bind())
	particles.add_child(timer)
	timer.start()

func _try_complete_mission() -> void:
	if not is_local_player or not _in_deposit_zone:
		# print("[PLAYER] Devi essere nella zona deposito per completare la missione")
		return
	if _is_paused:
		return
	if _game_state.mission_phase != "MISSIONE":
		# print("[PLAYER] Missione non in corso")
		return

	# Verifica se c'è qualcosa da vendere
	if _game_state.team_deposit_counts["metal"] == 0 and _game_state.team_deposit_counts["plastic"] == 0 and _game_state.team_deposit_counts["electronics"] == 0:
		# print("[PLAYER] Niente da vendere")
		return

	var result = _game_state.settle_mission()
	if result.success:
		# print("[PLAYER] Missione completata! Incasso totale: %d Bulloni" % [result.total_revenue])
		_show_mission_summary(result)
	else:
		# print("[PLAYER] Errore completamento missione: %s" % [result.reason])
		pass

func _show_mission_summary(result: Dictionary) -> void:
	var popup = PopupPanel.new()
	popup.title = "Missione Completata"

	# Stile popup
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.5, 0.4, 0.2, 1)
	popup.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	# Title label
	var title_label = Label.new()
	title_label.text = "MISSIONE COMPLETATA"
	title_label.horizontal_alignment = 1
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	title_label.add_theme_color_override("outline_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title_label)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.5, 0.4, 0.2, 0.5))
	vbox.add_child(sep)

	var labels = [
		["Valore vendita:", "%d Bulloni" % [result.sale_value], Color(0.7, 0.9, 0.7, 1)],
		["Oggetti raccolti:", "%d / %d" % [result.clean_count, result.total_count], Color(0.7, 0.8, 1, 1)],
		["Bonus contratto:", "%d Bulloni" % [result.bonus], Color(1, 0.85, 0.3, 1)],
		["Contratto raggiunto:", "%s" % ["SÌ" if result.contract_met else "NO"], Color(0.3, 1, 0.5, 1) if result.contract_met else Color(1, 0.4, 0.4, 1)],
	]

	for label_data in labels:
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var label_left = Label.new()
		label_left.text = label_data[0]
		label_left.add_theme_font_size_override("font_size", 16)
		label_left.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 1))
		label_left.size_flags_horizontal = 2  # EXPAND
		hbox.add_child(label_left)

		var label_right = Label.new()
		label_right.text = label_data[1]
		label_right.add_theme_font_size_override("font_size", 16)
		label_right.add_theme_color_override("font_color", label_data[2])
		label_right.horizontal_alignment = 2  # RIGHT
		hbox.add_child(label_right)

	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("separator_color", Color(0.5, 0.4, 0.2, 0.5))
	vbox.add_child(sep2)

	var total_label = Label.new()
	total_label.text = "INCASSO TOTALE: %d Bulloni" % [result.total_revenue]
	total_label.horizontal_alignment = 1
	total_label.add_theme_font_size_override("font_size", 22)
	total_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	total_label.add_theme_color_override("outline_color", Color(0, 0, 0, 0.8))
	total_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(total_label)

	var balance_label = Label.new()
	balance_label.text = "Nuovo saldo: %d Bulloni" % [result.new_balance]
	balance_label.horizontal_alignment = 1
	balance_label.add_theme_font_size_override("font_size", 16)
	balance_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 1))
	vbox.add_child(balance_label)

	var sep3 = HSeparator.new()
	sep3.add_theme_color_override("separator_color", Color(0.5, 0.4, 0.2, 0.5))
	vbox.add_child(sep3)

	var close_btn = Button.new()
	close_btn.text = "Continua"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.25, 0.15, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.4, 0.35, 0.2, 1)
	close_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.25, 0.2, 0.1, 1)
	close_btn.add_theme_stylebox_override("pressed", btn_pressed)
	close_btn.pressed.connect(popup.close)
	vbox.add_child(close_btn)

	popup.popup_centered()

func _toggle_upgrade_panel() -> void:
	if _upgrade_panel and _upgrade_panel.visible:
		_upgrade_panel.close()
		_upgrade_panel = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Crea pannello upgrade
	_upgrade_panel = PopupPanel.new()
	_upgrade_panel.title = "Officina - Upgrade"
	_upgrade_panel.popup_centered()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var vbox = VBoxContainer.new()
	_upgrade_panel.add_child(vbox)

	# Mostra Bulloni attuali
	var credits_label = Label.new()
	credits_label.text = "Bulloni squadra: %d" % [_game_state.team_credits]
	credits_label.horizontal_alignment = 1
	vbox.add_child(credits_label)

	# Separatore
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Upgrade bag
	var bag_level = _game_state.team_upgrade_levels["bag"]
	var bag_upgrades = _game_state._get_upgrade_defs("bag")
	var next_bag_level = bag_level + 1
	var next_bag = _game_state._find_upgrade(bag_upgrades, next_bag_level)

	var bag_container = HBoxContainer.new()
	vbox.add_child(bag_container)

	var bag_label = Label.new()
	bag_label.text = "Zaino: Livello %d -> %d kg" % [bag_level, _game_state.get_inventory_capacity(owner_peer_id)]
	bag_label.size_flags_horizontal = 2  # EXPAND
	bag_container.add_child(bag_label)

	if next_bag:
		var bag_cost = next_bag.cost
		var bag_btn = Button.new()
		bag_btn.text = "Upgrade (%d Bulloni) -> %d kg" % [bag_cost, next_bag.capacity_kg]
		bag_btn.disabled = _game_state.team_credits < bag_cost
		bag_btn.pressed.connect(_purchase_upgrade.bind("bag", next_bag_level))
		bag_container.add_child(bag_btn)
	else:
		var bag_max = Label.new()
		bag_max.text = "MAX"
		bag_container.add_child(bag_max)

	# Upgrade tool
	var tool_level = _game_state.team_upgrade_levels["tool"]
	var tool_upgrades = _game_state._get_upgrade_defs("tool")
	var next_tool_level = tool_level + 1
	var next_tool = _game_state._find_upgrade(tool_upgrades, next_tool_level)

	var tool_container = HBoxContainer.new()
	vbox.add_child(tool_container)

	var tool_label = Label.new()
	tool_label.text = "Strumento: Livello %d (velocità raccolta x%.2f)" % [tool_level, _game_state.get_upgrade_effect("tool")]
	tool_label.size_flags_horizontal = 2
	tool_container.add_child(tool_label)

	if next_tool:
		var tool_cost = next_tool.cost
		var tool_btn = Button.new()
		tool_btn.text = "Upgrade (%d Bulloni) -> x%.2f" % [tool_cost, next_tool.time_multiplier]
		tool_btn.disabled = _game_state.team_credits < tool_cost
		tool_btn.pressed.connect(_purchase_upgrade.bind("tool", next_tool_level))
		tool_container.add_child(tool_btn)
	else:
		var tool_max = Label.new()
		tool_max.text = "MAX"
		tool_container.add_child(tool_max)

	# Upgrade movement
	var move_level = _game_state.team_upgrade_levels["movement"]
	var move_upgrades = _game_state._get_upgrade_defs("movement")
	var next_move_level = move_level + 1
	var next_move = _game_state._find_upgrade(move_upgrades, next_move_level)

	var move_container = HBoxContainer.new()
	vbox.add_child(move_container)

	var move_label = Label.new()
	move_label.text = "Movimento: Livello %d (velocità x%.2f)" % [move_level, _game_state.get_upgrade_effect("movement")]
	move_label.size_flags_horizontal = 2
	move_container.add_child(move_label)

	if next_move:
		var move_cost = next_move.cost
		var move_btn = Button.new()
		move_btn.text = "Upgrade (%d Bulloni) -> x%.2f" % [move_cost, next_move.speed_multiplier]
		move_btn.disabled = _game_state.team_credits < move_cost
		move_btn.pressed.connect(_purchase_upgrade.bind("movement", next_move_level))
		move_container.add_child(move_btn)
	else:
		var move_max = Label.new()
		move_max.text = "MAX"
		move_container.add_child(move_max)

	# Chiudi al click fuori o ESC
	_upgrade_panel.about_to_popup.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	_upgrade_panel.popup_hide.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

func _purchase_upgrade(category: String, level: int) -> void:
	if _game_state.purchase_upgrade(category, level):
		print("[PLAYER] Upgrade %s livello %d acquistato!" % [category, level])
		# Aggiorna pannello
		_toggle_upgrade_panel()  # Chiude
		_toggle_upgrade_panel()  # Riapre aggiornato
		# Aggiorna HUD capacità
		_update_inventory_hud()
	else:
		print("[PLAYER] Errore acquisto upgrade: Bulloni insufficienti o upgrade non disponibile")

var _upgrade_panel: PopupPanel = null

func set_as_local_player(peer_id: int) -> void:
	print("[PLAYER] set_as_local_player START for peer ", peer_id)
	is_local_player = true
	owner_peer_id = peer_id
	# Ensure camera is initialized (may be called before _ready())
	if not camera:
		camera = get_node_or_null("Camera3D")
	if camera:
		camera.current = true
		print("[PLAYER] Camera set as current: ", camera.current, " camera path: ", camera.get_path())
	else:
		print("[PLAYER] ERROR: Camera is null!")
	# Mesh locale nascosta in prima persona, remota visibile
	if not mesh_local:
		mesh_local = get_node_or_null("MeshInstance3D")
	if not mesh_remote:
		mesh_remote = get_node_or_null("RemoteMesh")
	if mesh_local:
		mesh_local.visible = false
	if mesh_remote:
		mesh_remote.visible = false
	if name_label:
		name_label.hide()
	_apply_local_settings()
	if DisplayServer.get_name()!="headless" and not is_instance_valid(_local_avatar):
		_local_avatar=preload("res://scripts/gameplay/worker_model.gd").new()
		_local_avatar.name="LocalWorker"
		_local_avatar.seated=0.0
		add_child(_local_avatar)
		for mesh in _local_avatar.find_children("*","MeshInstance3D",true,false):
			if mesh.layers==1<<19: mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		# The held-tool rig already supplies first-person arms. Keep the worker's
		# full silhouette in shadows without clipping a second pair into the lens.
		for index in [2,3,6,7]:
			_local_avatar.segments[index].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# Cattura mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_is_paused = false
	print("[PLAYER] set_as_local_player DONE - is_local_player: ", is_local_player, " mouse_mode: ", Input.mouse_mode, " camera.current: ", camera.current if camera else "null")

func set_as_remote_player(peer_id: int) -> void:
	is_local_player = false
	owner_peer_id = peer_id
	if camera:
		camera.current = false
		camera.hide()
	# Mesh locale nascosta, remota visibile per gli altri
	if mesh_local:
		mesh_local.visible = false
	if mesh_remote:
		mesh_remote.visible = true
	# Disabilita collisione per interpolazione fluida
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

func set_single_player_mode(enabled: bool) -> void:
	_single_player_mode = enabled
	if enabled:
		print('[PLAYER] Single player mode enabled')

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player or _is_paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_rotation.y -= event.relative.x * mouse_sensitivity
		look_rotation.x = clamp(look_rotation.x - event.relative.y * mouse_sensitivity * (-1.0 if _invert_y else 1.0), -max_pitch, max_pitch)
	if is_instance_valid(_placement):
		_placement.handle_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V and not _gameplay_key(event) and is_instance_valid(_mounted_vehicle) and _mounted_vehicle.level in [2,3]:
		_toggle_vehicle_view()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4] and not _gameplay_key(event):
		if event.keycode == KEY_4:
			_toggle_scooter()
		else:
			_equip_tool(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_5,KEY_6] and not _gameplay_key(event):
		_equip_tool(event.keycode-KEY_2)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P and not _gameplay_key(event):
		_toggle_parking_brake()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("recovery_mode"):
		_recover_intact = not _recover_intact
		_cancel_collection()
		if is_instance_valid(_target_scrap) and _target_scrap.is_in_group("salvage_assemblies"):
			_target_scrap.recover_intact = _recover_intact
		_notify("Modalità: recupera componente intero." if _recover_intact else "Modalità: separa materiali nella sacca.")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and not _gameplay_key(event):
		_scan_scrap(Input.is_key_pressed(KEY_SHIFT))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L and not _gameplay_key(event):
		_toggle_work_light()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B and not _gameplay_key(event):
		_open_scrap_book()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_J,KEY_M] and not _gameplay_key(event):
		_open_career("map" if event.keycode==KEY_M else "story")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I and not _gameplay_key(event):
		_open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if is_instance_valid(_dragged):
			_finish_drag()
			return
		_activate_interaction(preload("res://scripts/gameplay/interaction_focus.gd").resolve(self))
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if _is_paused:
		_close_pause_menu()
	else:
		_open_pause_menu()

func _open_pause_menu() -> void:
	if is_instance_valid(_dragged):
		_finish_drag()
	_open_panel("PAUSA")
	preload("res://scripts/ui/menu_art.gd").button_style(_add_panel_button("Riprendi", _close_pause_menu),true)
	_add_panel_button("Attrezzi", _open_inventory)
	_add_panel_button("Diario · Mappa", _open_career)
	_add_panel_button("Impostazioni", _show_settings)
	_add_panel_button("Menu principale", _quit_to_menu)
	_pause_menu.popup_centered(Vector2i(560, 220))

func _close_pause_menu() -> void:
	get_node("HUD").show()
	if is_instance_valid(_upgrade_monitor) and _upgrade_monitor.active:
		_upgrade_monitor.close()
	if is_instance_valid(_pause_menu):
		_pause_menu.popup_hide.disconnect(_close_pause_menu)
		_pause_menu.queue_free()
		_pause_menu = null
	_is_paused = false
	get_tree().paused = false
	# A page rebuild closes and reopens a panel in the same callback. Capturing
	# here warped the desktop pointer to the centre on every catalogue click.
	call_deferred("_capture_mouse_if_playing")

func _capture_mouse_if_playing() -> void:
	if is_local_player and not _is_paused and not is_instance_valid(_pause_menu):
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _clear_navigation() -> void:
	_career_tracking=false
	_career_route_key=""
	_navigation_label=""
	_navigation_target=global_position
	if is_instance_valid(_pause_menu):
		for atlas in _pause_menu.find_children("YardAtlas","Control",true,false): atlas.queue_redraw()
		if _pause_menu.has_meta("clear_waypoint"):
			_pause_menu.get_meta("clear_waypoint").disabled=true
	_notify("Meta rimossa.")

func _show_mission_status() -> void:
	# Show mission status popup
	var popup = PopupPanel.new()
	popup.title = "Stato Missione"
	popup.popup_centered()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var vbox = VBoxContainer.new()
	popup.add_child(vbox)

	var contract = _game_state.current_contract
	if contract:
		var contract_label = Label.new()
		contract_label.text = "Contratto: %s" % [contract.name]
		contract_label.horizontal_alignment = 1
		vbox.add_child(contract_label)

		var target_label = Label.new()
		target_label.text = "Obiettivo: %d %s" % [contract.target_count, contract.material_id]
		target_label.horizontal_alignment = 1
		vbox.add_child(target_label)

		var current_label = Label.new()
		var current = _game_state.team_deposit_counts[contract.material_id] if _game_state.team_deposit_counts.has(contract.material_id) else 0
		current_label.text = "Consegnato: %d / %d" % [current, contract.target_count]
		current_label.horizontal_alignment = 1
		vbox.add_child(current_label)

		var bonus_label = Label.new()
		bonus_label.text = "Bonus: %d Bulloni" % [contract.bonus_reward]
		bonus_label.horizontal_alignment = 1
		vbox.add_child(bonus_label)
	else:
		var no_contract = Label.new()
		no_contract.text = "Nessun contratto attivo"
		no_contract.horizontal_alignment = 1
		vbox.add_child(no_contract)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var credits_label = Label.new()
	credits_label.text = "Bulloni squadra: %d" % [_game_state.team_credits]
	credits_label.horizontal_alignment = 1
	vbox.add_child(credits_label)

	var close_btn = Button.new()
	close_btn.text = "Chiudi"
	close_btn.pressed.connect(popup.close)
	vbox.add_child(close_btn)

	popup.popup_hide.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)

func _show_settings() -> void:
	var dialog = preload("res://scenes/settings_dialog.tscn").instantiate()
	add_child(dialog)
	dialog.settings_applied.connect(_apply_local_settings)
	dialog.popup_hide.connect(dialog.queue_free)
	dialog.show_dialog()

func _apply_local_settings() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	mouse_sensitivity = float(config.get_value("controls", "mouse_sensitivity", 0.002))
	_invert_y = bool(config.get_value("controls", "invert_y", false))
	if camera:
		camera.fov = float(config.get_value("graphics", "fov", 80.0))

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * (log(linear) / log(10.0))

# Helper method for creating volume sliders in settings dialog
func _make_volume_slider(vbox: VBoxContainer, label_text: String, bus_name: String, config_key: String, default_val: float = 1.0) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = 1
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 1))
	hbox.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	# Load saved value
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		slider.value = cfg.get_value("audio", config_key, default_val)
	else:
		slider.value = default_val
	slider.size_flags_horizontal = 3
	hbox.add_child(slider)
	var val_lbl = Label.new()
	val_lbl.text = "%d%%" % [int(slider.value * 100)]
	val_lbl.size_flags_horizontal = 1
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = 1
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85, 1))
	hbox.add_child(val_lbl)
	slider.value_changed.connect(func(v):
		val_lbl.text = "%d%%" % [int(v * 100)]
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), linear_to_db(v))
		var cfg_audio = ConfigFile.new()
		if cfg_audio.load("user://settings.cfg") == OK:
			cfg_audio.set_value("audio", config_key, v)
			cfg_audio.save("user://settings.cfg")
	)

func _abandon_mission() -> void:
	# Confirm abandon
	var confirm = ConfirmationDialog.new()
	confirm.title = "Abbandona Missione"
	confirm.dialog_text = "Sei sicuro di voler abbandonare la missione?\nPerderai tutti i materiali non depositati."
	confirm.ok_button_text = "Abbandona"
	confirm.cancel_button_text = "Annulla"
	confirm.confirmed.connect(_do_abandon_mission)
	confirm.popup_centered()

func _do_abandon_mission() -> void:
	# Call session state to end mission
	_session.end_mission()
	_close_pause_menu()

func _quit_to_menu() -> void:
	var confirm = ConfirmationDialog.new()
	confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm.dialog_text = "Tornare al menu? Sacca, rottami recuperati e progressione verranno salvati.\nRiprenderai lo stesso settore; rinnova i recuperi dalla bilancia."
	confirm.confirmed.connect(_do_quit_to_menu)
	confirm.popup_hide.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()

func _do_quit_to_menu() -> void:
	_stop_cart()
	if not _save_progress():
		return
	_session._cleanup_and_return_to_menu()

var _towed_cart: Node3D

var _vehicle_support: CollisionShape3D
var _drag_velocity: Vector3 = Vector3.ZERO
var _drag_original_yaw: float = 0.0
var _drag_tether: MeshInstance3D
var _dragged: CollisionObject3D
var _drag_origin: Vector3

func _physics_process(delta: float) -> void:
	if is_local_player:
		_process_drag(delta)
		_process_local_input(delta)
		if not _single_player_mode:
			_send_input_to_host()
		_process_collection(delta)
		_update_inventory_hud()
		_feedback_lifetime = maxf(0, _feedback_lifetime - delta)
		if _feedback_lifetime <= 0:
			_feedback.text = ""
		_update_hint()
		_animate_equipment(delta)
		if is_instance_valid(_local_avatar):
			_local_avatar.visible=not is_instance_valid(_mounted_vehicle)
			if _local_avatar.visible: _local_avatar.animate_walk(delta,Vector2(velocity.x,velocity.z).length())
		_animate_vehicle_exit(delta)
		_sync_carried_visual()
		_update_work_light()
	else:
		_interpolate_remote(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	if is_local_player and is_instance_valid(_mounted_vehicle):
		_vehicle_motion.after_slide(self)
		_vehicle_speed = _vehicle_motion.speed
	if (multiplayer.is_server() or _single_player_mode) and global_position.y < fall_threshold_y:
		_respawn_at_spawn()
	if is_local_player:
		_game_state.player_positions[owner_peer_id] = global_position
		_game_state.player_rotations[owner_peer_id] = look_rotation.y

func _process_collection(delta: float) -> void:
	if _ignore_collect_until_release:
		if Input.is_action_pressed("collect"): return
		_ignore_collect_until_release=false
	if is_instance_valid(_placement):
		_cancel_collection()
		return
	if is_instance_valid(_dragged):
		_cancel_collection()
		return
	if not is_local_player or _is_paused or _vehicle_exit_time>0 or is_instance_valid(_mounted_vehicle) or not _game_state.operations.held.is_empty():
		return

	# Raycast dal centro della camera
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + camera.global_transform.basis.z * -_game_state.player_interaction_m
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = true  # Layer 1 per scrap items
	query.exclude = [self.get_rid()]

	var result = space_state.intersect_ray(query)
	var hit_scrap = null
	_world_hint = ""

	if result and result.collider:
		_target_hit_world = result.position
		var collider = result.collider
		if collider.has_meta("assembly"):
			hit_scrap = collider.get_meta("assembly")
			var component: int = int(collider.get_meta("component"))
			if hit_scrap.selected_component != component:
				_cancel_collection()
			hit_scrap.select_component(component)
			hit_scrap.recover_intact = _recover_intact
			hit_scrap.set_highlighted(true)
		elif collider.is_in_group("scrap") or collider.has_method("commit_stage"):
			hit_scrap = collider
			if collider.is_in_group("salvage_assemblies"):
				collider.recover_intact = _recover_intact
		elif collider.is_in_group("landfill_piles") or collider.is_in_group("landfill_scenery"):
			_world_hint = "CUMULO · cerca rottami sporgenti sui fianchi"

	# Aggiorna target scrap
	if hit_scrap != _target_scrap:
		_cancel_collection()
		if _target_scrap:
			_target_scrap.set_highlighted(false)
		_target_scrap = hit_scrap
		if _target_scrap:
			_target_scrap.set_highlighted(true)

	# Aggiorna reticolo
	if _reticle:
		if _target_scrap:
			_reticle.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1) if _collection_requirement().is_empty() else Color("#efb46c"))
		else:
			_reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

	# Gestione raccolta
	if Input.is_action_pressed("collect"):
		if _target_scrap and not _collecting:
			_start_collection()
		elif _collecting:
			_update_collection(delta)
	else:
		if _collecting:
			_cancel_collection()

func _start_collection() -> void:
	var reason: String = _collection_requirement()
	if not reason.is_empty():
		return
	if _target_scrap.has_method("can_start_collection") and not _target_scrap.can_start_collection():
		return
	_collecting = true
	_collect_progress = 0.0
	if _collect_progress_bar:
		_collect_progress_bar.visible = true
		_collect_progress_bar.value = 0

func _update_collection(delta: float) -> void:
	if not _collection_requirement().is_empty():
		_cancel_collection()
		return
	if _target_scrap.has_method("commit_stage"):
		_collect_progress += delta / (_target_scrap.collection_seconds() * _game_state.module_effect("workbench"))
		_collect_progress_bar.value = _collect_progress * 100
		if _target_scrap.has_method("set_work_progress"):
			_target_scrap.set_work_progress(_collect_progress)
		if _collect_progress >= 1.0:
			if _target_scrap.has_method("set_recovery_point"):
				_target_scrap.set_recovery_point(_target_hit_world)
			var result: Dictionary = _target_scrap.commit_stage(owner_peer_id, _active_tool())
			if result.success:
				_play_feedback("metal")
				_collection_fx(_target_scrap)
			_notify(result.message)
			_cancel_collection()
		return
	var material_id: String = _scrap_type_to_material_id(_target_scrap.scrap_type)
	_collect_progress += delta / (_game_state.recovery_seconds(material_id, _active_tool()))
	if _collect_progress_bar:
		_collect_progress_bar.value = _collect_progress * 100

	if _collect_progress >= 1.0:
		_complete_collection()

func _complete_collection() -> void:
	if _target_scrap:
		var scrap_data = _target_scrap.get_scrap_data()
		# Mappa tipo scrap a material_id
		var material_id = _scrap_type_to_material_id(scrap_data.type)
		var variant: int = preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(_target_scrap.entity_id)
		var requested: bool = _game_state.specifics.needs("%d_%d" % [_target_scrap.scrap_type,variant])
		# Aggiungi all'inventario via GameState
		var success = _game_state.recover_world_scrap(owner_peer_id, _target_scrap.entity_id, material_id, _active_tool())
		if success:
			# Raccogli l'oggetto (lo rimuove dalla scena)
			_game_state.ops.record_discovery(int(_target_scrap.scrap_type),preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(_target_scrap.entity_id))
			_play_feedback(material_id if material_id in ["metal","plastic","electronics"] else "metal")
			_collection_fx(_target_scrap)
			_target_scrap.collect()
			_notify("Raccolto: " + {"metal":"metallo", "plastic":"plastica", "electronics":"elettronica", "copper":"rame", "aluminum":"alluminio", "glass":"vetro", "rubber":"gomma"}.get(material_id, material_id))
			if requested:
				_notify("Pezzo riservato alla richiesta: depositalo per consegnarlo.")
			_target_scrap = null
			# Screen shake feedback
			_apply_screen_shake(0.15, 0.2)
		else:
			# Inventario pieno - mostra messaggio
			_notify("Sacca piena: torna al DEPOSITO." if not _game_state.can_add_to_inventory(owner_peer_id,material_id) else "Raccolta annullata: impossibile confermare o salvare il recupero.")

	_collecting = false
	_collect_progress = 0.0
	if _collect_progress_bar:
		_collect_progress_bar.visible = false
		_collect_progress_bar.value = 0

	# Reset reticolo
	if _reticle:
		_reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

func _apply_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration

func _update_screen_shake(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var t = 1.0 - _shake_timer / _shake_duration
		# Decay intensity
		var current_intensity = _shake_intensity * (1.0 - t)
		# Random shake offset
		_shake_offset = Vector3(
			randf_range(-1.0, 1.0) * current_intensity,
			randf_range(-1.0, 1.0) * current_intensity * 0.5,
			randf_range(-1.0, 1.0) * current_intensity
		)
		if camera:
			camera.position = _shake_offset
	else:
		if camera and camera.position != Vector3.ZERO:
			camera.position = camera.position.lerp(Vector3.ZERO, delta * 10.0)

func _scrap_type_to_material_id(type_int: int) -> String:
	match type_int:
		0: return "metal"
		1: return "plastic"
		2: return "electronics"
		3: return "copper"
		4: return "aluminum"
		5: return "glass"
		6: return "rubber"
		7: return "textile"
		8: return "hazardous"
	return "metal"

func _cancel_collection() -> void:
	if is_instance_valid(_target_scrap) and _target_scrap.has_method("set_work_progress"):
		_target_scrap.set_work_progress(0)
	_collecting = false
	_collect_progress = 0.0
	if _collect_progress_bar:
		_collect_progress_bar.visible = false
		_collect_progress_bar.value = 0

func _process_local_input(_delta: float) -> void:
	if _is_paused:
		return
	if is_instance_valid(_mounted_vehicle):
		_drive_vehicle(_delta)
		return
	input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_sprinting = Input.is_action_pressed("sprint")
	var speed: float = _game_state.player_sprint_mps if is_sprinting else _game_state.player_walk_mps
	speed *= float(_game_state.get_upgrade_effect("movement"))
	if not _game_state.operations.held.is_empty():
		speed = float(_game_state.logistics_def.carry_walk_mps)*float(_game_state.get_upgrade_effect("movement"))
	if is_instance_valid(_dragged):
		speed = float(_game_state.logistics_def.get("drag_speed_mps",1.8))*_game_state.module_effect("harness")*_drag_mobility()*0.8
	if is_instance_valid(_towed_cart):
		speed = minf(speed,float(_game_state.logistics_def.crafting.handcart.tow_speed_mps))
	rotation.y = look_rotation.y
	camera.basis = Basis.from_euler(Vector3(look_rotation.x, 0, 0))
	var direction: Vector3 = (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_instance_valid(_towed_cart):
		velocity.y = jump_velocity * (0.6 if not _game_state.operations.held.is_empty() else 1.0)

func _send_input_to_host() -> void:
	if _single_player_mode:
		# Single player: processa localmente senza rete
		_process_input_on_host()
		return

	if multiplayer.is_server():
		# Host processa direttamente
		_process_input_on_host()
	else:
		# Client invia RPC
		input_sequence += 1
		last_input_time = Time.get_ticks_msec() / 1000.0

		var move = Vector2(input_vec.x, input_vec.y)
		rpc_id(1, "rpc_receive_input", owner_peer_id, input_sequence, move, is_sprinting, jump_requested, look_rotation.y)

		jump_requested = false  # Consumato

@rpc("any_peer", "call_local", "unreliable")
func rpc_receive_input(peer_id: int, seq: int, move: Vector2, sprint: bool, jump: bool, yaw: float) -> void:
	# Solo host: valida e applica
	if not multiplayer.is_server():
		return

	# Validazione base
	if seq <= 0:
		return
	if move.length() > 1.5:
		return
	if yaw < -3.15 or yaw > 3.15:
		return

	# Trova player
	var player = _find_player_by_peer(peer_id)
	if not player:
		return

	# Applica input simulato
	player._apply_host_input(move, sprint, jump, yaw, seq)

func _apply_host_input(move: Vector2, sprint: bool, jump: bool, yaw: float, seq: int) -> void:
	input_vec = move
	is_sprinting = sprint
	if jump and is_on_floor():
		velocity.y = jump_velocity
	rotation.y = yaw
	look_rotation.y = yaw
	input_sequence = seq
	last_input_time = Time.get_ticks_msec() / 1000.0

func _process_input_on_host() -> void:
	# Host processa il proprio input localmente
	_process_local_input(0)  # delta già gestito in _physics_process
	input_sequence += 1
	last_input_time = Time.get_ticks_msec() / 1000.0

func _interpolate_remote(delta: float) -> void:
	# Interpolazione semplice per player remoti
	if _interpolation_buffer.size() < 2:
		return

	var target = _interpolation_buffer[0]
	var next = _interpolation_buffer[1]

	var t = (Time.get_ticks_msec() / 1000.0 - target.time) * 1000.0 / INTERPOLATION_MS
	t = clamp(t, 0.0, 1.0)

	global_position = global_position.lerp(target.position, t * 10.0 * delta)
	rotation.y = lerp_angle(rotation.y, target.rotation, t * 10.0 * delta)

	# Rimuovi vecchi
	if _interpolation_buffer.size() > 10:
		_interpolation_buffer.pop_back()

func receive_snapshot(state: Dictionary) -> void:
	# Chiamato da ReplicationService per aggiornare stato remoto
	if is_local_player:
		return

	_target_position = state.position
	_target_rotation = state.rotation

	_interpolation_buffer.insert(0, {
		"time": Time.get_ticks_msec() / 1000.0,
		"position": state.position,
		"rotation": state.rotation
	})

func _find_player_by_peer(peer_id: int) -> PlayerController:
	# Cerca nel tree
	for node in get_tree().get_nodes_in_group("players"):
		if node.owner_peer_id == peer_id:
			return node
	return null

func lerp_angle(from: float, to: float, weight: float) -> float:
	var diff = wrapf(to - from, -PI, PI)
	return from + diff * weight

func _respawn_at_spawn() -> void:
	if is_instance_valid(_placement): _placement.cancel()
	# Trova spawn point
	var sector = get_tree().get_first_node_in_group("sector")
	if not sector:
		return
	var spawn_points = sector.get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	var points = spawn_points.get_children()
	if points.is_empty():
		return

	var idx = (owner_peer_id - 1) % points.size()
	var spawn_point = points[idx]
	global_position = spawn_point.global_position + Vector3(0, respawn_height, 0)
	velocity = Vector3.ZERO
	_vehicle_motion.speed = 0.0
	_vehicle_speed = 0.0
	print("[PLAYER] Respawned peer " + str(owner_peer_id) + " at " + str(global_position))

# Metodi interazione (raccolta, deposito) - stub per uso futuro
func try_collect(entity_id: String) -> void:
	if not is_local_player:
		return
	var request_id = "%d_%d" % [owner_peer_id, Time.get_ticks_msec()]
	rpc_id(1, "rpc_collect_begin", request_id, entity_id)

func try_deposit() -> void:
	if not is_local_player:
		return
	var request_id = "%d_%d" % [owner_peer_id, Time.get_ticks_msec()]
	rpc_id(1, "rpc_deposit", request_id)

# RPC per azioni economiche (gestite da CommandService su host)
@rpc("any_peer", "call_local", "reliable")
func rpc_collect_begin(request_id: String, entity_id: String) -> void:
	print("Raccolta richiesta: %s da peer %d" % [entity_id, multiplayer.get_remote_sender_id()])

@rpc("any_peer", "call_local", "reliable")
func rpc_deposit(request_id: String) -> void:
	print("Deposito richiesto da peer %d" % multiplayer.get_remote_sender_id())

func get_inventory() -> Dictionary:
	return _game_state.player_inventories[owner_peer_id] if _game_state.player_inventories.has(owner_peer_id) else {}

func get_inventory_mass() -> float:
	return _game_state.get_inventory_mass(owner_peer_id)

func _near_depot() -> bool:
	var sector = get_tree().get_first_node_in_group("sector")
	return sector != null and global_position.distance_to(sector.get_node("DepositZone").global_position) <= _game_state.player_interaction_m

func _notify(message: String) -> void:
	_feedback.text = message
	_feedback_lifetime = 3.2

func _update_hint() -> void:
	if is_instance_valid(_placement):
		_interact_prompt.hide()
		return
	var key_text: String = InputMap.action_get_events("interact")[0].as_text()
	var sector = get_tree().get_first_node_in_group("sector")
	var distance: float = global_position.distance_to(sector.get_node("DepositZone").global_position)
	var order: Dictionary = _game_state.current_order()
	var goal: String = "CENTRO DI RECUPERO  %d/%d · %s" % [_game_state.completed_orders.size(), _game_state.order_defs.size(), order.name] if not order.is_empty() else ("FORNITURA · "+_game_state.ops.delivery_definition().name if not _game_state.ops.delivery_definition().is_empty() else "CENTRO CERTIFICATO · Scegli una fornitura al monitor")
	if not _game_state.operations.held.is_empty():
		goal = "TRASPORTO · %s · %d kg · E carica / deposita / appoggia" % [_game_state.part_defs[_game_state.operations.held.kind].name,_game_state.part_defs[_game_state.operations.held.kind].mass_kg]
	if is_instance_valid(_mounted_vehicle):
		goal = "%s · %02d km/h · %s" % [_mounted_vehicle.motion_definition().name, roundi(absf(_vehicle_speed) * 3.6), InputMap.action_get_events("jump")[0].as_text()+" · SALTA" if _mounted_vehicle.level == 1 else key_text+" · SCENDI | V · VISUALE | L · FARI | P · "+("FRENO INSERITO" if _vehicle_motion.parking_brake else "FRENO LIBERO")+" | "+InputMap.action_get_events("jump")[0].as_text()+" · FRENO A MANO"]
	if is_instance_valid(_towed_cart):
		goal = "CARRELLO AL TRAINO · %.0f / 60 kg · [%s] LASCIA" % [_game_state.crafting.cart_mass(_towed_cart.craft_id),key_text]
	_hint.text = preload("res://scripts/gameplay/yard_clock.gd").caption()+"\n"+"%s  /  BASE %.0f m\n%s" % [_region_name(), distance, goal]
	if not _game_state.specifics.payload().is_empty():
		_hint.text += "\nRICHIESTA · %s · SACCA %d / CASSONE %d / DEPOSITO %d" % [_game_state.specifics.definition().name,_game_state.specifics.units("bag"),_game_state.specifics.units("cargo"),_game_state.specifics.units("stock")]
	if not _navigation_label.is_empty():
		var local_direction: Vector3 = global_transform.basis.inverse() * (_navigation_target - global_position)
		var direction: String = "AVANTI" if local_direction.z < 0 and absf(local_direction.x) < absf(local_direction.z) * 0.5 else ("DESTRA" if local_direction.x > 0 else "SINISTRA")
		_hint.text += "\n%s · %s · %.0f m" % [_navigation_label, direction, global_position.distance_to(_navigation_target)]
	if not is_instance_valid(_mounted_vehicle) and _game_state.story!=null:
		if _career_hud_step.is_empty() or Engine.get_physics_frames()-_career_hud_frame>=12:
			_career_hud_step = _game_state.story.next_step()
			_career_hud_frame = Engine.get_physics_frames()
		var step: Dictionary = _career_hud_step
		_hint.text += "\nPROSSIMO · "+step.title+" · [J] DIARIO"
		if _career_tracking:
			var route_key: String = step.route+step.material
			if route_key!=_career_route_key:
				_apply_career_route(step)
	var prompt: String = ""
	var anchor: Vector3 = global_position + Vector3.UP * 2
	var focus: Dictionary = preload("res://scripts/gameplay/interaction_focus.gd").resolve(self)
	if focus.has("anchor"):
		anchor = focus.anchor
	match focus.kind:
		"dismount": prompt = "[%s] SCENDI" % key_text
		"uncouple": prompt = "[%s] LASCIA CARRELLO · %.0f / 60 kg" % [key_text,_game_state.crafting.cart_mass(focus.node.craft_id)]
		"crafted": prompt = "PREMI [%s] · %s" % [key_text,_game_state.crafting.definitions()[focus.node.kind].name.to_upper()]
		"carry": prompt = "[%s] %s" % [key_text,"CARICA NEL CASSONE" if _near_cargo_bay()!=null else ("DEPOSITA COMPONENTE" if _at_parts_storage() else "APPOGGIA A TERRA")]
		"bulk": prompt = "[%s] SOLLEVA · DESTRO TRASCINA\n%s" % [key_text,focus.node.display_name()]
		"cargo": prompt = "PREMI [%s] · CASSONE\n%.0f / %d kg" % [key_text,_game_state.ops.cargo_mass(),_game_state.ops.cargo_capacity()]
		"operation":
			prompt = "PREMI [%s] · %s" % [key_text,{"identity":"INSEGNA · PERSONALIZZA","recovery":"BANCO RECUPERO","dispatch":"BANCHINA SPEDIZIONI","warehouse":"MAGAZZINO COMPONENTI","craft":"BANCO COSTRUZIONE","fabrication":"ASSEMBLAGGIO","customer":"CLIENTE · ORDINI","career":"DIARIO · RIVA SECCA"}[focus.service]]
			if focus.service=="customer":
				prompt = "PREMI [%s] · %s %s" % [key_text,"PARLA CON" if focus.node.get_meta("customer_active",true) else "POSTAZIONE",_game_state.crafting.customer(str(focus.node.get_meta("customer"))).name.get_slice(" · ",0).to_upper()]
		"secret": prompt = "PREMI [%s] · OSSERVA\n%s" % [key_text,"CURIOSITÀ ARCHIVIATA" if focus.node.secret_id in _game_state.secrets_found else "OGGETTO INSOLITO"]
		"field_depot": prompt = "PREMI [%s] · SCARICA\nDEPOSITO SATELLITE" % key_text
		"vehicle": prompt = "PREMI [%s] · GUIDA\n%s" % [key_text,focus.node.motion_definition().name]
		"terminal": prompt = "PREMI [%s] PER APRIRE\n%s" % [key_text,{"tools":"MONITOR · UPGRADE","vehicles":"GARAGE · VEICOLI","land":"PLANIMETRIA · ESPANSIONI","journal":"ALBUM DELLE CURIOSITÀ"}[focus.service]]
		"press": prompt = "PREMI [%s] · PRESSA P-01" % key_text
		"depot": prompt = "PREMI [%s] · BILANCIA\nScarica e vendi i materiali" % key_text
	if focus.kind=="none" and is_instance_valid(_target_scrap):
		anchor = _target_scrap.global_position + Vector3.UP * (2.3 if _target_scrap.is_in_group("salvage_assemblies") else 1.0)
		if _target_scrap.is_in_group("salvage_assemblies"):
			anchor=_target_hit_world+camera.global_basis.y*0.42
		if _target_scrap.has_method("can_start_collection"):
			anchor = _target_hit_world + Vector3.UP * 0.7
		if _target_scrap.has_method("commit_stage"):
			prompt = "TIENI SINISTRO\n" + _target_scrap.display_name()
			if _target_scrap.is_in_group("landfill_piles") or _target_scrap.is_in_group("landfill_scenery"): prompt+="\nDESTRO · SPOSTA I FRAMMENTI"
			if _target_scrap.is_in_group("salvage_assemblies"):
				prompt += "\n[%s] CAMBIA RECUPERO" % InputMap.action_get_events("recovery_mode")[0].as_text()
			if _target_scrap.has_method("can_start_collection") and not _target_scrap.can_start_collection():
				prompt = _target_scrap.display_name()
		else:
			var id: String = _scrap_type_to_material_id(_target_scrap.scrap_type)
			var definition: Dictionary = _game_state.material_defs[id]
			var name_text: String = {"metal":"Metallo", "plastic":"Plastica", "electronics":"Elettronica", "copper":"Rame", "aluminum":"Alluminio", "glass":"Vetro", "rubber":"Gomma"}.get(id, id)
			prompt = "TIENI SINISTRO · %s\n%s · %d kg / %d Bulloni%s" % [_target_scrap.display_name().to_upper(), name_text, definition.mass_kg, definition.credits, " · NASCOSTO" if _target_scrap.is_in_group("hidden_salvage") else ""]
			var request_key: String = "%d_%d" % [_target_scrap.scrap_type,preload("res://scripts/gameplay/scrap_catalog.gd").variant_for(_target_scrap.entity_id)]
			if _game_state.specifics.needs(request_key):
				prompt += "\nRICHIESTA · PEZZO RISERVATO AL DEPOSITO"
	if is_instance_valid(_target_scrap) and not _is_paused and prompt.begins_with("TIENI SINISTRO"):
		var requirement: String = _collection_requirement()
		if not requirement.is_empty():
			prompt = requirement
	_interact_prompt.modulate = Color("#ffba7a") if is_instance_valid(_target_scrap) and not _collection_requirement().is_empty() else Color("#ffe4aa")
	if is_instance_valid(_dragged):
		prompt = "TRASCINA · %.0f kg\nRilascia destro per lasciare" % _drag_mass()
		anchor = _dragged.global_position+Vector3.UP
	_interact_prompt.pixel_size = 0.0018
	_interact_prompt.font_size = 26
	if is_instance_valid(_prompt_backing):
		var longest: int = 0
		for line in prompt.split("\n"):
			longest = maxi(longest,line.length())
		_prompt_backing.mesh.size = Vector2(clampf(longest*0.024+0.08,0.28,1.35),prompt.split("\n").size()*0.065+0.05)
	_interact_prompt.text = prompt
	_interact_prompt.global_position = _fit_world_prompt(anchor)
	_interact_prompt.visible = not _is_paused and not prompt.is_empty() and not camera.is_position_behind(anchor)

func _fit_world_prompt(anchor: Vector3) -> Vector3:
	var depth: float = -camera.to_local(anchor).z
	if depth<=0.05 or not is_instance_valid(_prompt_backing):
		return anchor
	var center: Vector2 = camera.unproject_position(anchor)
	var half: Vector2 = _prompt_backing.mesh.size*0.5
	var extent = Vector2(camera.unproject_position(anchor+camera.global_basis.x*half.x).distance_to(center),camera.unproject_position(anchor+camera.global_basis.y*half.y).distance_to(center))
	var viewport: Rect2 = get_viewport().get_visible_rect()
	var factor: float = minf(1.0,minf(viewport.size.x*0.45/maxf(extent.x,0.001),viewport.size.y*0.45/maxf(extent.y,0.001)))
	_interact_prompt.scale=Vector3.ONE*factor
	extent*=factor
	var margin: Vector2 = extent+Vector2(16,16)
	var fitted = Vector2(clampf(center.x,viewport.position.x+margin.x,viewport.end.x-margin.x),clampf(center.y,viewport.position.y+margin.y,viewport.end.y-margin.y))
	return camera.project_position(fitted,depth)

func _open_panel(title_text: String) -> void:
	if is_instance_valid(_placement): _placement.cancel()
	_stop_cart()
	if is_instance_valid(_dragged):
		_finish_drag()
	_cancel_collection()
	get_node("HUD").hide()
	_interact_prompt.hide()
	if is_instance_valid(_held_tool):
		_held_tool.hide()
	_is_paused = true
	if _single_player_mode:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_menu = PopupPanel.new()
	_pause_menu.theme = preload("res://scripts/ui/industrial_theme.gd").create()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	_pause_menu.popup_hide.connect(_close_pause_menu)
	_pause_menu.window_input.connect(_on_panel_shortcut.bind(title_text))
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 16)
	_pause_menu.add_child(_panel_box)
	var art = preload("res://scripts/ui/menu_art.gd")
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	_panel_box.add_child(header)
	var identity: Array = art.SYMBOLS.identity(title_text)
	var emblem = TextureRect.new()
	emblem.texture = art.SYMBOLS.icon(identity[1])
	emblem.custom_minimum_size = Vector2(36,36)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.modulate = Color("#ed9853")
	header.add_child(emblem)
	var heading = art.label(identity[0].to_upper(),25,Color("#e9e1ce"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_panel_wallet = art.label("%d Bulloni" % _game_state.team_credits,18,Color("#edbc60"))
	header.add_child(_panel_wallet)
	var close_button = Button.new()
	close_button.icon = art.SYMBOLS.icon("close")
	close_button.tooltip_text = "Chiudi · Esc"
	close_button.custom_minimum_size = Vector2(46, 46)
	close_button.pressed.connect(_close_pause_menu)
	header.add_child(close_button)
	var divider = HSeparator.new()
	_panel_box.add_child(divider)

func _add_panel_button(label_text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = label_text
	preload("res://scripts/ui/menu_art.gd").button_style(button)
	button.pressed.connect(callback)
	_panel_box.add_child(button)
	if callback==_close_pause_menu and (label_text.begins_with("TORNA") or label_text.begins_with("CHIUDI") or label_text.begins_with("ESCI DAL")):
		button.hide() # Header X and Esc already close the panel.
	return button

func _open_station(page: String = "trade") -> void:
	preload("res://scripts/ui/station_panel.gd").open(self,page)

func _refresh_station() -> void:
	_update_inventory_hud()
	var reserve: Dictionary = _game_state.story.reserves()
	var lines: PackedStringArray = []
	var names = preload("res://scripts/ui/yard_panels.gd")
	for material in reserve.materials:
		if int(reserve.materials[material])>0:
			lines.append("%s %d" % [names._material_name(material),reserve.materials[material]])
	_station_status.text = "SACCA     %.0f / %d kg\nAVANZI     %d Bulloni\nDEPOSITO     %d Bulloni · %d balle" % [get_inventory_mass(),_game_state.get_inventory_capacity(owner_peer_id),_game_state.story.surplus_value(),_game_state.get_deposit_value(),_game_state.press_bales]
	_station_status.tooltip_text = "Riservati agli obiettivi: %s · %d balle. Vendi avanzi conserva queste scorte." % [", ".join(lines),reserve.bales]
	_station_status.add_theme_font_size_override("font_size",22)
	_station_buy.disabled = true
	if is_instance_valid(_station_deposit):
		_station_deposit.disabled=get_inventory_mass()<=0
	if is_instance_valid(_station_surplus):
		_station_surplus.disabled=_game_state.story.surplus_value()<=0
	if is_instance_valid(_station_all_sale):
		_station_all_sale.disabled=_game_state.get_deposit_value()<=0
	preload("res://scripts/ui/station_panel.gd").refresh(self)

func _sell_deposit() -> void:
	if not _near_depot():
		return
	var revenue: int = EconomyService.sell_deposit()
	_notify("Vendita: +%d Bulloni." % revenue if revenue > 0 else ("Vendita non confermata: scorte conservate." if _game_state.get_deposit_value()>0 else "Deposito vuoto: nessun accredito."))
	_refresh_station()

func _buy_bag() -> void:
	if not _near_depot() or _game_state.team_upgrade_levels.bag != 0:
		return
	if EconomyService.purchase_upgrade("bag"):
		_notify("Acquistata sacca da 30 kg!")
		_save_progress()
	else:
		_notify("Bulloni insufficienti.")
	_refresh_station()

func _save_progress() -> bool:
	var saved: bool = SaveService.save_checkpoint()
	if not saved:
		_notify("ERRORE salvataggio. Progressi in memoria: riprova prima di uscire.")
	return saved

func _new_expedition() -> void:
	if _game_state.ops.cargo_mass()>0:
		_notify("Scarica il cassone prima di rinnovare il settore: il carico resta al sicuro.")
		_refresh_station()
		return
	if get_inventory_mass() > 0:
		_notify("Deposita la sacca prima di partire: non perderai materiali.")
		_refresh_station()
		return
	if not _save_progress():
		_refresh_station()
		return
	_close_pause_menu()
	if not _game_state.reset_for_new_mission("C01",true):
		_notify("Carica o recupera i componenti prima di rinnovare il settore.")
		return
	_session.transition_to(_session.ConnectionState.LOADING)
	get_tree().reload_current_scene()

func _near_press() -> bool:
	var press = get_tree().get_first_node_in_group("industrial_press")
	return press != null and global_position.distance_to(press.interaction_position()) <= _game_state.player_interaction_m

func _open_press() -> void:
	if _game_state.press_owned:
		_open_production_queue()
		return
	preload("res://scripts/ui/press_panel.gd").purchase(self)

func _refresh_press() -> void:
	_update_inventory_hud()
	var definition: Dictionary = _game_state.press_def
	var units: int = int(definition.input_units)
	var mass: int = units * int(_game_state.material_defs[definition.input_material].mass_kg)
	var state: String = "IMPIANTO DA ACQUISTARE"
	if _game_state.press_owned:
		state = "PRONTA" if _game_state.press_remaining <= 0 else "LOTTO IN LAVORAZIONE · %.1f s rimanenti" % _game_state.press_remaining
	_station_status.text = "%s\n\n%d metalli (%d kg)  →  1 balla\n%d Bulloni  ·  %.0f s\n\nMetalli: %d   ·   Balle: %d" % [state, units, mass, _game_state.get_bale_value(), _game_state.press_cycle_seconds(), _game_state.team_deposit_counts.metal, _game_state.press_bales]
	_station_status.add_theme_font_size_override("font_size",22)
	_station_buy.text = "Posseduta" if _game_state.press_owned else "Acquista · %d Bulloni" % definition.cost
	_station_buy.disabled = _game_state.press_owned or _game_state.team_credits < int(definition.cost)
	_press_start_button.text = "LAVORA %d METALLI → 1 BALLA" % units
	_press_start_button.disabled = not _game_state.press_owned or _game_state.press_remaining > 0 or _game_state.team_deposit_counts.metal < units
	preload("res://scripts/ui/press_panel.gd").refresh(self)

func _purchase_press() -> void:
	if not _near_press():
		return
	_game_state.purchase_press()
	_refresh_press()

func _begin_press() -> void:
	if not _near_press():
		return
	if _game_state.start_press():
		_close_pause_menu()
	else:
		_refresh_press()

func _open_development() -> void:
	_close_pause_menu()
	_upgrade_monitor = get_tree().get_first_node_in_group("upgrade_monitor")
	if _upgrade_monitor != null:
		_upgrade_monitor.open(self)

func _back_to_station() -> void:
	_close_pause_menu()
	_open_station()

func _buy_development(category: String) -> void:
	if not _near_garage():
		return
	var snapshot: Dictionary = _game_state.serialize().duplicate(true)
	if EconomyService.purchase_upgrade(category):
		if not _save_progress():
			_game_state.deserialize(snapshot)
		else:
			if category == "tool":
				_equipped_tool = int(_game_state.team_upgrade_levels.tool)
			_notify("Sbloccato: %s · tasto %d" % [_game_state.tool_defs[_active_tool()].name, _active_tool() + 1] if category == "tool" else "Dotazione acquistata e salvata.")
	_open_development()

func _buy_land() -> void:
	if _near_service("land") == "land":
		if _game_state.purchase_land():
			var index: int = _game_state.yard_level - 1
			_navigation_target = preload("res://scripts/gameplay/expansion_lots.gd").CENTERS[index] + Vector3(-34, 0, 25)
			_navigation_label = "LOTTO EST" if index == 0 else "LOTTO DELLE DUNE"
			_notify("Lotto aperto subito. Segui l'itinerario dal varco Est: risorse e scarico satellite sono pronti.")
		else:
			_notify(_game_state.land_requirement_message() if not _game_state.land_requirement_message().is_empty() else "Salvataggio non riuscito: progetto non addebitato.")
	_open_land()

func _near_garage() -> bool:
	return _near_service("tools") == "tools"

func _enter_workshop_zone() -> void:
	pass # L'ingresso nel garage non apre mai un pannello.

func _open_inventory() -> void:
	preload("res://scripts/ui/equipment_panel.gd").open(self)

func _sell_one(material_id: String, source: String) -> void:
	if not _near_depot():
		return
	var snapshot: Dictionary = _game_state.serialize().duplicate(true)
	var inventory_before: Dictionary = get_inventory().duplicate()
	var value: int = _game_state.sell_inventory_item(owner_peer_id, material_id) if source == "bag" else _game_state.sell_material(material_id)
	if value > 0:
		if not _save_progress():
			_game_state.deserialize(snapshot)
			_game_state.player_inventories[owner_peer_id] = inventory_before
		else:
			_notify("Venduta 1 unità: +%d Bulloni." % value)
	_open_cargo()

func _open_vehicle_shop() -> void:
	if _vehicle_selection in [2,3]:
		preload("res://scripts/ui/extra_vehicle_panel.gd").open(self,"skateboard" if _vehicle_selection==2 else "dirtbike")
		return
	_close_pause_menu()
	_open_panel("GARAGE / PARCO MEZZI")
	var selection: int = mini(_game_state.vehicle_level, 1) if _vehicle_selection < 0 else _vehicle_selection
	var art = preload("res://scripts/ui/menu_art.gd")
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	_panel_box.add_child(layout)
	var navigation = VBoxContainer.new()
	navigation.custom_minimum_size.x = 230
	navigation.add_theme_constant_override("separation", 14)
	layout.add_child(navigation)
	navigation.add_child(art.label("CATALOGO MEZZI", 13, Color("#8faeae")))
	for index in 4:
		var tile = Button.new()
		tile.text = ["Monopattino","Buggy","Skateboard","Moto da cross"][index] + ("  ✓" if _game_state.vehicle_level > index else "")
		tile.pressed.connect(_select_vehicle.bind(index))
		tile.icon = art.SYMBOLS.icon(["scooter","truck","skateboard","dirtbike"][index])
		art.button_style(tile, index == selection)
		navigation.add_child(tile)
	var details = VBoxContainer.new()
	details.custom_minimum_size.x = 510
	var personalize=Button.new()
	personalize.text="Insegna e colori"
	personalize.pressed.connect(_open_personalization)
	art.button_style(personalize)
	navigation.add_child(personalize)
	details.add_theme_constant_override("separation", 14)
	layout.add_child(details)
	var illustration = TextureRect.new()
	illustration.texture = preload("res://scripts/ui/salvage_ui.gd").image("scooter" if selection==0 else "buggy")
	illustration.custom_minimum_size = Vector2(510, 160 if selection==1 and _game_state.vehicle_level>=2 else 220)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details.add_child(illustration)
	var definition: Dictionary = _game_state.vehicle_defs[selection]
	var owned: bool = _game_state.vehicle_level > selection
	var available: bool = _game_state.vehicle_level == selection and _game_state.yard_level >= int(definition.requires_land)
	details.add_child(art.label(definition.name.to_upper(), 25))
	details.add_child(art.label("%.0f m/s  /  %s" % [definition.speed_mps, "ATTREZZATURA PORTATILE" if selection == 0 else "%d KG DI CASSONE" % _game_state.ops.cargo_capacity()], 15, Color("#edbc60")))
	art.details(details,"4: equipaggia o riponi. Spazio: salta." if selection==0 else "E sul sedile: guida. E sul cassone: carica. P: freno. V: visuale.","Comandi")
	var requirement: String = "Nessun requisito." if selection == 0 else "Richiede: monopattino e Lotto Est."
	details.add_child(art.label("POSSEDUTO · pronto all'uso" if owned else requirement, 15, Color("#8dbdac")))
	var purchase = Button.new()
	purchase.text = "Posseduto" if owned and selection == 0 else ("Nel parcheggio" if owned else ("ACQUISTA  ·  %d Bulloni" % definition.cost if available else "Bloccato"))
	purchase.disabled = owned or not available or _game_state.team_credits < int(definition.cost)
	purchase.pressed.connect(_buy_vehicle)
	art.button_style(purchase, not purchase.disabled)
	if not (owned and selection==1):
		details.add_child(purchase)
	else:
		purchase.free()
		var vehicle: Node3D
		for candidate in get_tree().get_nodes_in_group("yard_vehicles"):
			if candidate.level==2:
				vehicle=candidate
		var actions = HBoxContainer.new()
		details.add_child(actions)
		preload("res://scripts/ui/crafting_panel.gd").button(actions,"INDICA IL BUGGY",_track_location.bind(vehicle.global_position,"BUGGY PARCHEGGIATO") if vehicle!=null else _close_pause_menu,vehicle!=null)
		var cost: int = int(_game_state.logistics_def.buggy_recovery_cost)
		var parking: Array = _game_state.logistics_def.buggy_parking
		var recovery_point = Vector3(parking[0],parking[1],parking[2])
		preload("res://scripts/ui/crafting_panel.gd").button(actions,"SOCCORSO · %d BULLONI" % cost,_recover_owned_buggy,vehicle!=null and vehicle.parked and _game_state.team_credits>=cost and vehicle.global_position.distance_to(recovery_point)>=1)
		art.details(details,"Il soccorso conserva tutto il cassone. Il parcheggio deve essere libero.","Soccorso")
	_add_panel_button("ESCI DAL GARAGE", _close_pause_menu)
	_pause_menu.popup_centered(Vector2i(880, 650))

func _select_vehicle(index: int) -> void:
	_vehicle_selection = index
	_open_vehicle_shop()

func _buy_vehicle() -> void:
	if _near_service("vehicles") != "vehicles":
		return
	if _game_state.purchase_vehicle():
		get_tree().get_first_node_in_group("sector").spawn_owned_vehicles()
		_notify("Monopattino acquistato: premi 4 per equipaggiarlo." if _game_state.vehicle_level == 1 else "Buggy acquistato: ritiralo nel parcheggio del garage.")
	_open_vehicle_shop()

func _aims_at(point: Vector3, radius: float, exclude: Array = []) -> bool:
	var direction: Vector3 = -camera.global_basis.z
	var distance: float = (point-camera.global_position).dot(direction)
	if distance < 0 or distance > 3.0:
		return false
	if (camera.global_position+direction*distance).distance_to(point) > radius:
		return false
	var ignored: Array[RID] = [get_rid()]
	ignored.append_array(exclude)
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,point,1,ignored)).is_empty()

func _nearest_vehicle() -> Node3D:
	for vehicle in get_tree().get_nodes_in_group("yard_vehicles"):
		var seat: Vector3 = vehicle.to_global(Vector3(0,1.2,0.15))
		var local_position: Vector3 = vehicle.to_local(global_position)
		if vehicle.available() and (vehicle.level == 1 or (absf(local_position.x)>0.8 and local_position.z<0.85)) and global_position.distance_to(vehicle.global_position) <= 3.0 and _aims_at(seat,0.65,[vehicle.body.get_rid()]):
			return vehicle
	return null

func _mount_vehicle(vehicle: Node3D) -> bool:
	_stop_cart()
	if not _game_state.operations.held.is_empty():
		_notify("Carica o deposita il componente prima di guidare.")
		return false
	if is_instance_valid(_dragged):
		_finish_drag()
	if is_instance_valid(_mounted_vehicle) or vehicle == null or not vehicle.available() or global_position.distance_to(vehicle.global_position) > 3.0:
		return false
	_cancel_collection()
	if is_instance_valid(_target_scrap):
		_target_scrap.set_highlighted(false)
	_target_scrap = null
	_vehicle_entry_side=signf(vehicle.to_local(global_position).x)
	if _vehicle_entry_side==0: _vehicle_entry_side=1.0
	_vehicle_entry_time=0.24 if vehicle.level==2 else 0.0
	_vehicle_exit_time=0.0
	_mounted_vehicle = vehicle
	if is_instance_valid(_local_avatar): _local_avatar.hide()
	_vehicle_heading = vehicle.rotation.y
	look_rotation.y = _vehicle_heading
	if vehicle.level==2:
		look_rotation.x = 0.0
	_vehicle_motion.reset(_vehicle_heading, velocity if vehicle.level == 1 else Vector3.ZERO, vehicle.motion_definition())
	_vehicle_speed = _vehicle_motion.speed
	_walking_shape = collision.shape
	_walking_shape_position = collision.position
	_walking_snap = floor_snap_length
	_walking_camera_mask = camera.cull_mask
	camera.cull_mask &= ~(1 << 19)
	floor_snap_length = 0.65
	floor_constant_speed = false
	if vehicle.level == 2:
		var chassis_shape = BoxShape3D.new()
		chassis_shape.size = Vector3(1.65, 0.8, 2.65)
		collision.shape = chassis_shape
		collision.position = Vector3(0, 1.05, 0)
		_vehicle_support = CollisionShape3D.new()
		_vehicle_support.shape = SphereShape3D.new()
		_vehicle_support.shape.radius = 0.35
		_vehicle_support.position.y = 0.35
		add_child(_vehicle_support)
	if vehicle.level != 1:
		global_position = vehicle.global_position + Vector3(0, 0.2, 0)
	vehicle.set_parked(false)
	vehicle.visual.reparent(self)
	vehicle.visual.position = Vector3.ZERO
	vehicle.visual.rotation = Vector3.ZERO
	vehicle.animate_entry(_vehicle_entry_side)
	_vehicle_third_person = false
	_update_vehicle_camera()
	if vehicle.level==3:
		_notify("Moto da cross · W/S gas e freno · A/D sterzo · Spazio salto · V visuale · E scendi.")
	else:
		_notify("W/S accelera e frena · A/D sterza · Spazio salta · 4 riponi." if vehicle.level == 1 else "W/S accelera e frena · A/D sterza · E scendi · V visuale · Spazio + sterzo: derapa.")
	return true

func _dismount_vehicle() -> void:
	if not is_instance_valid(_mounted_vehicle):
		return
	var vehicle = _mounted_vehicle
	var previous_view: Transform3D=camera.global_transform
	var exit_position: Vector3 = global_position
	if vehicle.level in [2,3]:
		if not is_on_floor():
			_notify("Attendi di toccare terra prima di scendere.")
			return
		var found: bool = false
		for offset in [Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,2.5), Vector3(0,0,-2.5)]:
			var candidate: Vector3 = global_position + Basis(Vector3.UP, _vehicle_heading) * offset
			var query = PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 1.5, candidate - Vector3.UP * 1.5, 1, [get_rid(), vehicle.body.get_rid()])
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.normal.y < 0.6:
				continue
			var space = PhysicsShapeQueryParameters3D.new()
			space.shape = _walking_shape
			space.transform = Transform3D(Basis.IDENTITY, hit.position + _walking_shape_position + Vector3.UP * 0.08)
			space.exclude = [get_rid(), vehicle.body.get_rid()]
			if get_world_3d().direct_space_state.intersect_shape(space).is_empty():
				exit_position = hit.position + Vector3.UP * 0.08
				found = true
				break
		if not found:
			_notify("Spazio di uscita occupato. Sposta il buggy.")
			return
	vehicle.global_position = global_position + Vector3.UP * vehicle.visual.position.y
	vehicle.rotation.y = _vehicle_heading
	var parked_chassis: Basis = vehicle.visual.basis
	vehicle.visual.reparent(vehicle)
	vehicle.visual.position = Vector3.ZERO
	vehicle.visual.basis = parked_chassis if vehicle.level == 2 else Basis.IDENTITY
	if is_instance_valid(_vehicle_support):
		_vehicle_support.queue_free()
		_vehicle_support = null
	if _walking_shape != null:
		collision.shape = _walking_shape
		collision.position = _walking_shape_position
	floor_snap_length = _walking_snap
	camera.cull_mask = _walking_camera_mask
	vehicle.set_parked(true)
	if vehicle.level==2: vehicle.animate_exit(exit_position)
	_mounted_vehicle = null
	if is_instance_valid(_local_avatar): _local_avatar.show()
	_vehicle_third_person = false
	_vehicle_speed = 0
	if vehicle.level != 1:
		velocity = Vector3.ZERO
	if vehicle.level == 1:
		vehicle.hide()
		vehicle.body.collision_layer = 0
		_notify("Monopattino riposto. Puoi raccogliere.")
	else:
		global_position = exit_position
	camera.position = Vector3(0, 1.6, 0)
	camera.basis = Basis.from_euler(Vector3(look_rotation.x, 0, 0))
	look_rotation.y = rotation.y
	_vehicle_entry_time=0.0
	if vehicle.level==2:
		_vehicle_exit_from=global_transform.affine_inverse()*previous_view
		_vehicle_exit_time=0.32
		camera.transform=_vehicle_exit_from

func _animate_vehicle_exit(delta: float) -> void:
	if _vehicle_exit_time<=0 or is_instance_valid(_mounted_vehicle): return
	_vehicle_exit_time=maxf(0.0,_vehicle_exit_time-delta)
	var progress: float=smoothstep(0,1,1.0-_vehicle_exit_time/0.32)
	var target=Basis.from_euler(Vector3(look_rotation.x,0,0))
	camera.transform=Transform3D(Basis(_vehicle_exit_from.basis.get_rotation_quaternion().slerp(target.get_rotation_quaternion(),progress)),_vehicle_exit_from.origin.lerp(Vector3(0,1.6,0),progress))

func _drive_vehicle(delta: float) -> void:
	_vehicle_entry_time=maxf(0.0,_vehicle_entry_time-delta)
	var previous_heading: float = _vehicle_heading
	_vehicle_motion.step(self, _mounted_vehicle, Input.get_axis("move_back", "move_forward"), Input.get_axis("move_left", "move_right"), (Input.is_action_pressed("jump") if _mounted_vehicle.level==2 else Input.is_action_just_pressed("jump")), delta)
	_vehicle_heading = _vehicle_motion.heading
	look_rotation.y += wrapf(_vehicle_heading-previous_heading,-PI,PI)
	_vehicle_speed = _vehicle_motion.speed
	_update_vehicle_camera()

func _panel_text(title: String, description: String) -> void:
	var art = preload("res://scripts/ui/menu_art.gd")
	art.details(_panel_box,description,title.capitalize())

func _panel_metrics(values: Array) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel_box.add_child(row)
	var art = preload("res://scripts/ui/menu_art.gd")
	for entry in values:
		var box = PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip = StyleBoxFlat.new()
		chip.bg_color = Color("#30382e")
		chip.set_corner_radius_all(10)
		chip.content_margin_left=14
		chip.content_margin_right=14
		chip.content_margin_top=12
		chip.content_margin_bottom=12
		box.add_theme_stylebox_override("panel",chip)
		row.add_child(box)
		var column = HBoxContainer.new()
		box.add_child(column)
		box.tooltip_text=entry[0]
		var symbol=TextureRect.new()
		symbol.texture=art.SYMBOLS.icon(art.SYMBOLS.item_key(entry[0]))
		symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.custom_minimum_size=Vector2(26,26)
		column.add_child(symbol)
		column.add_child(art.label(entry[1], 22, Color("#f2e1ba")))

func _near_service(kind: String = "") -> String:
	var nearest: String = ""
	var best: float = 3.0
	for terminal in get_tree().get_nodes_in_group("service_terminal"):
		var id: String = terminal.get_meta("service")
		if not kind.is_empty() and kind != id:
			continue
		var distance: float = global_position.distance_to(terminal.global_position)
		if distance <= best:
			var ray = PhysicsRayQueryParameters3D.create(camera.global_position, terminal.global_position + Vector3(0, 1.3, 0), 1, [get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				best = distance
				nearest = id
	return nearest

func _open_service(id: String) -> void:
	match id:
		"tools": _open_development()
		"vehicles": _open_vehicle_shop()
		"land": _open_land()
		"journal": _open_journal()

func _open_land() -> void:
	preload("res://scripts/ui/land_panel.gd").open(self)

func _open_cargo(material: String="") -> void:
	preload("res://scripts/ui/materials_panel.gd").open(self,material)

func _active_tool() -> int:
	return _equipped_tool if _game_state.owns_tool(_equipped_tool) else 0

func _equip_tool(level: int) -> void:
	if not _game_state.owns_tool(level):
		_notify("Acquista l'attrezzo al monitor della casa ufficio.")
		return
	if is_instance_valid(_mounted_vehicle) and _mounted_vehicle.level == 1:
		_dismount_vehicle()
	_cancel_collection()
	_equipped_tool = level
	if _is_paused:
		_close_pause_menu()
	_notify("Equipaggiato: " + _game_state.tool_defs[level].name)

func _choose_portable(kind: String) -> void:
	if is_instance_valid(_mounted_vehicle) and _mounted_vehicle.level!=1: return
	if not preload("res://scripts/economy/extra_mobility.gd").select_portable(kind): return
	if is_instance_valid(_mounted_vehicle) and _mounted_vehicle.vehicle_kind!=kind: _dismount_vehicle()
	_toggle_scooter(kind)

func _toggle_scooter(kind: String="") -> void:
	if kind.is_empty(): kind=str(_game_state.operations.get("mobility",{}).get("portable","scooter"))
	if kind not in ["scooter","skateboard"]: return
	if not _game_state.operations.held.is_empty():
		_notify("Deposita il componente prima di equipaggiare il monopattino.")
		return
	if (_game_state.vehicle_level<1 and kind=="scooter") or (kind=="skateboard" and not preload("res://scripts/economy/extra_mobility.gd").owned(kind)):
		_notify("Acquista prima il monopattino al garage.")
		return
	if _is_paused:
		_close_pause_menu()
	if is_instance_valid(_mounted_vehicle):
		if _mounted_vehicle.level == 1:
			_dismount_vehicle()
		else:
			_notify("Scendi dal mezzo prima di equipaggiare il portatile.")
		return
	var scooter: Node3D
	for vehicle in get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.level==1 and vehicle.vehicle_kind==kind:
			scooter = vehicle
	if scooter == null:
		return
	var ground = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position - Vector3.UP, 1, [get_rid(), scooter.body.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground)
	if hit.is_empty() or hit.normal.y < 0.75:
		_notify("Tocca terra prima di equipaggiare il monopattino.")
		return
	var clearance = PhysicsShapeQueryParameters3D.new()
	clearance.shape = BoxShape3D.new()
	clearance.shape.size = Vector3(0.65, 1.15, 1.45)
	clearance.transform = Transform3D(Basis(Vector3.UP, look_rotation.y), global_position + Vector3(0, 0.7, 0))
	clearance.exclude = [get_rid(), scooter.body.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(clearance).is_empty():
		_notify("Qui manca spazio per il monopattino: spostati un poco.")
		return
	scooter.global_position = global_position
	scooter.rotation.y = look_rotation.y
	scooter.show()
	scooter.set_parked(true)
	if _mount_vehicle(scooter):
		_notify("Mezzo portatile equipaggiato · 4 per riporlo · 1–3 per tornare agli attrezzi.")
	else:
		scooter.hide()
		scooter.body.collision_layer = 0

func _animate_equipment(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_action_clock += delta
	if _tool_visual_level != _active_tool():
		if is_instance_valid(_held_tool):
			_held_tool.queue_free()
		_held_tool = Node3D.new()
		camera.add_child(_held_tool)
		_tool_visual_level = _active_tool()
		var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.beveled_box(_held_tool, Vector3(0.10, 0.08, 0.13), Vector3(0.05, -0.04, 0.04), art.GRAPHITE)
		art.beveled_box(_held_tool, Vector3(0.09, 0.085, 0.20), Vector3(0.05, -0.05, 0.20), art.MINT.darkened(0.35))
		for finger in 4:
			art.beveled_box(_held_tool, Vector3(0.019, 0.035, 0.08), Vector3(0.015 + finger * 0.023, -0.02, -0.05), art.GRAPHITE.lightened(0.15))
		art.beveled_box(_held_tool, Vector3(0.035, 0.045, 0.07), Vector3(-0.012, -0.04, 0.025), art.YELLOW)
		if _tool_visual_level == 1:
			art.beveled_box(_held_tool, Vector3(0.065, 0.18, 0.065), Vector3(0.04, 0.08, -0.1), art.MINT)
			art.beveled_box(_held_tool, Vector3(0.025, 0.32, 0.025), Vector3(0.04, 0.32, -0.1), art.STEEL)
			art.beveled_box(_held_tool, Vector3(0.045, 0.025, 0.012), Vector3(0.04, 0.49, -0.1), art.STEEL)
		elif _tool_visual_level == 2:
			art.beveled_box(_held_tool, Vector3(0.055, 0.32, 0.065), Vector3(0.05, 0.13, -0.05), Color("#9a6b42"))
			art.beveled_box(_held_tool, Vector3(0.30, 0.12, 0.12), Vector3(0.05, 0.34, -0.05), art.STEEL)
			art.beveled_box(_held_tool, Vector3(0.055, 0.16, 0.05), Vector3(-0.09, 0.27, -0.05), art.STEEL).rotation.z = -0.4
		elif _tool_visual_level==3:
			art.beam(_held_tool,Vector3(0.04,-0.05,-0.1),Vector3(0.04,0.48,-0.1),0.045,art.RUST)
			art.beam(_held_tool,Vector3(0.04,0.48,-0.1),Vector3(0.04,0.54,-0.23),0.045,art.STEEL)
			art.beveled_box(_held_tool,Vector3(0.08,0.022,0.07),Vector3(0.04,0.54,-0.25),art.STEEL)
		elif _tool_visual_level==4:
			for side in [-1,1]:
				art.beam(_held_tool,Vector3(side*0.08,-0.03,0),Vector3(0,0.32,-0.07),0.04,art.MINT)
				art.beam(_held_tool,Vector3(0,0.32,-0.07),Vector3(side*0.05,0.45,-0.08),0.05,art.STEEL)
	_held_tool.visible = not _is_paused and not is_instance_valid(_mounted_vehicle) and _game_state.operations.held.is_empty()
	var swing: float = sin(_action_clock * 16) if _collecting else sin(_action_clock * 2) * 0.08
	_held_tool.position = Vector3(0.33, (-0.44 if _tool_visual_level == 0 and not _collecting else -0.36) + swing * 0.025, -0.65 - absf(swing) * 0.05)
	_held_tool.rotation = Vector3(swing * 0.2, 0.05, swing * 0.12)

func _collection_fx(target: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ghost = Node3D.new()
	get_tree().current_scene.add_child(ghost)
	ghost.add_to_group("collection_fx")
	ghost.global_position = target.global_position + Vector3.UP * 0.2
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	if target.is_in_group("scrap"):
		var copy: Node3D = target.mesh.duplicate()
		ghost.add_child(copy)
		copy.position = Vector3.ZERO
	else:
		for index in 4:
			art.box(ghost, Vector3.ONE * 0.1, Vector3(randf_range(-0.2, 0.2), randf() * 0.3, randf_range(-0.2, 0.2)), art.STEEL if index % 2 else art.YELLOW)
	var tween = ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "global_position", camera.global_position - camera.global_basis.z * 0.4, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "scale", Vector3.ONE * 0.05, 0.32)
	tween.chain().tween_callback(ghost.queue_free)
func _track_location(location: Vector3, label_text: String) -> void:
	_navigation_target = location
	_navigation_label = label_text
	_close_pause_menu()
	_notify("Itinerario selezionato: " + label_text + ". Segui l’indicatore sul navigatore.")

func _near_field_depot() -> Node3D:
	for node in get_tree().get_nodes_in_group("field_depot"):
		if global_position.distance_to(node.global_position) <= 3:
			return node
	return null

func _open_field_depot() -> void:
	if _near_field_depot() == null:
		return
	_close_pause_menu()
	_open_panel("SCARICO SATELLITE")
	_panel_metrics([["SACCA", "%.0f kg" % get_inventory_mass()], ["SCORTE", "%d Bulloni" % _game_state.get_deposit_value()], ["DESTINAZIONE", "Base"]])
	_panel_text("Scarico · nessuna vendita", "I materiali arrivano al deposito centrale. Vendi alla bilancia della base.")
	_add_panel_button("TRASFERISCI TUTTA LA SACCA", _deposit_field).disabled = get_inventory_mass() <= 0
	_add_panel_button("TORNA AL RECUPERO", _close_pause_menu)
	_pause_menu.popup_centered(Vector2i(780, 380))

func _deposit_field() -> void:
	if _near_field_depot() == null:
		return
	var snapshot: Dictionary = _game_state.serialize().duplicate(true)
	var inventory_before: Dictionary = get_inventory().duplicate()
	var value: int = InventoryService.deposit_all(owner_peer_id)
	if value > 0:
		if not _save_progress():
			_game_state.deserialize(snapshot)
			_game_state.player_inventories[owner_peer_id] = inventory_before
		else:
			_notify("Materiali al deposito centrale. Vendili alla bilancia quando rientri.")
	_open_field_depot()

func _near_secret() -> Node3D:
	for secret in get_tree().get_nodes_in_group("world_secrets"):
		if global_position.distance_to(secret.global_position) > 3:
			continue
		var ray = PhysicsRayQueryParameters3D.create(camera.global_position, secret.global_position + Vector3.UP * 0.8, 1, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider == secret:
			return secret
	return null

func _discover_nearest() -> void:
	var secret = _near_secret()
	if secret == null:
		return
	if secret.secret_id not in _game_state.secrets_found and not secret.discover():
		_notify("Impossibile salvare la scoperta: riprova prima di allontanarti.")
		return
	_open_journal()

func _open_journal(selected: int=-1) -> void:
	preload("res://scripts/ui/curiosities_panel.gd").open(self,selected)

func _region_name() -> String:
	if global_position.distance_to(preload("res://scripts/gameplay/leisure_sites.gd").PARK)<90: return "DUNE PARK"
	if global_position.distance_to(preload("res://scripts/gameplay/leisure_sites.gd").OASIS)<50: return "OASI DEL RITORNO"
	for site in _game_state.logistics_def.get("outposts",[]):
		if Vector2(global_position.x-site.position[0],global_position.z-site.position[2]).length()<25:
			return site.name.to_upper()
	if absf(position.x) < 33 and position.z > 7 and position.z < 40:
		return "BASE / SERVIZI"
	for lot in get_tree().get_nodes_in_group("unlocked_lots"):
		var relative: Vector3 = global_position - lot.global_position
		if absf(relative.x) <= 40 and absf(relative.z) <= 40:
			return "LOTTO EST" if lot.get_meta("level") == 1 else "LOTTO DELLE DUNE"
	return "DISCARICA" if maxf(absf(position.x), absf(position.z)) < 80 else "DUNE ESTERNE"
func _collection_requirement() -> String:
	if not _game_state.operations.held.is_empty():
		return "MANI OCCUPATE\nCarica o deposita il componente."
	if is_instance_valid(_target_scrap) and _target_scrap.is_in_group("salvage_assemblies"):
		return _target_scrap.requirement(owner_peer_id,_active_tool())
	if not is_instance_valid(_target_scrap):
		return ""
	if _target_scrap.has_method("can_start_collection") and not _target_scrap.can_start_collection():
		return ""
	var allowed: Array = []
	var required_mass: float = 0
	var step: Dictionary = {}
	if _target_scrap.has_method("commit_stage"):
		step = _target_scrap.get_step() if _target_scrap.has_method("get_step") else _game_state.salvage_defs.pile.steps[0]
		if step.is_empty():
			return ""
		allowed = [int(step.get("tool", 0))]
		for id in step["yield"]:
			required_mass += float(_game_state.material_defs[id].mass_kg) * int(step["yield"][id])
	else:
		var id: String = _scrap_type_to_material_id(_target_scrap.scrap_type)
		allowed = _game_state.material_defs[id].get("tools", [0]).map(func(value): return int(value))
		required_mass = float(_game_state.material_defs[id].mass_kg)
	if _active_tool() not in allowed:
		var descriptions: PackedStringArray = []
		for tool in allowed:
			descriptions.append("%s [%d]" % [_game_state.tool_defs[int(tool)].name, int(_game_state.tool_defs[int(tool)].key)])
		return "STRUMENTO NECESSARIO\n" + " / ".join(descriptions)
	if int(step.get("land", 0)) > _game_state.yard_level:
		return "PROGETTO NECESSARIO\nApri il Lotto Est alla planimetria."
	if get_inventory_mass() + required_mass > _game_state.get_inventory_capacity(owner_peer_id):
		return "SACCA PIENA\nServono %.0f kg liberi per questo recupero." % required_mass
	return ""

func _land_project_text(land: Dictionary) -> String:
	var lines: PackedStringArray = ["24 rottami · 3 cumuli · scarico satellite", "BANCO RECUPERO · riparazioni e riciclo" if int(land.level) == 1 else "SPEDIZIONI · forniture e tramoggia", "Attrezzo: " + _game_state.tool_defs[int(land.get("requires_tool", 0))].name]
	for id in land.get("project_materials", {}):
		lines.append("%s nel deposito: %d / %d" % [id.capitalize(), _game_state.team_deposit_counts.get(id, 0), land.project_materials[id]])
	return "\n".join(lines)

func _complete_work_order(id: String) -> void:
	if not _near_garage():
		return
	if not _game_state.complete_order(id):
		_notify("Consegna non riuscita: controlla materiali e salvataggio.")
	_open_development()
	if is_instance_valid(_upgrade_monitor):
		_upgrade_monitor.active_page = "orders"
		_upgrade_monitor.build_screen()
func _buy_module(id: String) -> void:
	if _near_service("tools") != "tools":
		return
	if not _game_state.purchase_module(id):
		_notify(_game_state.module_requirement(id))
	_open_development()
func _near_bulk_part() -> Node3D:
	var nearest: Node3D
	var best: float = 3.0
	for item in get_tree().get_nodes_in_group("bulk_parts"):
		var distance: float = global_position.distance_to(item.global_position)
		if distance < best:
			var query = PhysicsRayQueryParameters3D.create(camera.global_position,item.global_position+Vector3.UP*0.35,1,[get_rid()])
			var hit = get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.collider == item:
				nearest = item
				best = distance
	return nearest

func _near_cargo_bay() -> Node3D:
	for vehicle in get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.level != 2 or not vehicle.parked:
			continue
		var local: Vector3 = vehicle.to_local(global_position)
		var rear: Vector3 = vehicle.to_global(Vector3(0,0,1.8))
		if local.z > 0.85 and global_position.distance_to(rear) <= 3.0 and _aims_at(vehicle.to_global(Vector3(0,1.2,1.6)),0.72,[vehicle.body.get_rid()]):
			var query = PhysicsRayQueryParameters3D.create(camera.global_position,rear+Vector3.UP*0.7,1,[get_rid(),vehicle.body.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				return vehicle
	return null

func _ops_service_node() -> Node3D:
	for station in get_tree().get_nodes_in_group("operations_service"):
		if global_position.distance_to(station.global_position) <= 3.0:
			if str(station.get_meta("operation")) in ["craft","customer","career"] and not _aims_at(station.global_position+Vector3.UP*1.2,0.75,[station.get_rid()] if station is CollisionObject3D else []):
				continue
			var ignored: Array[RID] = [get_rid()]
			if station is CollisionObject3D:
				ignored.append(station.get_rid())
			var query = PhysicsRayQueryParameters3D.create(camera.global_position,station.global_position+Vector3.UP*1.3,1,ignored)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				return station
	return null

func _near_ops_service() -> String:
	var station = _ops_service_node()
	return str(station.get_meta("operation")) if station != null else ""

func _at_parts_storage() -> bool:
	return _near_depot() or _near_field_depot() != null or _near_ops_service() in ["recovery","warehouse"]

func _buggy_at_storage() -> bool:
	if not _at_parts_storage():
		return false
	for vehicle in get_tree().get_nodes_in_group("yard_vehicles"):
		if vehicle.level == 2 and vehicle.parked and global_position.distance_to(vehicle.global_position) < 6:
			return true
	return false

func _interact_carried() -> void:
	if _near_cargo_bay() != null:
		if not _game_state.ops.load_held():
			_notify("Cassone pieno: scarica o amplia la capacità.")
		else:
			_notify("Componente caricato nel buggy · %.0f / %d kg." % [_game_state.ops.cargo_mass(),_game_state.ops.cargo_capacity()])
	elif _at_parts_storage():
		if _game_state.ops.store_held():
			_notify("Componente depositato nel magazzino.")
	else:
		var desired: Vector3 = global_position-global_basis.z*1.4
		var query = PhysicsRayQueryParameters3D.create(desired+Vector3.UP*2,desired-Vector3.UP*4,1,[get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.65:
			_notify("Cerca un punto libero e stabile per appoggiare il componente.")
			return
		var space = PhysicsShapeQueryParameters3D.new()
		space.shape = BoxShape3D.new()
		space.shape.size = Vector3(1.1,0.75,1.1)
		space.transform = Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*0.42)
		space.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(space).is_empty():
			_notify("Spazio occupato: spostati prima di appoggiare il componente.")
			return
		_game_state.ops.drop_part(hit.position+Vector3.UP*0.02)

func _sync_carried_visual() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var id: String = str(_game_state.operations.held.get("id",""))
	if id != _carried_visual_id:
		if is_instance_valid(_carried_visual):
			_carried_visual.queue_free()
		_carried_visual = null
		_carried_visual_id = id
		if not id.is_empty():
			_carried_visual = Node3D.new()
			camera.add_child(_carried_visual)
			preload("res://scripts/gameplay/haul_part.gd").build_model(_carried_visual,_game_state.operations.held.kind,int(_game_state.operations.held.quality))
			_carried_visual.position = Vector3(0,-0.65,-1.0)
			_carried_visual.scale = Vector3.ONE*0.6
	if is_instance_valid(_carried_visual):
		_carried_visual.visible = not _is_paused

func _open_buggy_cargo() -> void:
	preload("res://scripts/ui/yard_panels.gd").cargo(self)

func _open_parts_storage() -> void:
	preload("res://scripts/ui/yard_panels.gd").parts(self,false)

func _open_production_queue() -> void:
	preload("res://scripts/ui/yard_panels.gd").production(self)

func _open_ops_service(station: Node3D = null) -> void:
	if station==null:
		station = _ops_service_node()
	if station==null:
		return
	var operation: String = str(station.get_meta("operation"))
	if operation == "career":
		_open_career()
	elif operation=="identity":
		_open_personalization()
	elif operation == "fabrication":
		_open_fabrication_queue()
	elif operation == "craft":
		_open_crafting()
	elif operation == "recovery":
		preload("res://scripts/ui/yard_panels.gd").parts(self,true)
	elif operation == "customer":
		preload("res://scripts/ui/customer_panel.gd").open(self,str(station.get_meta("customer")))
	elif operation == "dispatch":
		_open_supply_jobs()
	elif operation == "warehouse":
		_open_parts_storage()

func _open_supply_jobs() -> void:
	preload("res://scripts/ui/yard_panels.gd").deliveries(self)

func _open_personalization() -> void:
	preload("res://scripts/ui/personalization_panel.gd").open(self)

func _ops_action(action: String, id: String = "", count: int = 0) -> void:
	var success: bool = false
	match action:
		"route_parts":
			if _near_garage() or _near_ops_service() == "dispatch":
				var definition: Dictionary = _game_state.ops.delivery_definition()
				var best: float = INF
				for node in get_tree().get_nodes_in_group("bulk_parts"):
					if definition.get("parts",{}).has(node.kind) and global_position.distance_to(node.global_position) < best:
						_navigation_target = node.global_position
						_navigation_label = _game_state.part_defs[node.kind].name
						best = global_position.distance_to(node.global_position)
				if is_finite(best):
					_close_pause_menu()
					_notify("Recupero indicato sul navigatore.")
				else:
					_notify("Recupera i componenti smontando auto e macchinari.")
			return
		"cancel_delivery":
			if _near_garage() or _near_ops_service() == "dispatch":
				success = _game_state.ops.cancel_delivery()
		"route_products":
			if _near_garage() or _near_ops_service()=="dispatch":
				_route_career_map("craft")
			return
		"store_bag":
			if _near_ops_service() == "warehouse":
				success = _game_state.ops.store_bag(owner_peer_id)
		"load_bag":
			if _near_cargo_bay() != null:
				success = _game_state.ops.transfer_bag_to_cargo(owner_peer_id)
		"unload":
			if _buggy_at_storage():
				success = _game_state.ops.unload_cargo()
		"sell":
			if _near_depot():
				success = _game_state.ops.sell_part(id)
		"repair":
			if _near_ops_service() == "recovery":
				success = _game_state.ops.repair_part(id)
		"recycle":
			if _near_ops_service() == "recovery":
				success = _game_state.ops.recycle_part(id)
		"take":
			if _at_parts_storage():
				success = _game_state.ops.take_stored(id)
		"queue":
			if _near_press():
				success = _game_state.ops.enqueue_press(count)
		"cancel_queue":
			if _near_press():
				success = _game_state.ops.cancel_press_queue()
		"autofeed":
			if _near_press() or _near_ops_service() == "dispatch":
				success = _game_state.ops.set_autofeed(not bool(_game_state.operations.autofeed))
		"accept_delivery":
			if _near_garage() or _near_ops_service() == "dispatch":
				success = _game_state.ops.accept_delivery(id)
		"complete_delivery":
			if _near_garage() or _near_ops_service() == "dispatch":
				success = _game_state.ops.complete_delivery(count)
	if success:
		_notify("Operazione completata e salvata.")
		_close_pause_menu()
	else:
		_notify("Operazione non disponibile: controlla spazio, posizione e requisiti.")

# Loose bulky parts can be pulled along the ground; inventory stays untouched.
func _process_drag(delta: float) -> void:
	if _ignore_drag_until_release:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): return
		_ignore_drag_until_release=false
	if is_instance_valid(_placement): return
	if _is_paused or _vehicle_exit_time>0 or is_instance_valid(_mounted_vehicle):
		if is_instance_valid(_dragged):
			_finish_drag()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if is_instance_valid(_dragged):
			_finish_drag()
		return
	if not is_instance_valid(_dragged):
		if not _game_state.operations.held.is_empty():
			return
		var pick = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*3,1,[get_rid()])
		pick.collide_with_areas = true
		var hit = get_world_3d().direct_space_state.intersect_ray(pick)
		if not hit.is_empty() and hit.collider.has_meta("assembly"):
			hit.collider = hit.collider.get_meta("assembly")
		var reach: float=3.0
		if not hit.is_empty(): reach=minf(3.0,camera.global_position.distance_to(hit.position)+(0.12 if hit.collider.is_in_group("landfill_piles") or hit.collider.is_in_group("landfill_scenery") else -0.02))
		var fragment: Dictionary=preload("res://scripts/gameplay/heap_fragments.gd").pick(self,camera.global_position,camera.global_position-camera.global_basis.z*reach)
		if not fragment.is_empty(): hit={"collider":fragment.source.promote(fragment.index)}
		if hit.is_empty() or not (hit.collider.is_in_group("bulk_parts") or hit.collider.is_in_group("scrap") or hit.collider.is_in_group("salvage_assemblies") or hit.collider.is_in_group("heap_fragments")):
			return
		_dragged = hit.collider
		_drag_origin = _dragged.global_position
		_drag_original_yaw = _dragged.rotation.y
		_drag_velocity = Vector3.ZERO
		_cancel_collection()
	if camera.global_position.distance_to(_dragged.global_position)>3.8:
		_finish_drag()
		return
	var target: Vector3 = camera.global_position-camera.global_basis.z*1.8
	var ground = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(target.x,global_position.y+1,target.z),Vector3(target.x,global_position.y-1.5,target.z),1,[get_rid(),_dragged.get_rid()]))
	if ground.is_empty() or ground.normal.y < 0.65:
		return
	var speed_limit: float = float(_game_state.logistics_def.get("drag_speed_mps",1.8))*_game_state.module_effect("harness")*_drag_mobility()
	var offset: float=_dragged.get_drag_ground_offset() if _dragged.has_method("get_drag_ground_offset") else (0.08 if _dragged.is_in_group("scrap") else 0.015)
	var difference: Vector3 = ground.position+Vector3.UP*offset-_dragged.global_position
	var desired: Vector3 = difference.normalized()*minf(speed_limit,difference.length()*4)
	var acceleration: float = float(_game_state.logistics_def.drag_acceleration)*_drag_mobility()
	_drag_velocity = _drag_velocity.move_toward(desired,acceleration*delta)
	var proposed: Vector3 = _dragged.global_position+_drag_velocity*delta
	var fraction: float = 1.0
	var displacement: Vector3 = proposed-_dragged.global_position
	for child in _dragged.get_children():
		if child is CollisionShape3D and not child.disabled:
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			query.transform = child.global_transform
			query.motion = displacement
			query.exclude = [get_rid(),_dragged.get_rid()]
			var safe = get_world_3d().direct_space_state.cast_motion(query)
			fraction = minf(fraction,safe[0])
	_dragged.global_position += displacement*fraction
	if fraction<0.99:
		_drag_velocity = Vector3.ZERO
	_rotate_dragged(delta)
	_draw_drag_tether()

func _finish_drag() -> void:
	var before: Dictionary = _game_state.operations.duplicate(true)
	var point: Vector3 = _dragged.global_position
	var id: String = str(_dragged.entity_id) if not _dragged.is_in_group("bulk_parts") else str(_dragged.part_id)
	if not _game_state.operations.has("loose_rotations"):
		_game_state.operations.loose_rotations = {}
	_game_state.operations.loose_rotations[id] = wrapf(_dragged.rotation.y,-PI,PI)
	if _dragged.is_in_group("bulk_parts"):
		_game_state.operations.field[id].position = [point.x,point.y,point.z]
		_game_state.operations.field[id].dropped = true
	else:
		if not _game_state.operations.has("loose_positions"):
			_game_state.operations.loose_positions = {}
		_game_state.operations.loose_positions[id] = [point.x,point.y,point.z]
	if not SaveService.save_checkpoint():
		_game_state.operations = before
		_dragged.global_position = _drag_origin
		_dragged.rotation.y = _drag_original_yaw
		_notify("Spostamento annullato: salvataggio non riuscito.")
	_dragged = null
	_drag_velocity = Vector3.ZERO
	if is_instance_valid(_drag_tether):
		_drag_tether.hide()

func _drag_mass() -> float:
	if not is_instance_valid(_dragged):
		return 0
	if _dragged.is_in_group("heap_fragments"): return _dragged.fragment_mass
	if _dragged.is_in_group("bulk_parts"):
		return float(_game_state.part_defs[_dragged.kind].mass_kg)
	if _dragged.is_in_group("salvage_assemblies"):
		return float(_game_state.logistics_def.drag_assembly_mass_kg.get(_dragged.definition_id,100))
	return float(_game_state.material_defs[_scrap_type_to_material_id(_dragged.scrap_type)].mass_kg)

func _drag_mobility() -> float:
	var material: String = "metal"
	if is_instance_valid(_dragged) and _dragged.is_in_group("scrap"):
		material = _scrap_type_to_material_id(_dragged.scrap_type)
	elif is_instance_valid(_dragged) and _dragged.is_in_group("bulk_parts"):
		material = "rubber" if _dragged.kind=="wheel" else ("electronics" if _dragged.kind=="battery" else "metal")
	var friction: float = float(_game_state.logistics_def.drag_material_friction.get(material,1.0))
	return 1.0/(friction*sqrt(1+_drag_mass()/float(_game_state.logistics_def.drag_mass_scale_kg)))

func _rotate_dragged(delta: float) -> void:
	if _drag_velocity.length()<0.05:
		return
	var old_yaw: float = _dragged.rotation.y
	var desired: float = atan2(-_drag_velocity.x,-_drag_velocity.z)
	_dragged.rotation.y = rotate_toward(old_yaw,desired,delta*1.8*_drag_mobility())
	for child in _dragged.get_children():
		if child is CollisionShape3D and not child.disabled:
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			query.exclude = [get_rid(),_dragged.get_rid()]
			query.transform = child.global_transform
			var new_hits: Array = get_world_3d().direct_space_state.intersect_shape(query)
			_dragged.rotation.y = old_yaw
			query.transform = child.global_transform
			var old_hits: Array = get_world_3d().direct_space_state.intersect_shape(query)
			var previous_rids: Array = old_hits.map(func(hit):return hit.rid.get_id())
			for hit in new_hits:
				if hit.rid.get_id() not in previous_rids:
					return
			_dragged.rotation.y = rotate_toward(old_yaw,desired,delta*1.8*_drag_mobility())

func _draw_drag_tether() -> void:
	if DisplayServer.get_name()=="headless":
		return
	if not is_instance_valid(_drag_tether):
		_drag_tether = MeshInstance3D.new()
		_drag_tether.mesh = ImmediateMesh.new()
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#edbc60")
		_drag_tether.material_override = material
		get_tree().current_scene.add_child(_drag_tether)
	_drag_tether.show()
	var mesh: ImmediateMesh = _drag_tether.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(camera.to_global(Vector3(0.22,-0.28,-0.4)))
	mesh.surface_add_vertex(_dragged.global_position+Vector3.UP*0.3)
	mesh.surface_end()

func _open_scrap_book(family: int = 0) -> void:
	_close_pause_menu()
	_open_panel("LIBRO DEI RECUPERI")
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	var album: Array = _game_state.operations.get("scrap_album",[])
	var art = preload("res://scripts/ui/menu_art.gd")
	_panel_metrics([["SCOPERTE","%d / 35" % album.size()],["FAMIGLIA","%d / 5" % album.filter(func(key):return key.begins_with(str(family)+"_")).size()]])
	var families = ["METALLI","PLASTICHE","ELETTRONICA","RAME","ALLUMINIO","VETRO","GOMMA"]
	var tabs=HBoxContainer.new()
	_panel_box.add_child(tabs)
	for type in 7:
		var tab=Button.new()
		tab.text=families[type].capitalize()
		tab.pressed.connect(_open_scrap_book.bind(type))
		art.button_style(tab,type==family)
		tab.add_theme_font_size_override("font_size",14)
		tabs.add_child(tab)
	var grid=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	_panel_box.add_child(grid)
	for variant in 5:
		var found: bool = "%d_%d" % [family,variant] in album
		var tile=PanelContainer.new()
		tile.custom_minimum_size=Vector2(370,76)
		var tile_style=StyleBoxFlat.new()
		tile_style.bg_color=Color("#20343d")
		tile_style.border_color=Color("#84d7bd") if found else Color("#344d58")
		tile_style.set_border_width_all(1)
		tile_style.set_corner_radius_all(10)
		tile_style.content_margin_left=14
		tile_style.content_margin_right=14
		tile_style.content_margin_top=10
		tile_style.content_margin_bottom=10
		tile.add_theme_stylebox_override("panel",tile_style)
		grid.add_child(tile)
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		tile.add_child(row)
		var symbol=TextureRect.new()
		symbol.texture=art.SYMBOLS.icon("check" if found else "box")
		symbol.custom_minimum_size=Vector2(28,28)
		symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.modulate=Color("#84d7bd") if found else Color("#71838b")
		row.add_child(symbol)
		var name_label=art.label(catalog.item_name(family,variant)+("  ★" if variant==4 else ""),17,Color("#dae5e7") if found else Color("#81969e"))
		name_label.custom_minimum_size.x=300
		name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
	var footer = HBoxContainer.new()
	_panel_box.add_child(footer)
	var scan = _add_panel_button("SCANNER · COLLEZIONE",_scan_scrap.bind(true))
	scan.reparent(footer)
	scan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan.disabled = int(_game_state.workshop_modules.get("scanner",0))==0
	var close = _add_panel_button("TORNA AL LAVORO",_close_pause_menu)
	close.reparent(footer)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_menu.popup_centered(Vector2i(880,650))
	call_deferred("_center_popup_if_open",_pause_menu,Vector2i(880,650))

var _work_light: SpotLight3D
var _work_light_enabled: bool = true

func _update_work_light() -> void:
	var level: int = int(_game_state.workshop_modules.get("headlamp",0))
	if level == 0 or not is_local_player:
		if is_instance_valid(_work_light):
			_work_light.hide()
		return
	if not is_instance_valid(_work_light):
		_work_light = SpotLight3D.new()
		camera.add_child(_work_light)
		_work_light.position = Vector3(0.12,-0.12,-0.15)
		_work_light.light_color = Color("#ffe6ba")
		_work_light.light_energy = 3.0
		_work_light.shadow_enabled = false
	_work_light.spot_range = _game_state.module_effect("headlamp")
	_work_light.spot_angle = 34 if level == 1 else 48
	_work_light.visible = _work_light_enabled

func _toggle_work_light() -> void:
	if is_instance_valid(_mounted_vehicle) and _mounted_vehicle.level in [2,3]:
		_mounted_vehicle.toggle_headlights()
		_close_pause_menu()
		_notify("Fari accesi." if _mounted_vehicle.headlights_enabled else "Fari spenti.")
		return
	if int(_game_state.workshop_modules.get("headlamp",0))==0:
		_notify("Installa la lampada al monitor → Officina.")
		return
	_work_light_enabled = not _work_light_enabled
	_update_work_light()
	_close_pause_menu()
	_notify("Lampada accesa." if _work_light_enabled else "Lampada spenta.")

func _scan_scrap(collection_only: bool = false) -> void:
	_career_tracking = false
	if int(_game_state.workshop_modules.get("scanner",0))==0:
		_notify("Installa lo scanner al monitor → Officina.")
		return
	var range_m: float = _game_state.module_effect("scanner") * (1.25 if _game_state.story.has_project("archive") else 1.0)
	if not collection_only and _scan_specific_request(range_m):
		return
	if not collection_only and _scan_delivery_parts(range_m):
		return
	var album: Array = _game_state.operations.get("scrap_album",[])
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	var nearest: Node3D
	var best: float = range_m
	for item in get_tree().get_nodes_in_group("scrap"):
		var key: String = "%d_%d" % [item.scrap_type,catalog.variant_for(item.entity_id)]
		var distance: float = global_position.distance_to(item.global_position)
		if key not in album and not item.is_queued_for_deletion() and distance<=best:
			best = distance
			nearest = item
	_close_pause_menu()
	if nearest == null:
		if _navigation_label.begins_with("SCANNER"):
			_navigation_label = ""
		_notify("Nessuna nuova voce del libro entro %d m. Esplora un'altra zona." % range_m)
		return
	_navigation_target = nearest.global_position
	_navigation_label = "SCANNER · "+nearest.display_name()
	_notify("Segnale trovato: %s · %.0f m." % [nearest.display_name(),best])

func _gameplay_key(event: InputEvent) -> bool:
	for action in ["move_forward","move_back","move_left","move_right","jump","sprint","interact","recovery_mode"]:
		if event.is_action(action):
			return true
	return false

func _shortcut_free(key: int) -> bool:
	var event = InputEventKey.new()
	event.keycode=key
	return not _gameplay_key(event)

func _scan_delivery_parts(range_m: float) -> bool:
	var job: Dictionary = _game_state.ops.delivery_definition()
	if job.is_empty():
		return false
	var missing: Array[String] = []
	var pending: Array = _game_state.operations.stored_parts.duplicate()
	pending.append_array(_game_state.operations.cargo_parts)
	if not _game_state.operations.held.is_empty():
		pending.append(_game_state.operations.held)
	for kind in job.parts:
		var count: int = 0
		for part in pending:
			if part.kind==kind:
				count += 1
		if count<int(job.parts[kind]):
			missing.append(kind)
	if missing.is_empty():
		return false
	var nearest: Node3D
	var best: float = range_m
	for part in get_tree().get_nodes_in_group("bulk_parts"):
		var distance: float = global_position.distance_to(part.global_position)
		if part.kind in missing and not part.is_queued_for_deletion() and distance<=best:
			nearest = part
			best = distance
	_close_pause_menu()
	if nearest == null:
		if _navigation_label.begins_with("SCANNER"):
			_navigation_label = ""
		_notify("Fornitura: componenti mancanti fuori portata (%d m). Maiusc+F cerca il libro." % range_m)
		return true
	_navigation_target = nearest.global_position
	_navigation_label = "SCANNER · FORNITURA · "+_game_state.part_defs[nearest.kind].name
	_notify("Fornitura: %s · %.0f m%s" % [_game_state.part_defs[nearest.kind].name,best," · da riparare al Lotto Est" if nearest.quality==0 else ""])
	return true

func _toggle_parking_brake() -> void:
	if not is_instance_valid(_mounted_vehicle) or _mounted_vehicle.level not in [2,3]:
		_notify("Usa il parcheggio alla guida di un mezzo a motore.")
		return
	_vehicle_motion.parking_brake = not _vehicle_motion.parking_brake
	_close_pause_menu()
	_notify("Freno di stazionamento inserito." if _vehicle_motion.parking_brake else "Freno di stazionamento rilasciato.")

func _specific_action(action: String, id: String) -> void:
	if not _near_garage():
		_notify("Raggiungi il monitor dell'ufficio per gestire le richieste.")
		return
	var success: bool = false
	match action:
		"accept": success = _game_state.specifics.accept(id)
		"deliver": success = _game_state.specifics.deliver(id.to_int())
		"cancel": success = _game_state.specifics.cancel()
	if success:
		_close_pause_menu()
		_notify("Richiesta aggiornata e salvata. Scanner F per cercare i pezzi.")
	else:
		_close_pause_menu()
		_notify("Controlla requisiti, deposito e salvataggio.")

func _scan_specific_request(range_m: float) -> bool:
	if _game_state.specifics.payload().is_empty():
		return false
	var job: Dictionary = _game_state.specifics.definition()
	var catalog = preload("res://scripts/gameplay/scrap_catalog.gd")
	var missing: bool = false
	for key in job.items:
		missing = missing or _game_state.specifics.needs(key)
	if not missing:
		var destination: Node3D = get_tree().get_first_node_in_group("upgrade_monitor") if _game_state.specifics.ready() else get_tree().get_first_node_in_group("sector").get_node("DepositZone")
		_close_pause_menu()
		_navigation_target = destination.global_position
		_navigation_label = "SCANNER · RICHIESTA · "+("CONSEGNA AL MONITOR" if _game_state.specifics.ready() else "DEPOSITA ALLA BILANCIA")
		_notify("Tutti i pezzi recuperati: "+("consegna al monitor." if _game_state.specifics.ready() else "deposita sacca e cassone."))
		return true
	var best: float = range_m
	var nearest: Node3D
	for item in get_tree().get_nodes_in_group("scrap"):
		var key: String = "%d_%d" % [item.scrap_type,catalog.variant_for(item.entity_id)]
		var distance: float = global_position.distance_to(item.global_position)
		if _game_state.specifics.needs(key) and not item.is_queued_for_deletion() and distance<=best:
			nearest = item
			best = distance
	_close_pause_menu()
	if nearest==null:
		if _navigation_label.begins_with("SCANNER"):
			_navigation_label = ""
		_notify("Nessun pezzo della richiesta entro %dm. Esplora o usa Maiusc+F per il libro." % range_m)
	else:
		_navigation_target = nearest.global_position
		_navigation_label = "SCANNER · RICHIESTA · "+nearest.display_name()
		_notify("Pezzo richiesto trovato: "+nearest.display_name())
	return true

func _near_crafted() -> Node3D:
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*3.0,1,[get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider.is_in_group("crafted_objects") else null

func _open_crafting(selection: String = "handcart") -> void:
	if _near_ops_service()!="craft":
		return
	preload("res://scripts/ui/crafting_panel.gd").open(self,true,selection)

func _open_crafted_gear() -> void:
	preload("res://scripts/ui/crafting_panel.gd").open(self,false)

var _placement: Node3D
var _ignore_drag_until_release: bool=false
var _ignore_collect_until_release: bool=false

func _craft_ground(kind: String, facing: float=INF) -> Dictionary:
	if not is_finite(facing): facing=rotation.y
	var ray = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*3,1,[get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		var forward=Vector3(-sin(look_rotation.y),0,-cos(look_rotation.y))
		var ahead: Vector3=global_position+forward*2.3
		hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*1.8,ahead-Vector3.UP*2.5,1,[get_rid()]))
	if hit.is_empty() or hit.normal.y<0.9:
		return {}
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.35,0.85,1.45) if kind=="handcart" else Vector3(0.8,2.1,0.8)
	if kind=="field_depot":
		shape.size=Vector3(1.6,1.3,1.6)
	if kind in preload("res://scripts/gameplay/yard_structures.gd").KINDS:
		shape.size=preload("res://scripts/gameplay/yard_structures.gd").footprint(kind)+Vector3(0.08,0,0.08)
	query.shape = shape
	var up: Vector3=hit.normal.normalized()
	var basis=Basis.looking_at(Vector3(-sin(facing),0,-cos(facing)).slide(up).normalized(),up)
	query.transform = Transform3D(basis,hit.position+up*(shape.size.y/2+0.08))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return {}
	# The fallback ground probe must not place through a nearby wall.
	var access=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,hit.position+up*0.15,1,[get_rid()]))
	if not access.is_empty() and access.position.distance_to(hit.position)>0.25: return {}
	return {"point":hit.position+up*0.04,"yaw":facing,"up":up}

func _craft_object(id: String) -> Node3D:
	for object in get_tree().get_nodes_in_group("crafted_objects"):
		if object.craft_id==id:
			return object
	return null

func _craft_action(action: String, id: String, ticket: int) -> void:
	var service = _game_state.crafting
	var success: bool = false
	if action in ["craft","repair","install"]:
		if _near_ops_service()!="craft":
			return
		success = service.install(id,ticket) if action=="install" else (service.craft(id,ticket) if action=="craft" else service.repair(id))
		if success:
			_play_feedback("craft")
			_open_crafting(id if action in ["craft","install"] else "repair_kit")
			return
			preload("res://scripts/ui/crafting_panel.gd").open(self,true,id if action=="craft" else "repair_kit")
			return
	elif action=="deploy":
		if is_instance_valid(_mounted_vehicle) or not _game_state.operations.held.is_empty():
			_close_pause_menu()
			_notify("Scendi dal mezzo e libera le mani prima di posizionare.")
			return
		_close_pause_menu()
		if id not in service.DEPLOYABLES or int(service.data().stock.get(id,0))<=0: return
		_placement=preload("res://scripts/gameplay/placement_mode.gd").new()
		_placement.player=self
		_placement.kind=id
		_placement.yaw=look_rotation.y
		add_child(_placement)
		return
	elif action=="locate":
		if service.data().objects.has(id):
			var pos: Array = service.data().objects[id].position
			_navigation_target = Vector3(pos[0],pos[1],pos[2])
			_navigation_label = "ATTREZZATURA · "+service.definitions()[service.data().objects[id].kind].name
			_close_pause_menu()
			return
	else:
		var object = _craft_object(id)
		if object==null or global_position.distance_to(object.global_position)>3.5:
			_close_pause_menu()
			return
		# The opened object menu keeps its identity; a settling camera should not
		# invalidate its buttons. Distance and obstruction are still checked.
		var access = PhysicsRayQueryParameters3D.create(camera.global_position,object.global_position+Vector3.UP*0.5,1,[get_rid(),object.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(access).is_empty():
			_close_pause_menu()
			return
		match action:
			"pack": success = service.pack(id)
			"load": success = service.load_cart(id)
			"unload":
				if _at_parts_storage():
					success = service.unload_cart(id)
			"tow":
				if object.kind=="handcart" and not is_instance_valid(_mounted_vehicle) and _game_state.operations.held.is_empty():
					_close_pause_menu()
					_towed_cart = object
					object.towing = self
					object.add_collision_exception_with(self)
					success = true
	_close_pause_menu()
	_notify(("Materiali riservati. Assemblaggio in corso nel garage." if action=="craft" and float(service.definitions()[id].get("seconds",0))>0 else "Operazione completata.") if success else "Operazione non riuscita: controlla scorte, spazio o salvataggio.")

func _stop_cart() -> void:
	if not is_instance_valid(_towed_cart):
		return
	var object = _towed_cart
	_towed_cart = null
	object.towing = null
	object.remove_collision_exception_with(self)
	if not _game_state.crafting.move_object(object.craft_id,object.global_position,object.rotation.y):
		get_tree().get_first_node_in_group("crafting_world").refresh()
		_notify("Salvataggio non riuscito: carrello riportato all'ultima posizione.")

func _toggle_vehicle_view() -> void:
	if not is_instance_valid(_mounted_vehicle) or _mounted_vehicle.level not in [2,3]:
		return
	_vehicle_third_person = not _vehicle_third_person
	_update_vehicle_camera()
	if _is_paused:
		_close_pause_menu()
	_notify("Visuale esterna · mouse per guardarti intorno." if _vehicle_third_person else "Visuale dal sedile.")

func _update_vehicle_camera() -> void:
	var visual: Node3D = _mounted_vehicle.visual
	if not _vehicle_third_person or _mounted_vehicle.level not in [2,3]:
		if _mounted_vehicle.level in [2,3]:
			look_rotation.y = _vehicle_heading+clampf(wrapf(look_rotation.y-_vehicle_heading,-PI,PI),-1.75,1.75)
			look_rotation.x = clampf(look_rotation.x,-1.05,0.8)
		var seat: Vector3 = Vector3(0,1.7,0) if _mounted_vehicle.level==1 else (Vector3(0,1.78,-0.11) if _mounted_vehicle.level==3 else Vector3(0,1.94,-0.075))
		if _mounted_vehicle.level in [2,3] and _vehicle_entry_time>0:
			seat+=Vector3(_vehicle_entry_side*1.35,-0.12,0.15)*pow(_vehicle_entry_time/0.24,2)
		camera.position = visual.position+visual.basis*seat
		camera.basis = (visual.basis*Basis.from_euler(Vector3(look_rotation.x,look_rotation.y-_vehicle_heading,0))).orthonormalized()
		camera.cull_mask = _walking_camera_mask & ~(1<<19)
		return
	camera.cull_mask = _walking_camera_mask | (1<<19)
	var focus: Vector3 = visual.global_position+Vector3.UP*1.35
	var pitch: float = clampf(look_rotation.x,-0.6,0.5)
	var orbit: Basis = Basis.from_euler(Vector3(pitch,look_rotation.y,0))
	var desired: Vector3 = focus+orbit*Vector3(0,1.6,5.8)
	# Cast a small camera volume; both walls and terrain retract the boom.
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.24
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY,focus)
	query.motion = desired-focus
	query.collision_mask = 1
	query.exclude = [get_rid(),_mounted_vehicle.body.get_rid()]
	var fraction: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	var safe: float = maxf(0,float(fraction[0])-0.025)
	camera.global_position = focus+(desired-focus)*safe
	if camera.global_position.distance_to(focus)>0.15:
		camera.look_at(focus,Vector3.UP)

func _sell_crafted_product(id: String, ticket: int) -> void:
	var station = _ops_service_node()
	if station==null or str(station.get_meta("operation"))!="customer" or str(station.get_meta("customer"))!=id:
		return
	var success: bool = _game_state.crafting.sell_product(id,1,ticket)
	preload("res://scripts/ui/customer_panel.gd").open(self,id)
	if success:
		_notify("Prodotto consegnato al cliente.")

func _open_career(page: String = "story") -> void:
	_career_current_page=page
	if page=="map" and (global_position.x< -50 or global_position.x>45 or global_position.z< -15 or global_position.z>50):
		_career_map_wide = true
	preload("res://scripts/ui/career_panel.gd").open(self,page)

func _claim_career(id: String) -> void:
	if _game_state.story.claim(id):
		_open_career("projects")
	else:
		_close_pause_menu()
		_notify("Progetto non confermato: controlla requisiti e salvataggio.")

func _apply_career_route(step: Dictionary) -> void:
	var point: Dictionary = preload("res://scripts/gameplay/yard_navigation.gd").objective(self,step)
	_navigation_target = point.position
	_navigation_label = "OBIETTIVO · "+point.name
	_career_route_key = step.route+step.material

func _track_career() -> void:
	_career_tracking = true
	_apply_career_route(_game_state.story.next_step())
	_close_pause_menu()
	_notify("Guida attiva. Il navigatore seguirà il prossimo passo; lo scanner seleziona una ricerca manuale.")

func _route_career_map(id: String) -> void:
	var points: Dictionary = preload("res://scripts/gameplay/yard_navigation.gd").points(self)
	if not points.has(id):
		return
	_career_tracking = false
	_navigation_target = points[id].position
	_navigation_label = points[id].name
	_close_pause_menu()
	_notify("Destinazione: "+_navigation_label)

func _locate_recipe_requirement(kind: String) -> void:
	if _near_ops_service()!="craft":
		return
	var step: Dictionary = _game_state.crafting.next_requirement(kind)
	if step.is_empty():
		return
	_career_tracking=false
	_apply_career_route(step)
	_close_pause_menu()
	_notify(step.title+" · "+step.detail)

func _center_popup_if_open(popup, dimensions: Vector2i) -> void:
	if is_instance_valid(popup) and popup.is_inside_tree() and not popup.is_queued_for_deletion() and popup==_pause_menu:
		popup.popup_centered(dimensions)

func _toggle_career_map() -> void:
	_career_map_wide = not _career_map_wide
	preload("res://scripts/ui/career_panel.gd").open(self,"map")

func _sell_surplus() -> void:
	if not _near_depot():
		return
	var revenue: int = EconomyService.sell_surplus()
	_notify("Avanzi venduti: +%d Bulloni." % revenue if revenue>0 else "Nessun avanzo venduto. Scorte conservate per gli obiettivi o salvataggio non riuscito.")
	_refresh_station()

func _confirm_sell_all() -> void:
	if not _near_depot():
		return
	var confirm = ConfirmationDialog.new()
	confirm.theme=preload("res://scripts/ui/industrial_theme.gd").create()
	confirm.title="Vendita totale"
	confirm.dialog_text = "%d Bulloni per tutte le scorte?\nInclude i materiali utili agli obiettivi.\nProdotti e pezzi riservati restano." % _game_state.get_deposit_value()
	confirm.ok_button_text = "Vendi tutto"
	confirm.cancel_button_text = "Annulla"
	preload("res://scripts/ui/menu_art.gd").button_style(confirm.get_ok_button(),true)
	preload("res://scripts/ui/menu_art.gd").button_style(confirm.get_cancel_button())
	confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(confirm)
	confirm.confirmed.connect(func(): _sell_deposit(); confirm.queue_free())
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()

func _play_feedback(kind: String) -> void:
	var audio = get_tree().get_first_node_in_group("yard_audio")
	if is_instance_valid(audio):
		audio.play_event(kind)

func _activate_interaction(focus: Dictionary) -> void:
	match focus.kind:
		"dismount": _dismount_vehicle()
		"uncouple": _stop_cart()
		"crafted": preload("res://scripts/ui/crafting_panel.gd").object_menu(self,focus.node)
		"carry": _interact_carried()
		"bulk":
			_game_state.ops.pickup_part(focus.node.part_id)
			_cancel_collection()
		"cargo": _open_buggy_cargo()
		"operation": _open_ops_service(focus.node)
		"secret":
			if focus.node.secret_id in _game_state.secrets_found or focus.node.discover():
				_open_journal()
			else:
				_notify("Impossibile salvare la scoperta: riprova prima di allontanarti.")
		"field_depot": _open_field_depot()
		"vehicle": _mount_vehicle(focus.node)
		"terminal": _open_service(focus.service)
		"press": _open_press()
		"depot": _open_station()

func _open_fabrication_queue() -> void:
	if _near_ops_service() in ["craft","fabrication"]:
		preload("res://scripts/ui/crafting_panel.gd").queue(self)

func _cancel_fabrication(id: String) -> void:
	if _near_ops_service() not in ["craft","fabrication"]:
		return
	var success: bool = _game_state.fabrication.cancel(id)
	_open_fabrication_queue()
	_notify("Lavoro annullato: materiali e componenti restituiti." if success else "Operazione non riuscita; lavoro conservato.")

func _on_panel_shortcut(event: InputEvent, title: String) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _gameplay_key(event):
		return
	if title=="ATTREZZATURA PERSONALE" and event.keycode==KEY_I:
		_pause_menu.set_input_as_handled()
		_close_pause_menu()
	elif title=="DIARIO / RIVA SECCA" and event.keycode in [KEY_J,KEY_M]:
		_pause_menu.set_input_as_handled()
		var page: String = "story" if event.keycode==KEY_J else "map"
		if _career_current_page==page:
			_close_pause_menu()
		else:
			_open_career(page)

func _recover_owned_buggy() -> void:
	if _near_service("vehicles")!="vehicles":
		return
	var vehicle: Node3D
	for candidate in get_tree().get_nodes_in_group("yard_vehicles"):
		if candidate.level==2:
			vehicle=candidate
	var success: bool = _game_state.ops.recover_buggy(vehicle)
	_close_pause_menu()
	_notify("Buggy riportato al parcheggio · carico conservato · −%d Bulloni." % int(_game_state.logistics_def.buggy_recovery_cost) if success else "Soccorso non disponibile: controlla Bulloni, parcheggio libero e mezzo fermo.")
























