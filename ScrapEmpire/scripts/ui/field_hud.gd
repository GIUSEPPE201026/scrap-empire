extends Control
const UI=preload("res://scripts/ui/salvage_ui.gd")
const SYMBOLS=preload("res://scripts/ui/menu_symbols.gd")
var player: Node3D
var layout_rects: Array[Rect2]=[]
var _elapsed: float=0.0
var _box: StyleBoxFlat

func _ready() -> void:
	name="FieldHUD"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box=UI.style(Color("#202321ed"),false,0)
	refresh()

func refresh() -> void:
	if not is_instance_valid(player): return
	player.get_node("HUD/InventoryHUD").hide()
	player._hint.hide()
	player._hotbar.hide()
	player._feedback.hide()
	for slot in player._hotbar_slots: slot.get_parent().hide()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<0.1: return
	_elapsed=0
	refresh()

func caption(value: String, at: Vector2, font_size: int=15, color: Color=UI.PAPER, width: float=-1) -> void:
	var font: Font=get_theme_default_font()
	if width>0 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
		while not value.is_empty() and font.get_string_size(value+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width: value=value.left(-1)
		value+="…"
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func picture(key: String, at: Vector2, dimensions: Vector2, color: Color=Color.WHITE) -> void:
	draw_texture_rect(UI.image(key),Rect2(at,dimensions),false,color)

func plate(rect: Rect2) -> void:
	draw_style_box(_box,rect)
	layout_rects.append(rect)

func _draw() -> void:
	if not is_instance_valid(player): return
	layout_rects.clear()
	var view: Vector2=get_viewport_rect().size
	var money=Rect2(Vector2(view.x-206,22),Vector2(182,58))
	plate(money)
	draw_texture_rect(SYMBOLS.icon("coin"),Rect2(money.position+Vector2(12,17),Vector2(24,24)),false,UI.ORANGE)
	caption(str(GameState.team_credits),money.position+Vector2(48,30),23)
	caption("BULLONI",money.position+Vector2(48,46),11,UI.MUTED)
	var riding: bool=is_instance_valid(player._mounted_vehicle)
	var driving: bool=riding and player._mounted_vehicle.level in [2,3]
	var goal=Rect2(Vector2(24,22),Vector2(352,82))
	plate(goal)
	caption(preload("res://scripts/gameplay/yard_clock.gd").caption(),goal.position+Vector2(12,21),12,UI.MUTED)
	var objective: String=player._career_hud_step.get("title","Esplora Riva Secca")
	if driving: objective="DUNE / "+player._region_name()
	caption(objective,goal.position+Vector2(12,49),17,UI.PAPER,326)
	caption(("[J] Diario" if player._shortcut_free(KEY_J) else "Pausa · Diario")+("    [M] Mappa" if player._shortcut_free(KEY_M) else ""),goal.position+Vector2(12,69),12,UI.ORANGE)
	if not player._navigation_label.is_empty():
		preload("res://scripts/ui/navigation_marker.gd").draw_marker(self,player)
		var route=Rect2(Vector2(24,112),Vector2(352,34))
		plate(route)
		var delta: Vector3=player.camera.global_basis.inverse()*(player._navigation_target-player.camera.global_position)
		var arrow: String=("↑" if delta.z<0 else "↓") if absf(delta.x)<absf(delta.z)*0.5 else ("→" if delta.x>0 else "←")
		caption(arrow+"  "+player._navigation_label+" · %.0f m" % player.global_position.distance_to(player._navigation_target),route.position+Vector2(10,22),13,UI.ORANGE,332)
	var bag=Rect2(Vector2(24,view.y-160),Vector2(248,132))
	plate(bag)
	picture("bag",bag.position+Vector2(8,6),Vector2(40,36))
	var mass: float=GameState.get_inventory_mass(player.owner_peer_id)
	var capacity: float=GameState.get_inventory_capacity(player.owner_peer_id)
	caption("%.1f / %.0f kg" % [mass,capacity],bag.position+Vector2(58,29),20)
	draw_rect(Rect2(bag.position+Vector2(12,47),Vector2(224,5)),Color("#545a4c"))
	draw_rect(Rect2(bag.position+Vector2(12,47),Vector2(224*clampf(mass/capacity,0,1),5)),UI.ORANGE)
	var inventory: Dictionary=GameState.player_inventories.get(player.owner_peer_id,{})
	var index: int=0
	for key in ["metal","plastic","electronics","copper","aluminum","glass","rubber"]:
		if int(inventory.get(key,0))<=0: continue
		var point: Vector2=bag.position+Vector2(12+(index%4)*57,62+(index/4)*29)
		picture(key,point,Vector2(27,26))
		caption(str(inventory[key]),point+Vector2(28,18),13)
		index+=1
	if index==0: caption("SACCA VUOTA",bag.position+Vector2(12,84),12,UI.MUTED)
	if driving:
		var speed=Rect2(Vector2(view.x/2-140,view.y-114),Vector2(280,86))
		plate(speed)
		caption("%02d" % roundi(absf(player._vehicle_speed)*3.6),speed.position+Vector2(14,48),40)
		caption("KM/H",speed.position+Vector2(90,47),12,UI.MUTED)
		var state: String="P · PARCHEGGIO" if player._vehicle_motion.parking_brake else ("DERAPATA" if player._vehicle_motion.drift_blend>0.4 else "SPAZIO · FRENO A MANO")
		if player._mounted_vehicle.level==3 and not player._vehicle_motion.parking_brake: state="CROSS · SPAZIO SALTO"
		caption(state,speed.position+Vector2(14,72),12,UI.ORANGE)
		caption("[V] Visuale  ·  [E] Scendi",speed.position+Vector2(130,27),11,UI.MUTED)
	else:
		var selected: int=3 if riding else (player._active_tool()+1 if player._active_tool()>=3 else player._active_tool())
		for slot in 6:
			var rect=Rect2(Vector2(view.x/2-175+slot*59,view.y-95),Vector2(53,53))
			var owned: bool=(GameState.vehicle_level>0 or preload("res://scripts/economy/extra_mobility.gd").owned("skateboard")) if slot==3 else GameState.owns_tool(slot-1 if slot>=4 else slot)
			draw_style_box(UI.style(UI.PAPER if slot==selected else UI.INK,slot==selected,0),rect)
			layout_rects.append(rect)
			var portable: String=GameState.operations.get("mobility",{}).get("portable","scooter")
			picture(["hands","screwdriver","hammer",portable,"crowbar","bolt_cutters"][slot],rect.position+Vector2(5,4),Vector2(43,40),Color.WHITE if owned else Color("#656c61"))
			caption(player._hotbar_slots[slot].text.get_slice(" · ",0),rect.position+Vector2(4,13),10,UI.INK if slot==selected else UI.MUTED)
		caption(player._hotbar.text.capitalize(),Vector2(view.x/2-160,view.y-20),12,UI.MUTED,320)
	if not player._feedback.text.is_empty():
		var notice=Rect2(Vector2(view.x/2-235,view.y-205),Vector2(470,45))
		plate(notice)
		draw_rect(Rect2(notice.position,Vector2(3,45)),UI.ORANGE)
		caption(player._feedback.text,notice.position+Vector2(13,27),14,UI.PAPER,444)
