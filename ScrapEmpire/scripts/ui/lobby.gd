## Lobby.gd
## Logica lobby: roster, ready, avvio missione, stato connessione.

class_name Lobby
extends Control

@onready var label_status: Label = %LabelStatus
@onready var label_ip_port: Label = %LabelIpPort
@onready var input_name: LineEdit = %InputName
@onready var btn_ready: Button = %BtnReady
@onready var btn_start: Button = %BtnStart
@onready var btn_leave: Button = %BtnLeave
@onready var roster_container: VBoxContainer = %RosterContainer
@onready var roster_item_template: HBoxContainer = %RosterItemTemplate
@onready var label_version: Label = %LabelVersion

var _session: SessionState
var _network: NetworkGateway
var _is_ready: bool = false
var _roster_items: Dictionary = {}  # peer_id -> node

func _ready() -> void:
	_session = SessionState
	_network = NetworkGateway

	input_name.text = _session.local_player_name
	input_name.max_length = 24

	btn_ready.pressed.connect(_on_ready_pressed)
	btn_start.pressed.connect(_on_start_pressed)
	btn_leave.pressed.connect(_on_leave_pressed)
	input_name.text_changed.connect(_on_name_changed)

	_session.roster_updated.connect(_on_roster_updated)
	_session.state_changed.connect(_on_state_changed)
	_session.handshake_result.connect(_on_handshake_result)
	_session.mission_starting.connect(_on_mission_starting)
	_session.mission_ended.connect(_on_mission_ended)

	# Nascondi template
	roster_item_template.visible = false

	_update_ui()

func _on_name_changed(new_name: String) -> void:
	_session.set_local_name(new_name)
	_network.send_reliable_rpc("rpc_register_player", [new_name])

func _on_ready_pressed() -> void:
	_is_ready = not _is_ready
	_session.set_ready(_is_ready)
	_update_ready_button()

func _on_start_pressed() -> void:
	if not _session.is_host:
		return

	# Carica scena settore
	var sector = ResourceLoader.load("res://scenes/sector.tscn")
	if sector:
		_session.start_mission(sector)
	else:
		_show_error("Scena settore non trovata")

func _on_leave_pressed() -> void:
	_network.disconnect_from_server()
	_session._cleanup_and_return_to_menu()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_roster_updated(players: Array[Dictionary]) -> void:
	_update_roster_display(players)
	_update_ui()

func _on_state_changed(state_name: String) -> void:
	_update_ui()
	_update_status_label(state_name)

func _on_handshake_result(success: bool, reason: String) -> void:
	if not success:
		_show_error(Localization.text("Handshake fallito: %s") % reason)
		call_deferred("_delayed_return_to_menu")

func _on_mission_starting() -> void:
	get_tree().change_scene_to_file("res://scenes/sector.tscn")

func _on_mission_ended(reason: String) -> void:
	_show_error(Localization.text("Missione terminata: %s") % reason)
	call_deferred("_delayed_return_to_menu")

func _delayed_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_roster_display(players: Array[Dictionary]) -> void:
	# Rimuovi vecchi item
	for peer_id in _roster_items:
		_roster_items[peer_id].queue_free()
	_roster_items.clear()

	# Crea nuovi
	for p in players:
		var item = roster_item_template.duplicate()
		item.visible = true
		roster_container.add_child(item)

		var name_label = item.get_node("NameLabel")
		var ready_check = item.get_node("ReadyCheck")
		var host_badge = item.get_node("HostBadge")

		name_label.text = p.name
		ready_check.button_pressed = p.ready
		ready_check.disabled = true  # Solo lettura
		host_badge.visible = p.is_host

		if p.peer_id == _session.local_peer_id:
			name_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

		_roster_items[p.peer_id] = item

func _update_ui() -> void:
	var is_lobby = _session.current_state == _session.ConnectionState.LOBBY
	var is_host = _session.is_host
	var is_loading = _session.current_state in [_session.ConnectionState.LOADING, _session.ConnectionState.READY]

	btn_ready.visible = is_lobby and not is_loading
	btn_start.visible = is_lobby and is_host and not is_loading
	btn_leave.visible = is_lobby or _session.current_state == _session.ConnectionState.HANDSHAKE

	input_name.editable = is_lobby and not is_loading
	_update_ready_button()

	if is_host:
		label_ip_port.text = "Host su porta 24567"
	else:
		label_ip_port.text = "Connesso all'host"

	label_version.text = "v%s | Proto %d | Hash %s" % [_session.build_id, _session.protocol_version, _session.content_hash.left(8)]

func _update_ready_button() -> void:
	btn_ready.text = "Pronto" if not _is_ready else "Annulla"
	btn_ready.button_pressed = _is_ready

	# Host non ha ready button se è l'unico
	if _session.is_host and _session.players.size() == 1:
		btn_ready.visible = false

func _update_status_label(state_name: String) -> void:
	match state_name:
		"DISCONNECTED": label_status.text = "Disconnesso"
		"CONNECTING": label_status.text = "Connessione..."
		"HANDSHAKE": label_status.text = "Handshake..."
		"LOBBY": label_status.text = "Lobby - In attesa giocatori"
		"LOADING": label_status.text = "Caricamento settore..."
		"READY": label_status.text = "Pronto - Avvio imminente"
		"MISSION": label_status.text = "In missione"
		_: label_status.text = state_name

func _show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.add_button("OK", true)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free.bind())