extends RefCounted
## Original workshop visual language: graphite, sand, safety orange, real item previews.
const INK=Color("#202321")
const SURFACE=Color("#30342f")
const PAPER=Color("#e9e1ce")
const MUTED=Color("#a8ad9e")
const ORANGE=Color("#ed9853")
const SYMBOLS=preload("res://scripts/ui/menu_symbols.gd")
static var _images: Dictionary={}

static func image(kind: String) -> Texture2D:
	var id: String={"cutters":"bolt_cutters","suspension":"suspension_kit","truck":"buggy","light":"work_lamp","radio":"restored_radio","repair":"repair_kit","bag":"bag_frame","bench":"garden_bench","press":"press_kit","box":"field_depot"}.get(kind,kind)
	if not _images.has(id):
		var path: String="res://assets/ui/catalog/%s.png" % id
		_images[id]=load(path) if ResourceLoader.exists(path) else SYMBOLS.icon(kind,128)
	return _images[id]

static func picture(parent: Node, kind: String, dimensions: Vector2) -> TextureRect:
	var rect=TextureRect.new()
	rect.texture=image(kind)
	rect.custom_minimum_size=dimensions
	rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

static func style(color: Color=SURFACE, selected: bool=false, margin: int=12) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=color
	box.border_color=ORANGE if selected else Color("#555c50")
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(3)
	box.content_margin_left=margin
	box.content_margin_right=margin
	box.content_margin_top=margin
	box.content_margin_bottom=margin
	return box

static func tile(parent: Node, key: String, caption: String, callback: Callable, selected: bool=false, enabled: bool=true, badge: String="") -> Button:
	var button=Button.new()
	button.tooltip_text=caption
	button.disabled=not enabled
	button.custom_minimum_size=Vector2(130,138)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,style(PAPER if selected else (Color("#41493d") if state=="hover" else SURFACE),selected or state=="focus",8))
	var column=VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left=8
	column.offset_right=-8
	column.offset_top=6
	column.offset_bottom=-6
	var art=picture(column,key,Vector2(110,91))
	art.size_flags_vertical=Control.SIZE_EXPAND_FILL
	art.modulate=Color.WHITE if enabled or selected else Color("#777c70")
	var name_label=Label.new()
	name_label.text={"handcart":"Carrello","field_depot":"Deposito","work_lamp":"Faro","repair_kit":"Kit riparazione","suspension_kit":"Sospensioni","cargo_kit":"Sponde","press_kit":"Idraulica","bag_frame":"Telaio sacca","desk_lamp":"Lampada","toolbox":"Cassetta","restored_radio":"Radio","bench_compressor":"Compressore","garden_bench":"Panca"}.get(key,caption.get_slice(" · ",0))
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size",14)
	name_label.add_theme_color_override("font_color",INK if selected else PAPER)
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	if not badge.is_empty():
		var tag=Label.new()
		tag.text=badge
		tag.position=Vector2(8,4)
		tag.add_theme_font_size_override("font_size",13)
		tag.add_theme_color_override("font_color",INK if selected else ORANGE)
		tag.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(tag)
	parent.add_child(button)
	return button

static func action(button: Button, caption: String, primary: bool=false) -> Button:
	button.text=caption
	button.set_meta("keep_label",true)
	load("res://scripts/ui/menu_art.gd").button_style(button,primary)
	button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y=44
	return button

static func hero(parent: Node, kind: String, dimensions: Vector2) -> TextureRect:
	var panel=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",style(Color("#252922"),false,8))
	parent.add_child(panel)
	return picture(panel,kind,dimensions)

static func column(parent: Node, width: float, color: Color=SURFACE) -> VBoxContainer:
	var panel=PanelContainer.new()
	panel.custom_minimum_size.x=width
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",style(color,false,14))
	parent.add_child(panel)
	var body=VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	panel.add_child(body)
	return body
