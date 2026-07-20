extends Node
## Handles core game logic and state

signal health_changed(new_health: int, max_health: int)
signal score_changed(new_score: int)
signal shield_changed(new_shield: int)
signal game_over(final_score: int)
signal undo_used
signal undo_restored
signal turn_ended

const GRID_SIZE := 4
const STARTING_HEALTH := 15
const MAX_HEALTH := 15

const MODE_ADJACENT := "adjacent"
const MODE_COMBINED := "combined"
const MODE_DIAGONAL := "diagonal"

const UNLOCK_COMBINED := 300
const UNLOCK_DIAGONAL := 1000
const UNLOCK_DIAGONAL_FROM_COMBINED := 1500

var player_health: int = STARTING_HEALTH
var player_shield: int = 0
var player_position: Vector2i = Vector2i(1, 1)
var score: int = 0
var undo_available: bool = true

var is_game_active: bool = false
var turn_count: int = 0

## adjacent | combined | diagonal — set when starting / loading a run
var movement_mode: String = MODE_ADJACENT

var _undo_state: Dictionary = {}

const JEWEL_VALUES := {
	"quartz": 1,
	"amethyst": 2,
	"emerald": 3,
	"sapphire": 5,
	"ruby": 8,
	"diamond": 13
}

## Cached best for current mode (and overall adjacent for unlocks / menu)
var high_score: int = 0
var tutorial_completed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	high_score = SaveManager.get_high_score(MODE_ADJACENT)
	tutorial_completed = SaveManager.is_tutorial_completed()


func get_movement_mode() -> String:
	return movement_mode


func is_mode_unlocked(mode: String) -> bool:
	match mode:
		MODE_COMBINED:
			return SaveManager.get_unlock_high_score() >= UNLOCK_COMBINED
		MODE_DIAGONAL:
			return SaveManager.get_high_score(MODE_ADJACENT) >= UNLOCK_DIAGONAL \
			    or SaveManager.get_high_score(MODE_COMBINED) >= UNLOCK_DIAGONAL_FROM_COMBINED
		_:
			return true


func start_new_game(mode: String = MODE_ADJACENT) -> void:
	if not is_mode_unlocked(mode):
		mode = MODE_ADJACENT
	movement_mode = mode

	player_health = STARTING_HEALTH
	player_shield = 0
	player_position = Vector2i(1, 1)
	score = 0
	undo_available = true
	is_game_active = true
	turn_count = 0
	_undo_state.clear()

	high_score = SaveManager.get_high_score(movement_mode)

	health_changed.emit(player_health, MAX_HEALTH)
	score_changed.emit(score)
	shield_changed.emit(player_shield)


func save_undo_state(grid_state: Array) -> void:
	_undo_state = {
		"health": player_health,
		"shield": player_shield,
		"position": {"x": player_position.x, "y": player_position.y},
		"score": score,
		"turn": turn_count,
		"grid": grid_state.duplicate(true)
	}


func grant_emergency_undo() -> void:
	if not _undo_state.is_empty():
		undo_available = true
		undo_restored.emit()


func perform_undo() -> Dictionary:
	if not undo_available or _undo_state.is_empty():
		return {}

	undo_available = false
	player_health = _undo_state.health
	player_shield = _undo_state.shield
	var pos_data: Dictionary = _undo_state.position
	player_position = Vector2i(pos_data.get("x", 1), pos_data.get("y", 1))
	score = _undo_state.score
	turn_count = _undo_state.turn

	health_changed.emit(player_health, MAX_HEALTH)
	score_changed.emit(score)
	shield_changed.emit(player_shield)
	undo_used.emit()

	return _undo_state.duplicate(true)


func take_damage(amount: int) -> void:
	var remaining_damage := amount

	if player_shield > 0:
		if player_shield >= remaining_damage:
			player_shield -= remaining_damage
			remaining_damage = 0
		else:
			remaining_damage -= player_shield
			player_shield = 0
		shield_changed.emit(player_shield)

	if remaining_damage > 0:
		player_health = maxi(0, player_health - remaining_damage)
		health_changed.emit(player_health, MAX_HEALTH)

	if player_health <= 0:
		end_game()


func heal(amount: int) -> void:
	player_health = mini(MAX_HEALTH, player_health + amount)
	health_changed.emit(player_health, MAX_HEALTH)


func add_shield(amount: int) -> void:
	player_shield += amount
	shield_changed.emit(player_shield)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func get_jewel_value(jewel_type: String) -> int:
	return JEWEL_VALUES.get(jewel_type.to_lower(), 1)


func end_turn() -> void:
	turn_count += 1
	turn_ended.emit()
	_save_game()


func end_game() -> void:
	is_game_active = false
	SaveManager.clear_game_save()
	_update_high_score(score)
	game_over.emit(score)


func get_difficulty_scale() -> float:
	return 1.0 + (turn_count * 0.02)


func _save_game() -> void:
	if not is_game_active:
		return

	var grid_node := get_tree().get_first_node_in_group("grid")
	if not grid_node:
		return

	var save_data := {
		"player": {
			"health": player_health,
			"shield": player_shield,
			"position": {"x": player_position.x, "y": player_position.y},
			"score": score,
			"undo_available": undo_available,
		},
		"turn_count": turn_count,
		"movement_mode": movement_mode,
		"grid": grid_node.serialize_grid(),
	}

	SaveManager.game.set_dict("state", save_data)
	SaveManager.game.save()


func load_game() -> bool:
	SaveManager.game.load_from_disk()
	var save_data: Dictionary = SaveManager.game.get_dict("state")
	if save_data.is_empty():
		return false

	var player_data: Dictionary = save_data.get("player", {})
	player_health = player_data.get("health", STARTING_HEALTH)
	player_shield = player_data.get("shield", 0)
	var pos_data: Dictionary = player_data.get("position", {"x": 1, "y": 1})
	player_position = Vector2i(
		int(pos_data.get("x", 1)),
		int(pos_data.get("y", 1))
	)
	score = int(player_data.get("score", 0))
	undo_available = player_data.get("undo_available", true)
	turn_count = int(save_data.get("turn_count", 0))
	movement_mode = str(save_data.get("movement_mode", MODE_ADJACENT))
	if movement_mode not in [MODE_ADJACENT, MODE_COMBINED, MODE_DIAGONAL]:
		movement_mode = MODE_ADJACENT
	high_score = SaveManager.get_high_score(movement_mode)
	is_game_active = true

	health_changed.emit(player_health, MAX_HEALTH)
	score_changed.emit(score)
	shield_changed.emit(player_shield)
	if not undo_available:
		undo_used.emit()

	return true


func has_saved_game() -> bool:
	return SaveManager.has_game_save()


func _update_high_score(new_score: int) -> bool:
	var mode_best := SaveManager.get_high_score(movement_mode)
	if new_score > mode_best:
		SaveManager.set_high_score(new_score, movement_mode)
		high_score = new_score
		return true
	high_score = mode_best
	return false


func reset_tutorial() -> void:
	tutorial_completed = false
	SaveManager.set_tutorial_completed(false)


func mark_tutorial_complete() -> void:
	tutorial_completed = true
	SaveManager.set_tutorial_completed(true)
