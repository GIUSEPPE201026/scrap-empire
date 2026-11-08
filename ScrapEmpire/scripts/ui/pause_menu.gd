## PauseMenu.gd
## Menu pausa stilizzato per Scrap Empire

extends PopupPanel

@onready var _resume_btn: Button = get_node("Panel/VBoxContainer/ResumeButton")
@onready var _mission_status_btn: Button = get_node("Panel/VBoxContainer/MissionStatusButton")
@onready var _upgrades_btn: Button = get_node("Panel/VBoxContainer/UpgradesButton")
@onready var _settings_btn: Button = get_node("Panel/VBoxContainer/SettingsButton")
@onready var _abandon_btn: Button = get_node("Panel/VBoxContainer/AbandonButton")
@onready var _quit_btn: Button = get_node("Panel/VBoxContainer/QuitButton")

signal resume_requested
signal mission_status_requested
signal upgrades_requested
signal settings_requested
signal abandon_mission_requested
signal quit_to_menu_requested

func _ready() -> void:
	_resume_btn.pressed.connect(_on_resume_pressed)
	_mission_status_btn.pressed.connect(_on_mission_status_pressed)
	_upgrades_btn.pressed.connect(_on_upgrades_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_abandon_btn.pressed.connect(_on_abandon_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	# Focus sul pulsante Riprendi
	_resume_btn.grab_focus()

func _on_resume_pressed() -> void:
	hide()
	resume_requested.emit()

func _on_mission_status_pressed() -> void:
	hide()
	mission_status_requested.emit()

func _on_upgrades_pressed() -> void:
	hide()
	upgrades_requested.emit()

func _on_settings_pressed() -> void:
	hide()
	settings_requested.emit()

func _on_abandon_pressed() -> void:
	hide()
	abandon_mission_requested.emit()

func _on_quit_pressed() -> void:
	hide()
	quit_to_menu_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		# ESC chiude il menu pausa
		_on_resume_pressed()