extends RefCounted

static func create() -> Theme:
	var theme = Theme.new()
	theme.default_font_size = 17
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color("#202321")
	panel.border_color = Color("#696f5e")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	theme.set_color("font_color", "Label", Color("#e9e1ce"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var button = StyleBoxFlat.new()
		button.bg_color = Color("#343a31") if state == "normal" else Color("#48513f")
		if state == "disabled":
			button.bg_color = Color("#2a2e28")
		button.set_corner_radius_all(3)
		button.content_margin_left = 18
		button.content_margin_right = 18
		button.content_margin_top = 10
		button.content_margin_bottom = 10
		button.border_color = Color("#ed9853") if state == "focus" else Color("#5d6655")
		button.set_border_width_all(2 if state == "focus" else 1)
		theme.set_stylebox(state, "Button", button)
	theme.set_color("font_color", "Button", Color("#f1eee0"))
	theme.set_color("font_disabled_color", "Button", Color("#8c9c9e"))
	return theme
