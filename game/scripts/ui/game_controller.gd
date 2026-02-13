extends Node

@onready var grid: GameGrid = %GameGrid
@onready var hud: CavernHUD = %CavernHUD
@onready var responsive_layout: CavernResponsiveLayout = %CavernResponsiveLayout


func _ready() -> void:
	get_tree().paused = false

	hud.set_grid(grid)

	CavernGameManager.game_over.connect(_on_game_over)

	if CavernGameManager.has_saved_game():
		_load_saved_game()
	else:
		_start_new_game()


func _start_new_game() -> void:
	CavernGameManager.start_new_game()
	if grid:
		grid.initialize_new_game()


func _load_saved_game() -> void:
	var success := CavernGameManager.load_game()
	if not success:
		_start_new_game()
		return

	if grid:
		# load_game() already loaded the data into SaveManager.game,
		var save_data: Dictionary = SaveManager.game.get_dict("state")
		grid.initialize_from_save(save_data)


func _on_game_over(_final_score: int) -> void:
	await get_tree().create_timer(1.0).timeout
	STransitions.change_scene_with_transition("res://game/scenes/ui/game_over.tscn", "fadeToBlack")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PauseMenu.pause()
