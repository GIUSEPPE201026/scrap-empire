## Boot.gd
## Entry point: carica il menu principale

extends Node

func _ready() -> void:
	var collect_event = InputEventMouseButton.new()
	collect_event.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_erase_events("collect")
	InputMap.action_add_event("collect", collect_event)
	var pause_event = InputEventKey.new()
	pause_event.keycode = KEY_ESCAPE
	InputMap.action_erase_events("pause")
	InputMap.action_add_event("pause", pause_event)
	print("[BOOT] Boot scene loaded, changing to main_menu")
	# Carica scena menu principale
	call_deferred("_change_scene")

func _change_scene() -> void:
	print("[BOOT] Changing scene to main_menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
