extends Control
var player: Node3D
var locations: Dictionary = {}
var selected: String = ""
var chosen: Callable
var bounds = Rect2(Vector2(-650,-650),Vector2(1300,1300))
var _terrain: Texture2D

func _ready() -> void:
	if custom_minimum_size==Vector2.ZERO:
		custom_minimum_size = Vector2(500,480)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	if bounds.size.x>200:
		var image=Image.create(192,192,false,Image.FORMAT_RGBA8)
		for y in 192:
			for x in 192:
				var at=bounds.position+Vector2(x,y)*bounds.size/192.0
				var height: float=preload("res://scripts/gameplay/desert_world.gd").height_at(Vector3(at.x,0,at.y))
				var shade: float=clampf(height/22,0,1)
				var color=Color("#b99a69").lerp(Color("#79654d"),shade)
				if fposmod(height,2.0)<0.10 and height>0.15: color=color.darkened(0.16)
				image.set_pixel(x,y,color)
		_terrain=ImageTexture.create_from_image(image)

func map_point(point: Vector3) -> Vector2:
	var scale: float = minf((size.x-36)/bounds.size.x,(size.y-36)/bounds.size.y)
	return (size-bounds.size*scale)*0.5+(Vector2(point.x,point.z)-bounds.position)*scale

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#292d27"))
	# Terrain texture is generated once from the playable height field.
	if _terrain:
		var first=map_point(Vector3(bounds.position.x,0,bounds.position.y))
		var last=map_point(Vector3(bounds.end.x,0,bounds.end.y))
		draw_texture_rect(_terrain,Rect2(first,last-first),false)
	var base = Rect2(map_point(Vector3(-80,0,-80)),map_point(Vector3(80,0,80))-map_point(Vector3(-80,0,-80)))
	draw_rect(base,Color("#3c675b"))
	draw_rect(base,Color("#8cb6a1"),false,1.5)
	for index in 2:
		var center: Vector3 = preload("res://scripts/gameplay/expansion_lots.gd").CENTERS[index]
		var plot = Rect2(map_point(center+Vector3(-40,0,-45)),map_point(center+Vector3(40,0,45))-map_point(center+Vector3(-40,0,-45)))
		draw_rect(plot,Color("#436b58") if GameState.yard_level>index else Color("#594b39"))
	for axis in range(-600,641,10 if bounds.size.x<200 else 200):
		draw_line(map_point(Vector3(axis,0,-640)),map_point(Vector3(axis,0,640)),Color("#486a63"),0.6)
		draw_line(map_point(Vector3(-640,0,axis)),map_point(Vector3(640,0,axis)),Color("#486a63"),0.6)
	if bounds.size.x<200:
		var font = get_theme_default_font()
		for block in [[Rect2(-22,22,8,6),"UFF"],[Rect2(-2.5,22,13,6),"GAR"],[Rect2(-37.5,19.5,7,7),"MAG"],[Rect2(-12,12,4,4),"P"]]:
			var rect: Rect2 = block[0]
			var begin: Vector2 = map_point(Vector3(rect.position.x,0,rect.position.y))
			var end: Vector2 = map_point(Vector3(rect.end.x,0,rect.end.y))
			draw_rect(Rect2(begin,end-begin),Color("#1d373c"))
			draw_rect(Rect2(begin,end-begin),Color("#7da99b"),false,1)
			draw_string(font,begin+Vector2(3,14),block[1],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#c7d9cb"))
		draw_line(map_point(Vector3(-38,0,14)),map_point(Vector3(24,0,14)),Color("#9b8a5a"),4)
		draw_line(map_point(Vector3(0,0,10)),map_point(Vector3(0,0,30)),Color("#9b8a5a"),4)
	draw_line(map_point(Vector3(0,0,0)),map_point(Vector3(255,0,0)),Color("#9b8a5a"),3)
	draw_line(map_point(Vector3(0,0,70)),map_point(Vector3(0,0,230)),Color("#9b8a5a"),3)
	var font = get_theme_default_font()
	draw_string(font,Vector2(20,30),"N ↑  /  RIVA SECCA",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#e7c479"))
	draw_string(font,Vector2(20,size.y-18),"CENTRO / SERVIZI" if bounds.size.x<200 else "DESERTO · 4 VARCHI · 1,3 km",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#c6c5ab"))
	var occupied: Array[Rect2]=[]
	for id in locations:
		if id=="customer" or id=="salvage":
			continue
		var color = Color("#f0c166") if id==selected else Color("#83c9b6")
		var location: Vector2=map_point(locations[id].position)
		draw_circle(location,5 if id==selected else 3.5,color)
		if bounds.size.x>200 and id in ["depot","oasis","dune_park","crash","cave","anomaly","north_cache","east_cache","west_cache"]:
			var caption: String={"depot":"SCRAPYARD","oasis":"OASI","dune_park":"DUNE PARK","crash":"VOLO 76","cave":"GROTTA","anomaly":"SEGNALE"}.get(id,locations[id].name.get_slice(" / ",0))
			caption=caption.left(20)
			var text_size=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			var label_at=location+Vector2(7,-6)
			for attempt in 5:
				var rect=Rect2(label_at-Vector2(0,12),text_size+Vector2(4,2))
				if not occupied.any(func(other):return other.intersects(rect)):
					occupied.append(rect)
					break
				label_at.y+=14
			draw_string(font,label_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#fff3d3"))
	if is_instance_valid(player):
		var at: Vector2 = map_point(player.global_position)
		var direction = Vector2(-sin(player.rotation.y),-cos(player.rotation.y))
		draw_circle(at,10,Color("#202321"))
		draw_colored_polygon(PackedVector2Array([at+direction*11,at+direction.rotated(2.4)*8,at+direction.rotated(-2.4)*8]),Color.WHITE)
		draw_string(font,at+Vector2(13,18),"TU",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		if not player._navigation_label.is_empty():
			var destination: Vector2 = map_point(player._navigation_target)
			draw_line(at,destination,Color("#d9b25b"),1.5)
			draw_arc(destination,8,0,TAU,24,Color("#f2bf61"),2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var best: float = 15
		var found: String = ""
		for id in locations:
			if id in ["customer","salvage"]:
				continue
			var distance: float = event.position.distance_to(map_point(locations[id].position))
			if distance<best:
				best = distance
				found = id
		if not found.is_empty() and chosen.is_valid():
			chosen.call(found)
