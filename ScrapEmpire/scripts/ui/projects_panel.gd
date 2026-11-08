extends RefCounted
const UI=preload("res://scripts/ui/salvage_ui.gd")
const ART=preload("res://scripts/ui/menu_art.gd")

static func build(player: Node) -> void:
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.y=minf(465,player.get_window().size.y-270)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	player._panel_box.add_child(scroll)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	scroll.add_child(row)
	var service=GameState.story
	var index: int=0
	for project in service.definition().projects:
		var card=UI.column(row,275)
		UI.picture(card,["garden_bench","press_machine","electronics"][index%3],Vector2(235,95))
		var title=ART.label(project.name.to_upper(),20,UI.PAPER)
		title.custom_minimum_size.x=235
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		card.add_child(title)
		for rule in project.rules:
			var have: int=service.metric(rule.metric)
			var label=ART.label("%s · %d/%d" % [rule.label,have,rule.amount],14,UI.MUTED)
			label.custom_minimum_size.x=235
			label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			card.add_child(label)
			var progress=ProgressBar.new()
			progress.show_percentage=false
			progress.value=minf(100,100.0*have/maxf(1,rule.amount))
			progress.custom_minimum_size.y=6
			card.add_child(progress)
		var reward=Button.new()
		reward.disabled=not service.ready(project.id)
		reward.pressed.connect(player._claim_career.bind(project.id))
		UI.action(reward,"Realizzato" if service.has_project(project.id) else "Riscuoti · %d" % project.reward,not reward.disabled)
		reward.set_meta("action_label","OTTIENI RICONOSCIMENTO")
		reward.tooltip_text=project.benefit
		card.add_child(reward)
		ART.details(card,project.description+"\n"+project.benefit,"Beneficio")
		index+=1
