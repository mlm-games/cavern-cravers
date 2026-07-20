## A single save file domain. Handles atomic writes, backups, and JSON serialization.
## Not meant to be used directly — access through SaveManager.
class_name SaveDomain
extends RefCounted

const SAVE_DIR := "user://saves/"
const CURRENT_VERSION := 1

var domain_name: String
var data: Dictionary = {}
var is_loaded: bool = false
var _dirty: bool = false


func _init(p_domain_name: String) -> void:
	domain_name = p_domain_name


func _get_path() -> String:
	return SAVE_DIR + domain_name + ".json"


func _get_backup_path() -> String:
	return SAVE_DIR + domain_name + ".json.bak"


func _get_temp_path() -> String:
	return SAVE_DIR + domain_name + ".json.tmp"


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	_dirty = true


func get_value(key: String, default: Variant = null) -> Variant:
	if not is_loaded:
		load_from_disk()
	return data.get(key, default)


func erase_value(key: String) -> void:
	data.erase(key)
	_dirty = true


func set_dict(key: String, dict: Dictionary) -> void:
	data[key] = dict
	_dirty = true


func get_dict(key: String) -> Dictionary:
	if not is_loaded:
		load_from_disk()
	var val = data.get(key, {})
	return val if val is Dictionary else {}


func clear() -> void:
	data.clear()
	is_loaded = true
	_dirty = true
	save()
	# Also remove the file
	var path := _get_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var backup := _get_backup_path()
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)


func save() -> bool:
	if not _dirty and is_loaded:
		return true

	_ensure_save_dir()

	var save_wrapper := {
		"version": CURRENT_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data,
	}

	var json_string := JSON.stringify(save_wrapper, "\t")
	var temp_path := _get_temp_path()
	var final_path := _get_path()
	var backup_path := _get_backup_path()

	# Write to temp file first (atomic write pattern)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("SaveDomain[%s]: Failed to open temp file: %s" % [domain_name, temp_path])
		return false

	file.store_string(json_string)
	file.flush()
	file.close()

	# Verify the temp file is valid before replacing
	if not _verify_file(temp_path):
		push_error("SaveDomain[%s]: Temp file verification failed, aborting save." % domain_name)
		DirAccess.remove_absolute(temp_path)
		return false

	# Rotate: current -> backup, temp -> current
	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		DirAccess.rename_absolute(final_path, backup_path)

	DirAccess.rename_absolute(temp_path, final_path)

	_dirty = false
	return true


func load_from_disk() -> bool:
	is_loaded = true

	var path := _get_path()

	if not FileAccess.file_exists(path):
		# Try backup
		var backup := _get_backup_path()
		if FileAccess.file_exists(backup):
			push_warning("SaveDomain[%s]: Main file missing, restoring from backup." % domain_name)
			DirAccess.rename_absolute(backup, path)
		else:
			data = {}
			return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveDomain[%s]: Failed to open file: %s" % [domain_name, path])
		return _try_load_backup()

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("SaveDomain[%s]: JSON parse error: %s" % [domain_name, json.get_error_message()])
		return _try_load_backup()

	var parsed = json.data
	if not parsed is Dictionary:
		push_error("SaveDomain[%s]: Root is not a Dictionary." % domain_name)
		return _try_load_backup()

	var version: int = parsed.get("version", 0)
	data = parsed.get("data", {})

	if version < CURRENT_VERSION:
		_migrate(version)
		_dirty = true # after migration

	return true



func _try_load_backup() -> bool:
	var backup := _get_backup_path()
	if not FileAccess.file_exists(backup):
		data = {}
		return false

	push_warning("SaveDomain[%s]: Attempting backup recovery." % domain_name)
	var final_path := _get_path()
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path)
	DirAccess.rename_absolute(backup, final_path)
	return load_from_disk()


func _verify_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	return json.parse(text) == OK and json.data is Dictionary


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _migrate(_from_version: int) -> void:
	# TODO: as the format evolves:
	# if from_version < 2:
	#     data["new_field"] = data.get("old_field", default)
	#     data.erase("old_field")
	pass
