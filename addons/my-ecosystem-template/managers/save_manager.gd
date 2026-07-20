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

const MODE_ADJACENT := "adjacent"
const MODE_COMBINED := "combined"
const MODE_DIAGONAL := "diagonal"
const ALL_MODES := [MODE_ADJACENT, MODE_COMBINED, MODE_DIAGONAL]


func _ready() -> void:
	settings.load_from_disk()
	_migrate_legacy_high_score()
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


func _migrate_legacy_high_score() -> void:
	## Move old single high_score into per-mode adjacent entry once.
	var legacy = settings.get_value("high_score", null)
	if legacy == null:
		return
	var scores: Dictionary = settings.get_value("high_scores", {})
	if not scores is Dictionary:
		scores = {}
	if not scores.has(MODE_ADJACENT):
		scores[MODE_ADJACENT] = int(legacy)
		settings.set_value("high_scores", scores)
	settings.erase_value("high_score")
	settings.save()


func get_high_score(mode: String = MODE_ADJACENT) -> int:
	var scores: Dictionary = settings.get_value("high_scores", {})
	if scores is Dictionary and scores.has(mode):
		return int(scores[mode])
	# Fallback: legacy single score only maps to adjacent
	if mode == MODE_ADJACENT:
		return int(settings.get_value("high_score", 0))
	return 0


func set_high_score(value: int, mode: String = MODE_ADJACENT) -> void:
	var scores: Dictionary = settings.get_value("high_scores", {})
	if not scores is Dictionary:
		scores = {}
	scores[mode] = value
	settings.set_value("high_scores", scores)
	settings.save()


func get_unlock_high_score() -> int:
	## Unlocks gate on normal (adjacent / Play) high score.
	return get_high_score(MODE_ADJACENT)


func is_tutorial_completed() -> bool:
	return settings.get_value("tutorial_completed", false)


func set_tutorial_completed(value: bool) -> void:
	settings.set_value("tutorial_completed", value)
	settings.save()
