## SettingsDialog.gd
## Shared settings dialog for main menu and pause menu

class_name SettingsDialog
extends PopupPanel

# Signals
signal settings_applied
signal settings_cancelled

# Settings storage
var _settings: Dictionary = {}
var settings_path: String = Localization.settings_path
var _pending_keybind_action: String = ""
var _keybind_waiting: bool = false
var _applied_close: bool = false
var _requested_window_mode: int=Window.MODE_WINDOWED
var _fullscreen_check: CheckButton
var _language_options: OptionButton

# Node references (will be set in _ready)
var _tab_container: TabContainer
var _quality_options: OptionButton
var _vsync_options: OptionButton
var _fov_slider: HSlider
var _fov_value: Label
var _master_slider: HSlider
var _master_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label
var _music_slider: HSlider
var _music_value: Label
var _sensitivity_slider: HSlider
var _sensitivity_value: Label
var _invert_y_check: CheckButton
var _btn_reset_defaults: Button
var _btn_apply: Button
var _btn_cancel: Button

# Keybind buttons
var _key_move_forward: Button
var _key_move_back: Button
var _key_move_left: Button
var _key_move_right: Button
var _key_jump: Button
var _key_sprint: Button
var _key_interact: Button
var _key_recovery_mode: Button

func _ready() -> void:
	theme = preload("res://scripts/ui/industrial_theme.gd").create()
	add_theme_stylebox_override("panel", theme.get_stylebox("panel", "PopupPanel"))
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	_setup_node_references()
	_organize_controls()
	_load_settings()
	_populate_dialog()
	_connect_signals()

	# Close button handling
	popup_hide.connect(_on_closed)

func _organize_controls() -> void:
	var art = preload("res://scripts/ui/menu_art.gd")
	var language_row=HBoxContainer.new()
	language_row.custom_minimum_size.y=48
	var language_label=Label.new()
	language_label.text="Lingua / Language"
	language_label.custom_minimum_size.x=150
	language_row.add_child(language_label)
	_language_options=OptionButton.new()
	_language_options.name="LanguageOptions"
	_language_options.add_item("Italiano",0)
	_language_options.add_item("English",1)
	_language_options.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	language_row.add_child(_language_options)
	_tab_container.get_node("Graphics").add_child(language_row)
	_tab_container.get_node("Graphics").move_child(language_row,0)
	_language_options.item_selected.connect(func(index):_settings.language=["it","en"][index])
	_fullscreen_check=CheckButton.new()
	_fullscreen_check.text="Schermo intero · questa sessione"
	_fullscreen_check.custom_minimum_size.y=42
	_tab_container.get_node("Graphics").add_child(_fullscreen_check)
	_fullscreen_check.toggled.connect(func(checked):_requested_window_mode=Window.MODE_EXCLUSIVE_FULLSCREEN if checked else Window.MODE_WINDOWED)
	for index in 3:
		_tab_container.set_tab_icon(index,art.SYMBOLS.icon(["light","settings","person"][index]))
	_tab_container.add_theme_constant_override("icon_max_width",22)
	for entry in [["Graphics","QualityLabel",_quality_options,null,"Qualità"],["Graphics","VSyncLabel",_vsync_options,null,"VSync"],["Graphics","FOVLabel",_fov_slider,_fov_value,"Campo visivo"],["Audio","MasterLabel",_master_slider,_master_value,"Generale"],["Audio","SFXLabel",_sfx_slider,_sfx_value,"Effetti"],["Audio","MusicLabel",_music_slider,_music_value,"Musica"],["Controls","SensitivityLabel",_sensitivity_slider,_sensitivity_value,"Sensibilità"]]:
		var page: Node = _tab_container.get_node(entry[0])
		var caption: Label = page.get_node(entry[1])
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		row.custom_minimum_size.y=48
		page.add_child(row)
		page.move_child(row,caption.get_index())
		caption.reparent(row)
		caption.text=entry[4]
		caption.custom_minimum_size.x=150
		caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var control: Control=entry[2]
		control.reparent(row)
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		if entry[3]!=null:
			var value: Label=entry[3]
			value.reparent(row)
			value.custom_minimum_size.x=65
			value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var controls: Node=_tab_container.get_node("Controls")
	controls.get_node("InvertYLabel").hide()
	_invert_y_check.text="Inverti verticale"
	controls.get_node("KeybindsLabel").text="Tasti"
	var bindings: Node=controls.get_node("KeybindContainer")
	var grid=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",24)
	grid.add_theme_constant_override("v_separation",6)
	controls.add_child(grid)
	for row in bindings.get_children():
		if row.name=="Interact":
			row.get_node("ActionLabel").text="Interagisci"
		row.reparent(grid)
		row.custom_minimum_size=Vector2(275,36)
		row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bindings.hide()
	_btn_reset_defaults.text="Ripristina"
	art.button_style(_btn_reset_defaults)
	art.button_style(_btn_cancel)
	art.button_style(_btn_apply,true)

func _setup_node_references() -> void:
	_tab_container = get_node("VBoxContainer/TabContainer")
	_tab_container.set_tab_title(0, "GRAFICA")
	_tab_container.set_tab_title(1, "AUDIO")
	_tab_container.set_tab_title(2, "COMANDI")
	_quality_options = get_node("VBoxContainer/TabContainer/Graphics/QualityOptions")
	_vsync_options = get_node("VBoxContainer/TabContainer/Graphics/VSyncOptions")
	_fov_slider = get_node("VBoxContainer/TabContainer/Graphics/FOVSlider")
	_fov_value = get_node("VBoxContainer/TabContainer/Graphics/FOVValue")
	_master_slider = get_node("VBoxContainer/TabContainer/Audio/MasterSlider")
	_master_value = get_node("VBoxContainer/TabContainer/Audio/MasterValue")
	_sfx_slider = get_node("VBoxContainer/TabContainer/Audio/SFXSlider")
	_sfx_value = get_node("VBoxContainer/TabContainer/Audio/SFXValue")
	_music_slider = get_node("VBoxContainer/TabContainer/Audio/MusicSlider")
	_music_value = get_node("VBoxContainer/TabContainer/Audio/MusicValue")
	_sensitivity_slider = get_node("VBoxContainer/TabContainer/Controls/SensitivitySlider")
	_sensitivity_value = get_node("VBoxContainer/TabContainer/Controls/SensitivityValue")
	_invert_y_check = get_node("VBoxContainer/TabContainer/Controls/InvertYCheck")
	_btn_reset_defaults = get_node("VBoxContainer/ButtonContainer/BtnResetDefaults")
	_btn_apply = get_node("VBoxContainer/ButtonContainer/BtnApply")
	_btn_cancel = get_node("VBoxContainer/ButtonContainer/BtnCancel")

	# Keybind buttons
	_key_move_forward = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/MoveForward/KeyButton")
	_key_move_back = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/MoveBack/KeyButton")
	_key_move_left = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/MoveLeft/KeyButton")
	_key_move_right = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/MoveRight/KeyButton")
	_key_jump = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/Jump/KeyButton")
	_key_sprint = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/Sprint/KeyButton")
	_key_interact = get_node("VBoxContainer/TabContainer/Controls/KeybindContainer/Interact/KeyButton")
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = "Modalità recupero"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_key_recovery_mode = Button.new()
	_key_recovery_mode.custom_minimum_size.x = 110
	row.add_child(_key_recovery_mode)
	get_node("VBoxContainer/TabContainer/Controls/KeybindContainer").add_child(row)

func _connect_signals() -> void:
	# Sliders
	_fov_slider.value_changed.connect(_on_fov_changed)
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_invert_y_check.toggled.connect(_on_invert_y_toggled)

	# Buttons
	_btn_reset_defaults.pressed.connect(_on_reset_defaults)
	_btn_apply.pressed.connect(_on_apply_pressed)
	_btn_cancel.pressed.connect(_on_cancel_pressed)

	# Keybind buttons
	_key_move_forward.pressed.connect(_on_keybind_pressed.bind("move_forward"))
	_key_move_back.pressed.connect(_on_keybind_pressed.bind("move_back"))
	_key_move_left.pressed.connect(_on_keybind_pressed.bind("move_left"))
	_key_move_right.pressed.connect(_on_keybind_pressed.bind("move_right"))
	_key_jump.pressed.connect(_on_keybind_pressed.bind("jump"))
	_key_sprint.pressed.connect(_on_keybind_pressed.bind("sprint"))
	_key_interact.pressed.connect(_on_keybind_pressed.bind("interact"))
	_key_recovery_mode.pressed.connect(_on_keybind_pressed.bind("recovery_mode"))

	# Dropdowns
	_quality_options.item_selected.connect(_on_quality_changed)
	_vsync_options.item_selected.connect(_on_vsync_changed)

func _load_settings() -> void:
	_requested_window_mode=get_tree().root.mode
	var config = ConfigFile.new()
	_settings.language="it"
	if config.load(settings_path) == OK:
		var language=config.get_value("interface","language","it")
		_settings.language=language if language is String and language in Localization.SUPPORTED else "it"
		_settings.graphics_quality = config.get_value("graphics", "quality", 2)
		_settings.vsync = config.get_value("graphics", "vsync", 1)
		_settings.fov = config.get_value("graphics", "fov", 80.0)
		_settings.master_volume = config.get_value("audio", "master_volume", 1.0)
		_settings.sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		_settings.music_volume = config.get_value("audio", "music_volume", 0.7)
		_settings.mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 0.002)
		_settings.invert_y = config.get_value("controls", "invert_y", false)
		_settings.key_move_forward = config.get_value("controls", "key_move_forward", "W")
		_settings.key_move_back = config.get_value("controls", "key_move_back", "S")
		_settings.key_move_left = config.get_value("controls", "key_move_left", "A")
		_settings.key_move_right = config.get_value("controls", "key_move_right", "D")
		_settings.key_jump = config.get_value("controls", "key_jump", "Spazio")
		_settings.key_sprint = config.get_value("controls", "key_sprint", "Shift")
		_settings.key_interact = config.get_value("controls", "key_interact", "E")
		_settings.key_recovery_mode = config.get_value("controls", "key_recovery_mode", "R")
	else:
		# Default settings
		_settings.graphics_quality = 2
		_settings.vsync = 1
		_settings.fov = 80.0
		_settings.master_volume = 1.0
		_settings.sfx_volume = 1.0
		_settings.music_volume = 0.7
		_settings.mouse_sensitivity = 0.002
		_settings.invert_y = false
		_settings.key_move_forward = "W"
		_settings.key_move_back = "S"
		_settings.key_move_left = "A"
		_settings.key_move_right = "D"
		_settings.key_jump = "Spazio"
		_settings.key_sprint = "Shift"
		_settings.key_interact = "E"
		_settings.key_recovery_mode = "R"

	# Preserve existing user bindings when the new action takes an unused default.
	var occupied: Array = []
	for action in ["move_forward","move_back","move_left","move_right","jump","sprint","interact"]:
		occupied.append(_settings["key_"+action])
	if _settings.get("key_recovery_mode","R") in occupied:
		for candidate in ["R","G","V","B","N"]:
			if candidate not in occupied:
				_settings.key_recovery_mode = candidate
				break
	# Apply keybinds to InputMap on startup
	_apply_keybinds()

func _save_settings() -> bool:
	var config = ConfigFile.new()
	config.load(settings_path)
	config.set_value("interface","language",_settings.language)
	config.set_value("graphics", "quality", _settings.graphics_quality)
	config.set_value("graphics", "vsync", _settings.vsync)
	config.set_value("graphics", "fov", _settings.fov)
	config.set_value("audio", "master_volume", _settings.master_volume)
	config.set_value("audio", "sfx_volume", _settings.sfx_volume)
	config.set_value("audio", "music_volume", _settings.music_volume)
	config.set_value("controls", "mouse_sensitivity", _settings.mouse_sensitivity)
	config.set_value("controls", "invert_y", _settings.invert_y)
	config.set_value("controls", "key_move_forward", _settings.key_move_forward)
	config.set_value("controls", "key_move_back", _settings.key_move_back)
	config.set_value("controls", "key_move_left", _settings.key_move_left)
	config.set_value("controls", "key_move_right", _settings.key_move_right)
	config.set_value("controls", "key_jump", _settings.key_jump)
	config.set_value("controls", "key_sprint", _settings.key_sprint)
	config.set_value("controls", "key_interact", _settings.key_interact)
	config.set_value("controls", "key_recovery_mode", _settings.key_recovery_mode)
	return config.save(settings_path) == OK

func _populate_dialog() -> void:
	_language_options.select(1 if _settings.language=="en" else 0)
	_fullscreen_check.set_pressed_no_signal(_requested_window_mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN])
	# Setup dropdown options
	_setup_dropdowns()

	# Populate with current settings
	_quality_options.selected = _settings.graphics_quality
	_vsync_options.selected = _settings.vsync
	_fov_slider.value = _settings.fov
	_on_fov_changed(_settings.fov)
	_master_slider.value = _settings.master_volume
	_on_master_volume_changed(_settings.master_volume)
	_sfx_slider.value = _settings.sfx_volume
	_on_sfx_volume_changed(_settings.sfx_volume)
	_music_slider.value = _settings.music_volume
	_on_music_volume_changed(_settings.music_volume)
	_sensitivity_slider.value = _settings.mouse_sensitivity
	_on_sensitivity_changed(_settings.mouse_sensitivity)
	_invert_y_check.button_pressed = _settings.invert_y

	# Update keybind buttons
	_key_move_forward.text = _settings.key_move_forward
	_key_move_back.text = _settings.key_move_back
	_key_move_left.text = _settings.key_move_left
	_key_move_right.text = _settings.key_move_right
	_key_jump.text = _settings.key_jump
	_key_sprint.text = _settings.key_sprint
	_key_interact.text = _settings.key_interact
	_key_recovery_mode.text = _settings.key_recovery_mode

	# Apply current settings immediately (preview)
	_apply_settings_to_engine()

func _setup_dropdowns() -> void:
	# Quality options
	_quality_options.clear()
	_quality_options.add_item("Bassa")
	_quality_options.add_item("Media")
	_quality_options.add_item("Alta")
	_quality_options.add_item("Ultra")

	# VSync options
	_vsync_options.clear()
	_vsync_options.add_item("Disattivato")
	_vsync_options.add_item("Attivato")
	_vsync_options.add_item("Adattivo")

func _apply_settings_to_engine() -> void:
	Localization.set_language(_settings.language)
	_tab_container.set_tab_title(0,Localization.text("GRAFICA"))
	_tab_container.set_tab_title(1,Localization.text("AUDIO"))
	_tab_container.set_tab_title(2,Localization.text("COMANDI"))
	get_tree().root.msaa_3d = int(_settings.graphics_quality)
	# Apply graphics settings
	# FOV will be applied when player spawns
	# VSync
	DisplayServer.window_set_vsync_mode(_settings.vsync)
	# Audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(_settings.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(_settings.sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(_settings.music_volume))

func _apply_keybinds() -> void:
	# Update InputMap with new keybinds
	var input_map = InputMap

	# Action name to settings key mapping
	var action_map = {
		"move_forward": "key_move_forward",
		"move_back": "key_move_back",
		"move_left": "key_move_left",
		"move_right": "key_move_right",
		"jump": "key_jump",
		"sprint": "key_sprint",
		"interact": "key_interact",
		"recovery_mode": "key_recovery_mode"
	}

	for action_name in action_map:
		if not input_map.has_action(action_name):
			input_map.add_action(action_name)
		var settings_key = action_map[action_name]
		var key_name = _settings[settings_key]
		var keycode = _get_keycode_from_name(key_name)

		if keycode != -1:
			# Remove existing events for this action
			var events = input_map.action_get_events(action_name)
			for event in events:
				input_map.action_erase_event(action_name, event)

			# Add new event
			var new_event = InputEventKey.new()
			new_event.keycode = keycode
			new_event.pressed = true
			input_map.action_add_event(action_name, new_event)

			print("[SETTINGS] Applied keybind: %s -> %s (keycode: %d)" % [action_name, key_name, keycode])

func _get_keycode_from_name(key_name: String) -> int:
	match key_name:
		"A": return KEY_A
		"B": return KEY_B
		"C": return KEY_C
		"D": return KEY_D
		"E": return KEY_E
		"F": return KEY_F
		"G": return KEY_G
		"H": return KEY_H
		"I": return KEY_I
		"J": return KEY_J
		"K": return KEY_K
		"L": return KEY_L
		"M": return KEY_M
		"N": return KEY_N
		"O": return KEY_O
		"P": return KEY_P
		"Q": return KEY_Q
		"R": return KEY_R
		"S": return KEY_S
		"T": return KEY_T
		"U": return KEY_U
		"V": return KEY_V
		"W": return KEY_W
		"X": return KEY_X
		"Y": return KEY_Y
		"Z": return KEY_Z
		"0": return KEY_0
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"7": return KEY_7
		"8": return KEY_8
		"9": return KEY_9
		"Spazio": return KEY_SPACE
		"Shift": return KEY_SHIFT
		"Ctrl": return KEY_CTRL
		"Alt": return KEY_ALT
		"Tab": return KEY_TAB
		"Esc": return KEY_ESCAPE
		"Invio": return KEY_ENTER
		"Backspace": return KEY_BACKSPACE
		"Del": return KEY_DELETE
		"Ins": return KEY_INSERT
		"Home": return KEY_HOME
		"End": return KEY_END
		"PgUp": return KEY_PAGEUP
		"PgDn": return KEY_PAGEDOWN
		"Su": return KEY_UP
		"Giù": return KEY_DOWN
		"Sinistra": return KEY_LEFT
		"Destra": return KEY_RIGHT
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
		"Num0": return KEY_KP_0
		"Num1": return KEY_KP_1
		"Num2": return KEY_KP_2
		"Num3": return KEY_KP_3
		"Num4": return KEY_KP_4
		"Num5": return KEY_KP_5
		"Num6": return KEY_KP_6
		"Num7": return KEY_KP_7
		"Num8": return KEY_KP_8
		"Num9": return KEY_KP_9
		"Num.": return KEY_KP_PERIOD
		"Num/": return KEY_KP_DIVIDE
		"Num*": return KEY_KP_MULTIPLY
		"Num-": return KEY_KP_SUBTRACT
		"Num+": return KEY_KP_ADD
		"NumInvio": return KEY_KP_ENTER
		"<": return KEY_LESS
		">": return KEY_GREATER
		"?": return KEY_QUESTION
		"@": return KEY_AT
		":": return KEY_COLON
		"\"": return KEY_APOSTROPHE
		"\\": return KEY_BACKSLASH
		"|": return KEY_BAR
		",": return KEY_COMMA
		".": return KEY_PERIOD
		"/": return KEY_SLASH
		";": return KEY_SEMICOLON
		"=": return KEY_EQUAL
		"-": return KEY_MINUS
		"[": return KEY_BRACKETLEFT
		"]": return KEY_BRACKETRIGHT
		_: return -1

func _get_key_name(keycode: int) -> String:
	match keycode:
		KEY_A: return "A"
		KEY_B: return "B"
		KEY_C: return "C"
		KEY_D: return "D"
		KEY_E: return "E"
		KEY_F: return "F"
		KEY_G: return "G"
		KEY_H: return "H"
		KEY_I: return "I"
		KEY_J: return "J"
		KEY_K: return "K"
		KEY_L: return "L"
		KEY_M: return "M"
		KEY_N: return "N"
		KEY_O: return "O"
		KEY_P: return "P"
		KEY_Q: return "Q"
		KEY_R: return "R"
		KEY_S: return "S"
		KEY_T: return "T"
		KEY_U: return "U"
		KEY_V: return "V"
		KEY_W: return "W"
		KEY_X: return "X"
		KEY_Y: return "Y"
		KEY_Z: return "Z"
		KEY_0: return "0"
		KEY_1: return "1"
		KEY_2: return "2"
		KEY_3: return "3"
		KEY_4: return "4"
		KEY_5: return "5"
		KEY_6: return "6"
		KEY_7: return "7"
		KEY_8: return "8"
		KEY_9: return "9"
		KEY_SPACE: return "Spazio"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
		KEY_ESCAPE: return "Esc"
		KEY_ENTER: return "Invio"
		KEY_BACKSPACE: return "Backspace"
		KEY_DELETE: return "Del"
		KEY_INSERT: return "Ins"
		KEY_HOME: return "Home"
		KEY_END: return "End"
		KEY_PAGEUP: return "PgUp"
		KEY_PAGEDOWN: return "PgDn"
		KEY_UP: return "Su"
		KEY_DOWN: return "Giù"
		KEY_LEFT: return "Sinistra"
		KEY_RIGHT: return "Destra"
		KEY_F1: return "F1"
		KEY_F2: return "F2"
		KEY_F3: return "F3"
		KEY_F4: return "F4"
		KEY_F5: return "F5"
		KEY_F6: return "F6"
		KEY_F7: return "F7"
		KEY_F8: return "F8"
		KEY_F9: return "F9"
		KEY_F10: return "F10"
		KEY_F11: return "F11"
		KEY_F12: return "F12"
		KEY_KP_0: return "Num0"
		KEY_KP_1: return "Num1"
		KEY_KP_2: return "Num2"
		KEY_KP_3: return "Num3"
		KEY_KP_4: return "Num4"
		KEY_KP_5: return "Num5"
		KEY_KP_6: return "Num6"
		KEY_KP_7: return "Num7"
		KEY_KP_8: return "Num8"
		KEY_KP_9: return "Num9"
		KEY_KP_PERIOD: return "Num."
		KEY_KP_DIVIDE: return "Num/"
		KEY_KP_MULTIPLY: return "Num*"
		KEY_KP_SUBTRACT: return "Num-"
		KEY_KP_ADD: return "Num+"
		KEY_KP_ENTER: return "NumInvio"
		KEY_LESS: return "<"
		KEY_GREATER: return ">"
		KEY_QUESTION: return "?"
		KEY_AT: return "@"
		KEY_COLON: return ":"
		KEY_APOSTROPHE: return "\""
		KEY_BACKSLASH: return "\\"
		KEY_BAR: return "|"
		KEY_COMMA: return ","
		KEY_PERIOD: return "."
		KEY_SLASH: return "/"
		KEY_SEMICOLON: return ";"
		KEY_EQUAL: return "="
		KEY_MINUS: return "-"
		KEY_BRACKETLEFT: return "["
		KEY_BRACKETRIGHT: return "]"
		_: return ""

# Signal handlers
func _on_closed() -> void:
	_cancel_keybind()
	_load_settings()
	_apply_settings_to_engine()
	if not _applied_close:
		settings_cancelled.emit()

func _on_reset_defaults() -> void:
	_cancel_keybind()
	_requested_window_mode=Window.MODE_WINDOWED
	_settings.language="it"
	_settings.graphics_quality = 2
	_settings.vsync = 1
	_settings.fov = 80.0
	_settings.master_volume = 1.0
	_settings.sfx_volume = 1.0
	_settings.music_volume = 0.7
	_settings.mouse_sensitivity = 0.002
	_settings.invert_y = false
	_settings.key_move_forward = "W"
	_settings.key_move_back = "S"
	_settings.key_move_left = "A"
	_settings.key_move_right = "D"
	_settings.key_jump = "Spazio"
	_settings.key_sprint = "Shift"
	_settings.key_interact = "E"
	_settings.key_recovery_mode = "R"
	_populate_dialog()

func _on_apply_pressed() -> void:
	_cancel_keybind()
	if not _save_settings():
		_btn_apply.text = "Errore salvataggio"
		return
	_apply_keybinds()
	_apply_settings_to_engine()
	_applied_close = true
	var window: Window=get_tree().root
	var requested_mode: int=_requested_window_mode
	settings_applied.emit()
	hide()
	window.set_deferred("mode",requested_mode)

func _on_cancel_pressed() -> void:
	hide()

func _on_fov_changed(value: float) -> void:
	_settings.fov = value
	_fov_value.text = "%d°" % [int(value)]

func _on_master_volume_changed(value: float) -> void:
	_settings.master_volume = value
	_master_value.text = "%d%%" % [int(value * 100)]
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_sfx_volume_changed(value: float) -> void:
	_settings.sfx_volume = value
	_sfx_value.text = "%d%%" % [int(value * 100)]
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

func _on_music_volume_changed(value: float) -> void:
	_settings.music_volume = value
	_music_value.text = "%d%%" % [int(value * 100)]
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))

func _on_sensitivity_changed(value: float) -> void:
	_settings.mouse_sensitivity = value
	_sensitivity_value.text = "%.4f" % [value]

func _on_invert_y_toggled(pressed: bool) -> void:
	_settings.invert_y = pressed

func _on_quality_changed(idx: int) -> void:
	_settings.graphics_quality = idx
	get_tree().root.msaa_3d = idx
	# Apply quality settings
	var quality_names = ["Low", "Medium", "High", "Ultra"]
	# Quality settings would be applied here (e.g., RenderingServer.set_debug_generate_wireframes, etc.)
	# For now just store the setting

func _on_vsync_changed(idx: int) -> void:
	_settings.vsync = idx
	DisplayServer.window_set_vsync_mode(idx)

func _on_keybind_pressed(action: String) -> void:
	_cancel_keybind()
	_pending_keybind_action = action
	_keybind_waiting = true

	# Update button text to show waiting
	var btn = _get_keybind_button(action)
	if btn:
		btn.text = "Premi un tasto..."
		btn.disabled = true

	# Capture next key press
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _get_keybind_button(action: String) -> Button:
	match action:
		"move_forward": return _key_move_forward
		"move_back": return _key_move_back
		"move_left": return _key_move_left
		"move_right": return _key_move_right
		"jump": return _key_jump
		"sprint": return _key_sprint
		"interact": return _key_interact
		"recovery_mode": return _key_recovery_mode
	return null

func _input(event: InputEvent) -> void:
	if _keybind_waiting and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_cancel_keybind()
			return
		var key_name = _get_key_name(event.keycode)
		if key_name:
			for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "interact", "recovery_mode"]:
				if action != _pending_keybind_action and _settings["key_" + action] == key_name:
					_get_keybind_button(_pending_keybind_action).text = Localization.text("Gia usato: ") + Localization.text(key_name)
					return
			if event.keycode in [KEY_TAB, KEY_I, KEY_1, KEY_2, KEY_3, KEY_4]:
				_get_keybind_button(_pending_keybind_action).text = "Tasto riservato"
				return
			_settings["key_" + _pending_keybind_action] = key_name
			var btn = _get_keybind_button(_pending_keybind_action)
			if btn:
				btn.text = key_name
				btn.disabled = false
			_keybind_waiting = false
			_pending_keybind_action = ""
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			get_viewport().set_input_as_handled()

func _cancel_keybind() -> void:
	if not _pending_keybind_action.is_empty():
		var button = _get_keybind_button(_pending_keybind_action)
		button.disabled = false
		button.text = _settings["key_" + _pending_keybind_action]
	_keybind_waiting = false
	_pending_keybind_action = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	# log10 not available in GDScript, use log(linear) / log(10)
	return 20.0 * (log(linear) / log(10.0))

# Public method to open the dialog
func show_dialog() -> void:
	_applied_close = false
	_btn_apply.text = "Applica"
	_load_settings()
	_populate_dialog()
	popup_centered()
