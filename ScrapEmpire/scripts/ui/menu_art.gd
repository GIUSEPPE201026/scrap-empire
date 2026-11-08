extends RefCounted
const SYMBOLS = preload("res://scripts/ui/menu_symbols.gd")
const UI=preload("res://scripts/ui/salvage_ui.gd")

static func ingredient(parent: Node, caption: String, owned: int, required: int, component: bool = false) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	parent.add_child(row)
	var symbol=TextureRect.new()
	symbol.texture=UI.image(SYMBOLS.item_key(caption))
	symbol.custom_minimum_size=Vector2(38,38)
	row.tooltip_text=caption+(" · funzionante" if component else "")
	symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.modulate=Color("#84d7bd") if owned>=required else Color("#efc374")
	row.add_child(symbol)
	var name_label=label(caption.replace(" ✓",""),15,UI.PAPER)
	name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	row.add_child(label("%d / %d" % [owned,required],19,symbol.modulate))

static func details(parent: Node, text_value: String, caption: String = "Dettagli") -> Label:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var toggle = Button.new()
	toggle.text = caption+"  +"
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.flat = true
	toggle.add_theme_font_size_override("font_size",14)
	toggle.add_theme_color_override("font_color",Color("#9db4bc"))
	column.add_child(toggle)
	var body = label(text_value,15,Color("#b9c8ce"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.hide()
	column.add_child(body)
	toggle.pressed.connect(func():
		body.visible = not body.visible
		toggle.text = caption+("  −" if body.visible else "  +")
	)
	return body

static func picture(path: String, dimensions: Vector2) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.custom_minimum_size = dimensions
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func equipment(index: int) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/equipment_atlas.png")
	var half: Vector2 = atlas.atlas.get_size() / 2
	atlas.region = Rect2(Vector2(index % 2, index / 2) * half, half)
	return atlas

static func vehicle(index: int) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/vehicle_atlas.png")
	var dimensions: Vector2 = atlas.atlas.get_size()
	atlas.region = Rect2(index * dimensions.x / 2, 0, dimensions.x / 2, dimensions.y)
	return atlas

static func label(text_value: String, font_size: int, color: Color = Color("#f1ecdc")) -> Label:
	var result = Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func button_style(button: Button, primary: bool = false) -> void:
	SYMBOLS.compact(button)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",22)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = UI.ORANGE if primary else UI.SURFACE
		if state == "hover":
			style.bg_color = Color("#ffb66f") if primary else Color("#46503e")
		if state == "disabled":
			style.bg_color = Color("#292e27")
		style.set_corner_radius_all(3)
		style.set_border_width_all(1)
		style.border_color = UI.ORANGE if primary or state == "focus" else Color("#59624f")
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#18232b") if primary else Color("#f4edda"))
	button.add_theme_color_override("font_hover_color", Color("#18232b") if primary else Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("#18232b") if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#18232b") if primary else Color.WHITE)
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_color_override("icon_"+state+"_color",Color("#18232b") if primary else Color("#d7e5e7"))
	button.add_theme_color_override("icon_disabled_color",Color("#6d858e"))
	SYMBOLS.visual_action(button)

static func icon_tile(parent: Node, key: String, caption: String, callback: Callable, selected: bool=false, enabled: bool=true, badge: String="") -> Button:
	var button=Button.new()
	button.tooltip_text=caption
	button.text=badge
	button.icon=SYMBOLS.icon(key,128)
	button.disabled=not enabled
	button.pressed.connect(callback)
	button_style(button,selected)
	button.custom_minimum_size=Vector2(112,88)
	button.add_theme_constant_override("icon_max_width",56)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

static func main_menu(root: Control) -> void:
	root.get_node("BgPanel").hide()
	var background = picture("res://assets/ui/empire_keyart.png", Vector2.ZERO)
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.075, 0.46)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left = VBoxContainer.new()
	left.position = Vector2(64, 64)
	left.size = Vector2(440, 660)
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)
	left.add_child(label("R I V A   S E C C A", 13, Color("#edbc60")))
	var title = label("SCRAP\nEMPIRE", 76)
	title.add_theme_constant_override("line_spacing", -12)
	left.add_child(title)
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 18
	left.add_child(spacer)
	root.btn_single.reparent(left)
	root.btn_single.text = "GIOCA"
	root.btn_single.icon = SYMBOLS.icon("play")
	root.btn_single.show()
	button_style(root.btn_single, true)
	root.btn_options.reparent(left)
	root.btn_options.text = "IMPOSTAZIONI"
	root.btn_options.show()
	button_style(root.btn_options)
	var network_toggle = Button.new()
	network_toggle.text = "Cooperativa"
	button_style(network_toggle)
	network_toggle.flat=true
	left.add_child(network_toggle)
	var network_row = HBoxContainer.new()
	left.add_child(network_row)
	for button in [root.btn_host, root.btn_join]:
		button.reparent(network_row)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2.ZERO
		button.show()
		button_style(button)
	network_row.hide()
	network_toggle.pressed.connect(func(): network_row.visible = not network_row.visible)
	root.btn_quit.reparent(left)
	root.btn_quit.show()
	root.btn_quit.text = "ESCI"
	button_style(root.btn_quit)
	var footer = label("RECUPERA  /  COSTRUISCI  /  ESPANDI", 12, Color("#c5bca8"))
	root.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left=64
	footer.offset_top=-44
	footer.offset_bottom=-24
	root.btn_single.grab_focus()

static func card(parent: Control, title: String, description: String, index: int, action: String, callback: Callable, unavailable: bool, illustration: Texture2D = null, compact: bool = false) -> Button:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1c3038")
	style.border_color = Color("#3d5861")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var art = TextureRect.new()
	art.texture = illustration if illustration != null else equipment(index)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if illustration != null else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(205, 100 if compact else 140)
	column.add_child(art)
	column.add_child(label(title, 19, Color("#edbc60")))
	var detail = label(description, 15, Color("#c6d2d2"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(205, 38)
	column.add_child(detail)
	var button = Button.new()
	button.text = action
	button.disabled = unavailable
	button.pressed.connect(callback)
	button_style(button, not unavailable)
	column.add_child(button)
	return button
