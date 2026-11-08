## MainMenu.gd
## Logica menu principale: ospita, unisciti, opzioni, esci.

class_name MainMenu
extends Control

@onready var btn_host: Button = get_node("BgPanel/VBoxContainer/BtnHost")
@onready var btn_join: Button = get_node("BgPanel/VBoxContainer/BtnJoin")
@onready var btn_single: Button = get_node("BgPanel/VBoxContainer/BtnSinglePlayer")
@onready var btn_options: Button = get_node("BgPanel/VBoxContainer/BtnOptions")
@onready var btn_quit: Button = get_node("BgPanel/VBoxContainer/BtnQuit")

@onready var dialog_host: AcceptDialog = get_node("DialogHost")
@onready var dialog_join: AcceptDialog = get_node("DialogJoin")
@onready var input_port_host: LineEdit = get_node("DialogHost/InputPortHost")
@onready var input_ip_join: LineEdit = get_node("DialogJoin/VBoxContainer2/InputIpJoin")
@onready var input_port_join: LineEdit = get_node("DialogJoin/VBoxContainer2/InputPortJoin")
@onready var input_name: LineEdit = get_node("NameDialog/InputName")

# Shared settings dialog
@onready var settings_dialog: SettingsDialog = get_node("SettingsDialog")

var _session: SessionState
var _network: NetworkGateway

func _ready() -> void:
	theme = preload("res://scripts/ui/industrial_theme.gd").create()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	print("[MAIN_MENU] Main menu scene loaded")
	_session = SessionState
	btn_single.text = "ENTRA NELLA DISCARICA"
	btn_single.tooltip_text = "Riprendi il settore e la progressione locale salvati."
	btn_host.text = "Co-op · sperimentale"
	btn_join.text = "Unisciti · sperimentale"
	_network = NetworkGateway

	# Carica nome salvato
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		input_name.text = config.get_value("player", "name", "Player")

	btn_host.pressed.connect(_on_host_pressed)
	btn_join.pressed.connect(_on_join_pressed)
	btn_single.pressed.connect(_on_single_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	dialog_host.confirmed.connect(_on_host_confirmed)
	dialog_join.confirmed.connect(_on_join_confirmed)

	# Settings dialog connections
	settings_dialog.settings_applied.connect(_on_settings_applied)
	settings_dialog.settings_cancelled.connect(_on_settings_cancelled)

	# Connetti segnali sessione
	_session.connection_failed.connect(_on_connection_failed)
	preload("res://scripts/ui/menu_art.gd").main_menu(self)

func _on_host_pressed() -> void:
	input_port_host.text = "24567"
	dialog_host.popup_centered()

func _on_join_pressed() -> void:
	input_ip_join.text = "127.0.0.1"
	input_port_join.text = "24567"
	dialog_join.popup_centered()

func _on_single_pressed() -> void:
	_save_name()
	_session.set_local_name(input_name.text)
	_session.start_single_player()

func _on_options_pressed() -> void:
	# Apri dialog opzioni condiviso
	settings_dialog.show_dialog()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_host_confirmed() -> void:
	var port = input_port_host.text.to_int()
	if port <= 0 or port > 65535:
		_show_error("Porta non valida")
		return

	_save_name()
	_session.set_local_name(input_name.text)
	_session.start_hosting(port)

func _on_join_confirmed() -> void:
	var ip = input_ip_join.text.strip_edges()
	var port = input_port_join.text.to_int()

	if ip.is_empty():
		_show_error("IP non valido")
		return
	if port <= 0 or port > 65535:
		_show_error("Porta non valida")
		return

	_save_name()
	_session.set_local_name(input_name.text)
	_session.start_joining(ip, port)

func _save_name() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("player", "name", input_name.text.left(24))
	config.save("user://settings.cfg")

func _on_connection_failed(reason: String) -> void:
	_show_error("Connessione fallita: %s" % reason)

func _show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.add_button("OK", true)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free.bind())

func _on_settings_applied() -> void:
	print("[MAIN_MENU] Settings applied")

func _on_settings_cancelled() -> void:
	print("[MAIN_MENU] Settings cancelled")
