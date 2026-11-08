extends RefCounted
const COLORS=[Color("#edb83c"),Color("#68b5a4"),Color("#bd5944"),Color("#4f83b6"),Color("#ddd3b9")]
const NAMES=["Giallo","Menta","Ruggine","Blu","Avorio"]

static func data() -> Dictionary:
	return GameState.operations.get("identity",{"name":"Riva Secca","buggy":0,"scooter":1})

static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or not value.get("name") is String or value.name.is_empty() or value.name.length()>24 or value.name!=value.name.strip_edges():
		return false
	for character in value.name:
		if character.unicode_at(0)<32 or character.unicode_at(0)==127:
			return false
	for key in ["buggy","scooter"]:
		if not SaveService._valid_count(value.get(key)) or int(value[key])>=COLORS.size():
			return false
	return true

static func apply(name_value: String, buggy: int, scooter: int, ticket: int) -> bool:
	var value={"name":name_value.strip_edges(),"buggy":buggy,"scooter":scooter}
	if not validate(value) or ticket!=int(GameState.operations.serial):
		return false
	var before: Dictionary=GameState.serialize().duplicate(true)
	GameState.operations.identity=value
	GameState.operations.serial+=1
	return GameState.ops._finish(before)
