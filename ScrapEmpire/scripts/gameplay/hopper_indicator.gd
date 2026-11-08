extends MeshInstance3D

func _ready() -> void:
	mesh = SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	GameState.operations_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("#6cddac") if GameState.operations.autofeed else Color("#b89652")
	material.emission_enabled = bool(GameState.operations.autofeed)
	material.emission = material.albedo_color
	material_override = material
