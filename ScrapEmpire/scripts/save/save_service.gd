## SaveService.gd
## Servizio salvataggio: checkpoint officina, backup, validazione.
## Solo host salva.

extends Node

signal save_completed(success: bool, path: String)
signal load_completed(success: bool, data: Dictionary)
signal backup_created(path: String)

var SAVE_DIR: String = "user://saves/"
const SAVE_PREFIX = "scrapempire_"
const SCHEMA_VERSION = 2
const AUTOSAVE_SECONDS: float = 60.0
var _autosave_elapsed: float = 0.0
var _autosave_retry: float = 0.0
var _last_autosave_epoch: int = -1
var last_save_notice: String = ""
var _last_checkpoint_timestamp: int = 0

# Riferimento all'autoload GameState (inizializzato in _ready)
var _game_state

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_game_state = get_node("/root/GameState")
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# Salva checkpoint officina (dopo missione, acquisto upgrade, nuova campagna)
func save_checkpoint(slot: int = 0, automatic: bool = false) -> bool:
	var data = _game_state.serialize()
	data.save_slot = slot
	_last_checkpoint_timestamp=maxi(_last_checkpoint_timestamp+1,int(Time.get_unix_time_from_system()*1000000))
	data.timestamp=_last_checkpoint_timestamp

	var filename = "%s%s%s_slot%d.json" % [SAVE_PREFIX, data.timestamp,"_auto" if automatic else "",slot]
	var temp_path = "%s%s.tmp" % [SAVE_DIR, filename]
	var final_path = "%s%s" % [SAVE_DIR, filename]

	# Scrivi file temporaneo
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Impossibile creare file temporaneo: %s" % temp_path)
		save_completed.emit(false, "")
		return false

	var json_text = JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()

	# Validazione: rileggi e verifica
	var validate_file = FileAccess.open(temp_path, FileAccess.READ)
	if not validate_file:
		push_error("Impossibile rileggere file per validazione")
		save_completed.emit(false, "")
		return false

	var validate_text = validate_file.get_as_text()
	validate_file.close()

	var parsed = JSON.parse_string(validate_text)
	if not parsed or not _validate_save_schema(parsed):
		var section: String="schema"
		if parsed is Dictionary:
			if parsed.has("operations") and not preload("res://scripts/economy/yard_operations.gd").validate(parsed.operations,_game_state,parsed): section="operations"
			elif parsed.has("local_expedition") and not preload("res://scripts/save/expedition_snapshot.gd").validate(parsed.local_expedition,_game_state,parsed): section="local_expedition"
		push_error("Validazione salvataggio fallita: "+section)
		save_completed.emit(false, "")
		return false

	# Backup precedente se esiste
	var old_file = FileAccess.open(final_path, FileAccess.READ)
	if old_file:
		old_file.close()
		var backup_path = "%s.backup" % final_path
		var dir_access = DirAccess.open(SAVE_DIR)
		if dir_access and dir_access.rename(final_path, backup_path) == OK:
			backup_created.emit(backup_path)

	# Promuovi temporaneo a definitivo
	var dir_access2 = DirAccess.open(SAVE_DIR)
	if not dir_access2 or dir_access2.rename(temp_path, final_path) != OK:
		push_error("Impossibile promuovere file salvataggio")
		save_completed.emit(false, "")
		return false

	if data.has("local_expedition"):
		_game_state.local_travel=data.local_expedition.get("travel",{}).duplicate(true)
	save_completed.emit(true, final_path)
	_autosave_elapsed = 0.0
	_autosave_retry = 0.0
	last_save_notice = "Salvato"
	if automatic:
		_trim_automatic_checkpoints(slot)
	return true

# Carica salvataggio
func load_save(slot: int = 0, timestamp: int = 0) -> bool:
	var filename = ""
	if timestamp > 0:
		filename = "%s%s_slot%d.json" % [SAVE_PREFIX, timestamp, slot]
		if not FileAccess.file_exists(SAVE_DIR+filename):
			filename = "%s%s_auto_slot%d.json" % [SAVE_PREFIX,timestamp,slot]
	else:
		# Trova il più recente per questo slot
		filename = _find_latest_save(slot)
		if filename.is_empty():
			load_completed.emit(false, {})
			return false

	var path = "%s%s" % [SAVE_DIR, filename]
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		load_completed.emit(false, {})
		return false

	var json_text = file.get_as_text()
	file.close()

	var parser = JSON.new()
	var parsed_ok: bool = parser.parse(json_text) == OK
	var data = parser.data if parsed_ok else null
	if not data is Dictionary:
		push_warning("JSON non valido conservato in %s" % path)
		load_completed.emit(false, {})
		return false

	if not _validate_save_schema(data):
		push_error("Schema salvataggio non valido")
		load_completed.emit(false, {})
		return false

	# Applica a GameState
	var success = _game_state.deserialize(data)
	if success:
		_last_checkpoint_timestamp=maxi(_last_checkpoint_timestamp,int(data.get("timestamp",0)))
		load_completed.emit(true, data)
	else:
		load_completed.emit(false, {})

	return success

func _find_latest_save(slot: int) -> String:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return ""

	dir.list_dir_begin()
	var latest = ""
	var latest_time = 0

	while true:
		var fname = dir.get_next()
		if fname.is_empty():
			break
		if fname.begins_with(SAVE_PREFIX) and fname.ends_with("_slot%d.json" % slot):
			# Estrai timestamp dal nome
			var parts = fname.split("_")
			if parts.size() >= 3:
				var time_str = parts[1]
				var time_val = time_str.to_int()
				if time_val > latest_time:
					latest_time = time_val
					latest = fname

	dir.list_dir_end()
	return latest

func _validate_save_schema(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("schema_version"):
		return false
	if not _valid_count(data.schema_version) or int(data.schema_version) not in [1,SCHEMA_VERSION]:
		return false
	if data.has("save_slot") and not _valid_count(data.save_slot):
		return false
	if data.has("timestamp"):
		var timestamp = data.timestamp
		if not (timestamp is int or timestamp is float) or not is_finite(float(timestamp)) or timestamp<0 or timestamp>9007199254740991 or float(timestamp)!=floor(float(timestamp)):
			return false

	# Verifica campi richiesti
	var required = ["team_credits", "team_deposit_counts", "team_upgrade_levels", "unlocked_contracts"]
	for field in required:
		if not data.has(field):
			return false
	var grants = data.get("applied_local_grants", [])
	var orders = data.get("completed_orders", [])
	if not orders is Array or orders.size() > _game_state.order_defs.size():
		return false
	for index in orders.size():
		if not orders[index] is String or orders[index] != _game_state.order_defs[index].id:
			return false
	var discoveries = data.get("secrets_found", [])
	if not discoveries is Array:
		return false
	var secret_ids: Array = []
	for definition in _game_state.secret_defs:
		secret_ids.append(definition.id)
	for id in discoveries:
		if not id is String or id not in secret_ids or discoveries.count(id) != 1:
			return false
	if not grants is Array or grants.size() > 100:
		return false
	for grant in grants:
		if not grant is String or grant.is_empty() or grant.length() > 100 or grants.count(grant) != 1:
			return false
	if not _valid_count(data.team_credits):
		return false
	if not _valid_count(data.get("yard_level", 0)) or data.get("yard_level", 0) > _game_state.land_defs.size():
		return false
	if not _valid_count(data.get("vehicle_level", 0)) or data.get("vehicle_level", 0) > _game_state.vehicle_defs.size():
		return false
	if data.get("vehicle_level", 0) > 0:
		var vehicle: Dictionary = _game_state.vehicle_defs[int(data.vehicle_level) - 1]
		if data.get("yard_level", 0) < int(vehicle.requires_land):
			return false
	if not data.team_deposit_counts is Dictionary or not data.team_upgrade_levels is Dictionary:
		return false
	for material_id in data.team_deposit_counts:
		if not _game_state.material_defs.has(material_id) or not _valid_count(data.team_deposit_counts[material_id]):
			return false
	for material_id in _game_state.material_defs:
		if not data.team_deposit_counts.has(material_id):
			return false
	var modules = data.get("workshop_modules", {})
	if not modules is Dictionary:
		return false
	for id in modules:
		if not _game_state.module_defs.has(id) or not _valid_count(modules[id]) or modules[id] > _game_state.module_defs[id].levels.size():
			return false
		if int(modules[id])>0:
			var definition: Dictionary=_game_state.module_defs[id].levels[int(modules[id])-1]
			if int(definition.get("deliveries",0))>0:
				var progress=data.get("operations",{})
				if not progress is Dictionary or not _valid_count(progress.get("deliveries")) or int(progress.deliveries)<int(definition.deliveries):
					return false
	for category in ["bag", "tool", "movement"]:
		var level = data.team_upgrade_levels.get(category, -1)
		if not _valid_count(level) or level > _game_state._get_upgrade_defs(category).size():
			return false
	if not data.unlocked_contracts is Array:
		return false
	for contract_id in data.unlocked_contracts:
		if not contract_id is String or contract_id not in ["C01", "C02", "C03"]:
			return false
	if data.schema_version == 2:
		var press_data = data.get("press")
		if not press_data is Dictionary or not press_data.get("owned") is bool:
			return false
		if not _valid_count(press_data.get("bales")):
			return false
		var remaining = press_data.get("remaining_seconds")
		if not (remaining is int or remaining is float) or not is_finite(float(remaining)):
			return false
		if remaining < 0 or remaining > float(_game_state.press_def.cycle_seconds):
			return false
		if not press_data.owned and (remaining > 0 or press_data.bales > 0):
			return false
	if data.has("operations") and not preload("res://scripts/economy/yard_operations.gd").validate(data.operations,_game_state,data):
		return false
	for item in data.get("operations",{}).get("crafting",{}).get("objects",{}).values():
		if int(item.get("bales",0))>0 and not data.get("press",{}).get("owned",false): return false
	if data.has("local_expedition") and not preload("res://scripts/save/expedition_snapshot.gd").validate(data.local_expedition,_game_state,data):
		return false
	return true

func _valid_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 1000000000 and float(value) == floor(float(value))

# Lista salvataggi disponibili
func list_saves() -> Array[Dictionary]:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return []

	dir.list_dir_begin()
	var saves: Array[Dictionary] = []

	while true:
		var fname = dir.get_next()
		if fname.is_empty():
			break
		if fname.begins_with(SAVE_PREFIX) and fname.ends_with(".json") and not fname.ends_with(".backup"):
			var path = "%s%s" % [SAVE_DIR, fname]
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var json_text = file.get_as_text()
				file.close()
				var parser = JSON.new()
				var parsed_ok: bool = parser.parse(json_text) == OK
				var data = parser.data if parsed_ok else null
				if _validate_save_schema(data):
					_last_checkpoint_timestamp=maxi(_last_checkpoint_timestamp,int(data.get("timestamp",0)))
					saves.append({
						"filename": fname,
						"path": path,
						"slot": data.save_slot if data.has("save_slot") else 0,
						"timestamp": data.timestamp if data.has("timestamp") else 0,
						"credits": data.team_credits if data.has("team_credits") else 0,
						"upgrades": data.team_upgrade_levels if data.has("team_upgrade_levels") else {}
					})

	dir.list_dir_end()
	# Ordina per timestamp decrescente
	saves.sort_custom(_sort_by_timestamp_desc.bind())
	return saves

func _sort_by_timestamp_desc(a: Dictionary, b: Dictionary) -> bool:
	return a.timestamp > b.timestamp

func _process(delta: float) -> void:
	if _game_state==null or not SessionState.is_single_player_session or SessionState.current_state!=SessionState.ConnectionState.MISSION or get_tree().paused:
		return
	if _last_autosave_epoch!=int(_game_state.operations.epoch):
		_last_autosave_epoch=int(_game_state.operations.epoch)
		_autosave_elapsed=0.0
	_autosave_retry=maxf(0.0,_autosave_retry-delta)
	_autosave_elapsed+=delta
	if _autosave_elapsed>=AUTOSAVE_SECONDS and _autosave_retry<=0:
		if not save_checkpoint(0,true):
			_autosave_retry=30.0
			last_save_notice="Salvataggio automatico non riuscito · riprovo tra 30 s"
			var player = get_tree().get_first_node_in_group("players")
			if player!=null:
				player._notify(last_save_notice)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and save_before_exit():
		get_tree().quit()

func save_before_exit() -> bool:
	if not SessionState.is_single_player_session or SessionState.current_state!=SessionState.ConnectionState.MISSION:
		return true
	var player = get_tree().get_first_node_in_group("players")
	if player!=null:
		player._stop_cart()
		if is_instance_valid(player._dragged):
			player._finish_drag()
	if save_checkpoint():
		return true
	last_save_notice="Chiusura annullata: impossibile salvare. Progressi ancora in memoria."
	if player!=null:
		player._notify(last_save_notice)
	return false

func _trim_automatic_checkpoints(slot: int) -> void:
	# Only our rolling auto files are rotated. Manual/transaction history and corrupt files remain.
	var directory = DirAccess.open(SAVE_DIR)
	if directory==null:
		return
	var history: Array[Dictionary] = []
	for filename in directory.get_files():
		if not filename.begins_with(SAVE_PREFIX) or not filename.ends_with("_auto_slot%d.json" % slot):
			continue
		var timestamp: int = filename.get_slice("_",1).to_int()
		if filename!="%s%d_auto_slot%d.json" % [SAVE_PREFIX,timestamp,slot]:
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(SAVE_DIR+filename))==OK and _validate_save_schema(parser.data):
			history.append({"filename":filename,"timestamp":timestamp})
	history.sort_custom(_sort_by_timestamp_desc)
	for index in range(2,history.size()):
		directory.remove(str(history[index].filename))

# Elimina salvataggio
func delete_save(filename: String) -> bool:
	var path = "%s%s" % [SAVE_DIR, filename]
	if FileAccess.file_exists(path):
		var dir_access = DirAccess.open(SAVE_DIR)
		if dir_access:
			return dir_access.remove_absolute(path) == OK
	return false
# Richiesta locale del proprietario: il checkpoint contiene anche la ricevuta,
# così un riavvio dopo la scrittura non accredita due volte.
func apply_pending_owner_bonus() -> bool:
	var path: String = SAVE_DIR + "owner_bonus.json"
	if not FileAccess.file_exists(path):
		return true
	var pending = JSON.parse_string(FileAccess.get_file_as_string(path))
	var grants: Array = []
	if pending is Dictionary and pending.has("grants") and pending.grants is Array:
		grants = pending.grants
	elif pending is Dictionary:
		grants = [pending]
	else:
		return false
	if grants.size() > 100:
		return false
	for grant in grants:
		if not grant is Dictionary or not grant.get("id") is String or grant.id.is_empty() or grant.id.length() > 100 or not _valid_count(grant.get("amount")) or grant.amount <= 0:
			return false
	var snapshot: Dictionary = _game_state.serialize().duplicate(true)
	var changed: bool = false
	for grant in grants:
		if grant.id in _game_state.applied_local_grants:
			continue
		if _game_state.team_credits + grant.amount > 1000000000 or _game_state.applied_local_grants.size() >= 100:
			_game_state.deserialize(snapshot)
			return false
		_game_state.team_credits += int(grant.amount)
		_game_state.applied_local_grants.append(grant.id)
		changed = true
	if not changed:
		return true
	if not save_checkpoint():
		_game_state.deserialize(snapshot)
		return false
	_game_state.credits_changed.emit(_game_state.team_credits)
	return true

