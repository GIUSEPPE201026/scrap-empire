extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func open(player: Node, selected: int=-1) -> void:
	if selected<0:
		selected=0
		if not GameState.secrets_found.is_empty():
			for index in GameState.secret_defs.size():
				if GameState.secret_defs[index].id==GameState.secrets_found.back(): selected=index
	selected=clampi(selected,0,GameState.secret_defs.size()-1)
	player._close_pause_menu()
	player._open_panel("ALBUM / CURIOSITÀ DELLA DISCARICA")
	var count: int=GameState.secrets_found.size()
	var summary=ART.label("%d / %d  ·  REPERTI SCOPERTI" % [count,GameState.secret_defs.size()],14,UI.MUTED)
	player._panel_box.add_child(summary)
	var body=HBoxContainer.new()
	body.add_theme_constant_override("separation",20)
	player._panel_box.add_child(body)
	var list=VBoxContainer.new()
	list.add_theme_constant_override("separation",8)
	body.add_child(list)
	for index in GameState.secret_defs.size():
		var definition: Dictionary=GameState.secret_defs[index]
		var found: bool=definition.id in GameState.secrets_found
		var tile=UI.tile(list,definition.id if found else "book",definition.name if found else "Indizio %02d" % (index+1),player._open_journal.bind(index),index==selected,true,"✓" if found else "?")
		tile.custom_minimum_size=Vector2(180,104)
		var art: TextureRect=tile.get_child(0).get_child(0)
		art.custom_minimum_size.y=54
		if not found and index==selected: art.modulate=UI.INK
		tile.set_meta("curiosity_index",index)
	var detail=VBoxContainer.new()
	detail.custom_minimum_size.x=370
	detail.add_theme_constant_override("separation",14)
	body.add_child(detail)
	var definition: Dictionary=GameState.secret_defs[selected]
	var found: bool=definition.id in GameState.secrets_found
	UI.hero(detail,definition.id if found else "book",Vector2(350,175))
	var title=ART.label(definition.name.to_upper() if found else "INDIZIO %02d" % (selected+1),23,UI.PAPER)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(title)
	var text=ART.label(definition.description if found else definition.hint,17,UI.PAPER)
	text.custom_minimum_size.x=350
	text.size.x=350
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(text)
	detail.add_child(ART.label("SCOPERTO · premio già assegnato" if found else "%d Bulloni · alla scoperta" % definition.reward,14,UI.ORANGE))
	player._pause_menu.popup_centered(Vector2i(650,520))
	player.call_deferred("_center_popup_if_open",player._pause_menu,Vector2i(650,520))
