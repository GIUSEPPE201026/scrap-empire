## ScrapDef.gd
## Definizione risorsa per i tipi di rottame. Caricata da data/balance.json.

class_name ScrapDef
extends Resource

@export var id: String = ""
@export var material_id: String = ""
@export var mass_kg: float = 0.0
@export var collect_seconds: float = 0.0
@export var visual_scene: PackedScene = null

## Crea un dizionario serializzabile per rete/salvataggio
func to_dict() -> Dictionary:
	return {
		"id": id,
		"material_id": material_id,
		"mass_kg": mass_kg,
		"collect_seconds": collect_seconds,
		"visual_scene_path": visual_scene.resource_path if visual_scene else ""
	}

## Carica definizioni da balance.json
static func load_from_balance(balance_path: String = "res://data/balance.json") -> Array[ScrapDef]:
	var file = FileAccess.open(balance_path, FileAccess.READ)
	if not file:
		push_error("Impossibile aprire %s" % balance_path)
		return []

	var json_text = file.get_as_text()
	file.close()
	var balance = JSON.parse_string(json_text)
	if not balance:
		push_error("JSON non valido in %s" % balance_path)
		return []

	var defs: Array[ScrapDef] = []
	var materials = balance.materials
	var sector_counts = balance.sector_counts

	for mat_id in materials:
		var mat = materials[mat_id]
		var count = sector_counts.get(mat_id, 0)

		for i in range(count):
			var def = ScrapDef.new()
			def.id = "%s_%03d" % [mat_id, i]
			def.material_id = mat_id
			def.mass_kg = mat.mass_kg
			def.collect_seconds = mat.collect_seconds
			defs.append(def)

	return defs
