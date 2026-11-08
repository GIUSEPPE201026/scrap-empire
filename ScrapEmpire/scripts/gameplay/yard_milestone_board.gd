extends Node3D

var caption: Label3D
var lights: Array[MeshInstance3D] = []
var previous: int = -1

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	for x in [-2.15,2.15]:
		art.box(self, Vector3(0.1, 3.7, 0.1), Vector3(x,1.85,0.08), art.STEEL)
	art.beveled_box(self, Vector3(4.6,1.8,0.18), Vector3(0,2.75,0), art.GRAPHITE)
	caption = art.sign_text(self, "", Vector3(0,3.1,-0.11), 38)
	caption.rotation.y = PI
	caption.pixel_size = 0.0028
	caption.outline_size = 1
	for index in GameState.order_defs.size():
		lights.append(art.beveled_box(self, Vector3(0.5,0.12,0.03), Vector3(-1.4 + index * 0.7,2.25,-0.12), art.STEEL))
	_process(0)

func _process(_delta: float) -> void:
	var count: int = GameState.completed_orders.size()
	if previous == count or caption == null:
		return
	previous = count
	caption.text = "CENTRO DI RECUPERO\n%s" % ("CERTIFICATO" if count == GameState.order_defs.size() else "AVVIAMENTO  %d / %d" % [count, GameState.order_defs.size()])
	for index in lights.size():
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("#85ccb0") if index < count else Color("#4a5d61")
		material.emission_enabled = index < count
		material.emission = Color("#3a8068")
		lights[index].material_override = material
