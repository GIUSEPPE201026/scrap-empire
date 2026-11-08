extends Node3D

const SCREEN_SIZE = Vector2(1.9, 1.28)
const UI_SIZE = Vector2i(1100, 740)
var display_viewport: SubViewport
var screen: MeshInstance3D
var focus_camera: Camera3D
var active: bool = false
var active_page: String = "tools"
var module_category: String = "vehicles"
var owner_player: Node3D
var buy_buttons: Dictionary = {}
var _passive_refresh_queued: bool = false
var _passive_signature: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_monitor")
	display_viewport = SubViewport.new()
	display_viewport.size = UI_SIZE
	display_viewport.disable_3d = true
	display_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	display_viewport.handle_input_locally = true
	add_child(display_viewport)
	focus_camera = Camera3D.new()
	focus_camera.position = Vector3(0, 1.85, -1.92)
	focus_camera.rotation.y = PI
	focus_camera.fov = 45
	focus_camera.near = 0.05
	add_child(focus_camera)
	if DisplayServer.get_name() != "headless":
		var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.box(self, Vector3(2.08, 1.45, 0.18), Vector3(0, 1.85, 0.03), art.GRAPHITE)
		art.box(self, Vector3(0.12, 0.16, 0.12), Vector3(0, 1.12, 0.05), art.STEEL)
		art.box(self, Vector3(0.7, 0.05, 0.45), Vector3(0, 1.04, -0.05), art.GRAPHITE)
		art.box(self, Vector3(0.08, 0.025, 0.015), Vector3(0.85, 0.86, -0.07), art.MINT)
		screen = MeshInstance3D.new()
		screen.mesh = QuadMesh.new()
		screen.mesh.size = SCREEN_SIZE
		screen.position = Vector3(0, 1.85, -0.07)
		screen.rotation.y = PI
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_texture = display_viewport.get_texture()
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		screen.material_override = material
		add_child(screen)
	GameState.credits_changed.connect(_passive_economy)
	GameState.deposit_changed.connect(_passive_deposit)
	GameState.operations_changed.connect(_queue_passive_refresh)
	build_screen()

func open(player: Node3D) -> void:
	owner_player = player
	active = true
	player._cancel_collection()
	player._interact_prompt.hide()
	if is_instance_valid(player._held_tool):
		player._held_tool.hide()
	player._is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	focus_camera.make_current()
	player.get_node("HUD").hide()
	build_screen()

func close() -> void:
	active = false
	if is_instance_valid(owner_player):
		owner_player.camera.make_current()
		owner_player.get_node("HUD").show()
	owner_player = null
	build_screen()

func _input(event: InputEvent) -> void:
	if not active or not is_instance_valid(owner_player):
		return
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		owner_player._close_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		var mapped = map_pointer(event.position)
		if mapped == null:
			return
		var local_event = event.duplicate()
		local_event.position = mapped
		local_event.global_position = mapped
		display_viewport.push_input(local_event, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		display_viewport.push_input(event, true)
		get_viewport().set_input_as_handled()

func map_pointer(pointer: Vector2) -> Variant:
	if screen == null:
		return null
	var plane = Plane(Vector3.FORWARD, screen.global_position)
	var hit = plane.intersects_ray(focus_camera.project_ray_origin(pointer), focus_camera.project_ray_normal(pointer))
	if hit == null:
		return null
	var local: Vector3 = screen.to_local(hit)
	var uv = Vector2(local.x / SCREEN_SIZE.x + 0.5, 0.5 - local.y / SCREEN_SIZE.y)
	if uv.x < 0 or uv.y < 0 or uv.x > 1 or uv.y > 1:
		return null
	return uv * Vector2(UI_SIZE)

func build_screen() -> void:
	_passive_signature = _content_signature()
	display_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_ONCE
	for child in display_viewport.get_children():
		display_viewport.remove_child(child)
		child.queue_free()
	buy_buttons.clear()
	var ui = preload("res://scripts/ui/menu_art.gd")
	var background = ColorRect.new()
	background.color = Color("#202321")
	background.size = Vector2(UI_SIZE)
	display_viewport.add_child(background)
	var margin = MarginContainer.new()
	margin.position = Vector2(30, 25)
	margin.size = Vector2(UI_SIZE) - Vector2(60, 50)
	margin.theme = preload("res://scripts/ui/industrial_theme.gd").create()
	display_viewport.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)
	var heading = HBoxContainer.new()
	column.add_child(heading)
	var title = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	title.add_child(ui.label("UFFICIO", 15, Color("#8da9aa")))
	title.add_child(ui.label("Riva Secca" if active_page=="career" else "Ricerca pezzi" if active_page=="specific" else ("Commesse" if active_page == "orders" else ("Impianti" if active_page == "modules" else "Equipaggiamento")), 28, Color("#f0dfbd")))
	var wallet = ui.label("%d Bulloni" % GameState.team_credits, 22, Color("#edbc60"))
	heading.add_child(wallet)
	column.add_child(HSeparator.new())
	var navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	column.add_child(navigation)
	for page in [["career","DIARIO"], ["tools", "DOTAZIONI"], ["modules", "OFFICINA"], ["orders", "COMMESSE  ·  %d / %d" % [GameState.completed_orders.size(), GameState.order_defs.size()]],["specific","RICHIESTE"]]:
		var tab = Button.new()
		tab.text = page[1]
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_set_page.bind(page[0]))
		ui.button_style(tab, active_page == page[0])
		tab.tooltip_text=page[1]
		tab.text={"career":"Diario","tools":"Attrezzi","modules":"Upgrade","orders":"Commesse","specific":"Richieste"}[page[0]]
		tab.set_meta("keep_label",true)
		tab.icon=ui.SYMBOLS.icon({"career":"book","tools":"bag","modules":"craft","orders":"box","specific":"scan"}[page[0]])
		tab.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size.y=58
		tab.add_theme_constant_override("icon_max_width",36)
		navigation.add_child(tab)
	if active_page == "career":
		_build_career(column)
		return
	if active_page == "specific":
		preload("res://scripts/ui/specific_orders_ui.gd").build(column,owner_player,active)
		return
	if active_page == "modules":
		_build_modules(column)
		return
	if active_page == "orders":
		_build_orders(column)
		return
	
	preload("res://scripts/ui/office_pages.gd").tools(self,column)

func _set_page(page: String) -> void:
	active_page = page
	build_screen()

func _build_orders(column: VBoxContainer) -> void:
	preload("res://scripts/ui/office_pages.gd").orders(self,column)

func _build_modules(column: VBoxContainer) -> void:
	var ui = preload("res://scripts/ui/menu_art.gd")
	var categories=HBoxContainer.new()
	column.add_child(categories)
	for entry in [["vehicles","Mezzi","truck"],["recovery","Recupero","bag"],["production","Produzione","press"]]:
		var tab=Button.new()
		tab.text=entry[1]
		tab.icon=ui.SYMBOLS.icon(entry[2])
		tab.pressed.connect(_set_module_category.bind(entry[0]))
		ui.button_style(tab,module_category==entry[0])
		categories.add_child(tab)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows = GridContainer.new()
	rows.columns=2
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	for id in GameState.module_defs:
		var category: String = "vehicles" if id in ["motor","suspension","cargo_rack","brakes","tyres"] else ("production" if id in ["press_drive","workbench","assembly"] else "recovery")
		if category!=module_category:
			continue
		var definition: Dictionary = GameState.module_defs[id]
		var level: int = int(GameState.workshop_modules.get(id, 0))
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#30342f")
		style.set_corner_radius_all(3)
		style.content_margin_left = 12
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.content_margin_right = 12
		panel.add_theme_stylebox_override("panel", style)
		rows.add_child(panel)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var icon = TextureRect.new()
		icon.texture = load("res://assets/ui/module_%s.svg" % definition.icon)
		var preview: String={"motor":"engine","suspension":"suspension_kit","cargo_rack":"cargo_kit","press_drive":"press_kit","workbench":"toolbox","gloves":"hands","harness":"handcart","headlamp":"work_lamp","brakes":"wheel","tyres":"rubber","assembly":"bench_compressor"}.get(id,"")
		if not preview.is_empty(): icon.texture=preload("res://scripts/ui/salvage_ui.gd").image(preview)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(60, 60)
		row.add_child(icon)
		var details = VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var title_label=ui.label("%s  ·  %d/%d" % [definition.name,level,definition.levels.size()],18)
		title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		details.add_child(title_label)
		details.custom_minimum_size.x = 225
		panel.tooltip_text=definition.description
		var requirement: String = GameState.module_requirement(id)
		var effect: String = "Completo"
		if level < definition.levels.size():
			var next: Dictionary = definition.levels[level]
			effect = ("Prestazioni +%d%%" % roundi((float(next.effect) - 1) * 100)) if id in ["motor", "suspension"] else ("Tempo −%d%%" % roundi((1 - float(next.effect)) * 100))
			if definition.get("unit","") in ["braking","grip"]:
				effect = "%s +%d%%" % ["Frenata" if definition.unit=="braking" else "Aderenza",roundi((float(next.effect)-1)*100)]
			if definition.get("unit","") == "m":
				effect = "Portata: %d m" % next.effect
			if definition.get("unit","") == "multiplier":
				effect = "Traino +%d%%" % roundi((float(next.effect)-1)*100)
			if definition.get("unit","") == "kg":
				effect = "Cassone: %d kg" % next.effect
		details.add_child(ui.label(effect,18,Color("#83c4ac")))
		if not requirement.is_empty() and not requirement.begins_with("Servono"):
			panel.tooltip_text+="\n"+requirement
		var buy = Button.new()
		buy.custom_minimum_size = Vector2(92, 65)
		buy.text = "✓" if level >= definition.levels.size() else str(definition.levels[level].cost)
		buy.icon=ui.SYMBOLS.icon("coin")
		buy.disabled = not active or not requirement.is_empty()
		buy.tooltip_text=requirement
		if id in ["suspension","cargo_rack","press_drive"] and active:
			var build=Button.new()
			build.text="Costruisci il kit"
			build.pressed.connect(owner_player._route_career_map.bind("craft"))
			ui.button_style(build)
			build.tooltip_text="Costruisci il kit · banco del garage"
			build.text=""
			build.icon=ui.SYMBOLS.icon("craft")
			build.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			build.custom_minimum_size=Vector2(64,44)
			preload("res://scripts/ui/salvage_ui.gd").action(build,"Costruisci")
			details.add_child(build)
		if active:
			buy.pressed.connect(owner_player._buy_module.bind(id))
		ui.button_style(buy, not buy.disabled)
		row.add_child(buy)
		buy_buttons[id] = buy
	var close_button = Button.new()
	close_button.text = "ESCI DAL MONITOR · ESC"
	close_button.disabled = not active
	if active:
		close_button.pressed.connect(owner_player._close_pause_menu)
	ui.button_style(close_button)
	column.add_child(close_button)

func _set_module_category(category: String) -> void:
	module_category=category
	build_screen()

func _passive_economy(_value: int) -> void:
	_queue_passive_refresh()

func _queue_passive_refresh() -> void:
	if active or _passive_refresh_queued or _passive_signature==_content_signature():
		return
	_passive_refresh_queued = true
	call_deferred("_refresh_passive")

func _refresh_passive() -> void:
	_passive_refresh_queued = false
	if is_inside_tree() and not active:
		build_screen()

func _build_career(column: VBoxContainer) -> void:
	preload("res://scripts/ui/office_pages.gd").career(self,column)

func _content_signature() -> String:
	return JSON.stringify([active_page,GameState.team_credits,GameState.team_upgrade_levels,GameState.workshop_modules,GameState.completed_orders,GameState.team_deposit_counts,GameState.press_bales,GameState.press_owned,GameState.yard_level,GameState.vehicle_level,GameState.operations.active_delivery,GameState.operations.deliveries,GameState.specifics.payload(),GameState.story.data()])

func _passive_deposit(_credits: int, _counts: Dictionary) -> void:
	_queue_passive_refresh()





