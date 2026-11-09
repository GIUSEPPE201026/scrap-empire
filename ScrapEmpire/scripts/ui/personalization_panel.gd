extends RefCounted
const ID=preload("res://scripts/economy/yard_identity.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func open(player: Node) -> void:
	player._close_pause_menu()
	player._open_panel("LA TUA DISCARICA")
	var current: Dictionary=ID.data()
	player._panel_box.add_child(ART.label("Insegna",18))
	var name_field=LineEdit.new()
	name_field.text=current.name
	name_field.max_length=24
	name_field.custom_minimum_size=Vector2(650,48)
	player._panel_box.add_child(name_field)
	var choices: Array[OptionButton]=[]
	for item in [["Buggy","buggy"],["Monopattino","scooter"]]:
		var row=HBoxContainer.new()
		player._panel_box.add_child(row)
		var title=ART.label(item[0],20)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var choice=OptionButton.new()
		choice.custom_minimum_size=Vector2(270,48)
		for color in ID.NAMES:
			choice.add_item(color)
		choice.select(int(current[item[1]]))
		row.add_child(choice)
		choices.append(choice)
	var preview=ColorRect.new()
	preview.color=ID.COLORS[int(current.buggy)]
	preview.custom_minimum_size.y=12
	player._panel_box.add_child(preview)
	choices[0].item_selected.connect(func(index):preview.color=ID.COLORS[index])
	var status=ART.label("Nome e livree · salvataggio locale",16)
	player._panel_box.add_child(status)
	var ticket: int=GameState.operations.serial
	var apply=player._add_panel_button("Salva",func():
		if player._near_service("vehicles")!="vehicles" and player._near_ops_service()!="identity":
			status.text="Avvicinati al garage o al pannello dell'insegna."
			return
		if ID.apply(name_field.text,choices[0].selected,choices[1].selected,ticket):
			player._close_pause_menu()
			player._notify(Localization.text("Insegna e livree aggiornate."))
		else:
			status.text="Nome non valido o salvataggio non riuscito. Riprova."
	)
	ART.button_style(apply,true)
	player._add_panel_button("TORNA AL LAVORO",player._close_pause_menu)
	player._pause_menu.popup_centered(Vector2i(740,510))
