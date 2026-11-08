extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(340, 230)

func _draw() -> void:
	var font = get_theme_default_font()
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	for x in range(20, int(size.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#274148"), 0.6)
	for y in range(20, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#274148"), 0.6)
	draw_line(Vector2(60, 150), Vector2(290, 150), Color("#c2a366"), 5)
	for index in 3:
		var owned: bool = index == 0 or GameState.yard_level >= index
		var box = Rect2(20 + index * 108, 45, 88, 92)
		draw_rect(box, Color("#3d746c") if owned else Color("#2a3b43"))
		draw_rect(box, Color("#8cc4b0") if owned else Color("#d2ad65"), false, 2)
		draw_string(font, box.position + Vector2(10, 26), ["BASE", "LOTTO", "LOTTO"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#eee1c7"))
		draw_string(font, box.position + Vector2(10, 48), ["SERVIZI", "EST", "DUNE"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#eee1c7"))
		draw_string(font, box.position + Vector2(10, 76), "APERTO" if owned else "PROGETTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b1d1bf") if owned else Color("#d2ad65"))
	draw_string(font, Vector2(20, 191), "ACCESSO DAL VARCO EST  →", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#efc778"))
	draw_string(font, Vector2(20, 215), "Schema dei collegamenti / non in scala", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8baaaa"))

func _background() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#172b32")
	style.set_corner_radius_all(8)
	return style
