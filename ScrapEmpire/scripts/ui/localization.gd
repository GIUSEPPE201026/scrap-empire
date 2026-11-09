extends Node
signal language_changed
const SUPPORTED=["it","en"]
var language: String="it"
var settings_path: String="user://settings.cfg"
var _english: Translation
var _italian: Translation

func _ready() -> void:
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/en.json"))
	var repaired: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/it.json"))
	var translation=Translation.new()
	translation.set_locale("en")
	var italian=Translation.new()
	italian.set_locale("it")
	_english=translation
	_italian=italian
	for source in catalog:
		var clean: String=repaired.get(source,source)
		for variant in [[source,catalog[source],clean],[source.to_upper(),str(catalog[source]).to_upper(),clean.to_upper()],[source.to_lower(),str(catalog[source]).to_lower(),clean.to_lower()],[source.capitalize(),str(catalog[source]).capitalize(),clean.capitalize()]]:
			translation.add_message(variant[0],variant[1])
			italian.add_message(variant[0],variant[2])
	for source in repaired:
		if not catalog.has(source):
			translation.add_message(source,repaired[source])
			italian.add_message(source,repaired[source])
	TranslationServer.add_translation(translation)
	TranslationServer.add_translation(italian)
	var config=ConfigFile.new()
	config.load(settings_path)
	set_language(config.get_value("interface","language","it"))

func set_language(value: Variant) -> void:
	language=value if value is String and value in SUPPORTED else "it"
	TranslationServer.set_locale(language)
	language_changed.emit()

func text(value: String) -> String:
	return TranslationServer.translate(value)

func format_text(template: String, values: Array) -> String:
	var arguments: Array=values.duplicate()
	for index in arguments.size():
		if arguments[index] is String: arguments[index]=text(arguments[index])
	return text(template) % arguments

func register_sign(caption: String) -> void:
	if not caption.contains("\n") or not _english.get_message(caption).is_empty(): return
	var lines: PackedStringArray=[]
	for line in caption.split("\n"):
		var translated: String=str(_english.get_message(line))
		lines.append(line if translated.is_empty() else translated)
	_english.add_message(caption,"\n".join(lines))
	_italian.add_message(caption,caption)
