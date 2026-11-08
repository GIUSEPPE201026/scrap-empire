extends StaticBody3D
var caption: Label3D
var back_caption: Label3D

func _ready() -> void:
	add_to_group("operations_service")
	set_meta("operation","identity")
	var shape=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(0.5,1.5,0.4)
	shape.position.y=0.75
	add_child(shape)
	caption=Label3D.new()
	caption.name="CustomYardName"
	caption.position=Vector3(-9,5.6,3.4)
	caption.font_size=72
	caption.pixel_size=0.006
	caption.rotation.y=PI
	caption.modulate=Color("#ffe4aa")
	add_child(caption)
	back_caption=caption.duplicate()
	back_caption.name="CustomYardNameBack"
	back_caption.position.z=4.65
	back_caption.rotation.y=0
	add_child(back_caption)
	if DisplayServer.get_name()!="headless":
		var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
		art.beveled_box(self,Vector3(16,1.2,0.4),Vector3(-9,5.6,4.06),art.GRAPHITE)
		art.box(self,Vector3(0.5,1.5,0.4),Vector3(0,0.75,0),art.MINT)
	GameState.operations_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	caption.text=preload("res://scripts/economy/yard_identity.gd").data().name
	back_caption.text=caption.text
