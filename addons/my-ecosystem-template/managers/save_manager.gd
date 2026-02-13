## Usage:
##   SaveManager.game.set_value("health", 15)
##   SaveManager.game.save()
##   var hp = SaveManager.game.get_value("health", 10)
##
##   SaveManager.settings.set_value("high_score", 100)
##   SaveManager.settings.save()
class_name SaveManagerAutoload
extends Node

## Separate domains so reading settings doesn't touch game saves
var game := SaveDomain.new("game_save")
var settings := SaveDomain.new("settings")

## Current schema version — bump when save format changes
const CURRENT_VERSION := 1


func _ready() -> void:
	settings.load_from_disk()
	# Game data loaded on demand, not at startup


func _notification(what: int) -> void:
	# Auto-save on quit / suspend (mobile backgrounding)
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
	or what == NOTIFICATION_APPLICATION_PAUSED:
		save_all()


func save_all() -> void:
	game.save()
	settings.save()


func has_game_save() -> bool:
	if game.is_loaded and not game.data.is_empty():
		return true
	return FileAccess.file_exists(game._get_path())


func clear_game_save() -> void:
	game.clear()


func get_high_score() -> int:
	return settings.get_value("high_score", 0)


func set_high_score(value: int) -> void:
	settings.set_value("high_score", value)
	settings.save()


func is_tutorial_completed() -> bool:
	return settings.get_value("tutorial_completed", false)


func set_tutorial_completed(value: bool) -> void:
	settings.set_value("tutorial_completed", value)
	settings.save()
