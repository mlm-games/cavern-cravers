extends Control

@onready var title_label: Label = %TitleLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var play_button: AnimButton = %PlayButton
@onready var safe_mode_button: AnimButton = %SafeModeButton
@onready var hard_mode_button: AnimButton = %HardModeButton
@onready var continue_button: AnimButton = %ContinueButton
@onready var settings_button: AnimButton = %SettingsButton
@onready var tutorial_button: AnimButton = %TutorialButton
@onready var quit_button: AnimButton = %QuitButton


func _ready() -> void:
	_setup_buttons()
	_update_mode_buttons()
	_update_high_score_display()
	_animate_title()
	
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		play_button.grab_focus()


func _setup_buttons() -> void:
	var has_save := CavernGameManager.has_saved_game() if CavernGameManager else false
	continue_button.visible = has_save
	if has_save:
		continue_button.pressed.connect(_on_continue_pressed)
	
	play_button.pressed.connect(_on_play_pressed.bind("adjacent"))
	safe_mode_button.pressed.connect(_on_play_pressed.bind("combined"))
	hard_mode_button.pressed.connect(_on_play_pressed.bind("diagonal"))
	settings_button.pressed.connect(_on_settings_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if OS.has_feature("web") or OS.has_feature("mobile"):
		quit_button.visible = false


func _update_mode_buttons() -> void:
	var adj_hs := SaveManager.get_high_score("adjacent") if SaveManager else 0
	var combined_hs := SaveManager.get_high_score("combined") if SaveManager else 0
	
	var combined_unlocked := adj_hs >= 300
	var diagonal_unlocked := adj_hs >= 1000 or combined_hs >= 1500
	
	if combined_unlocked:
		if combined_hs > 0:
			safe_mode_button.text = "Safe Mode (Best %d)" % combined_hs
		else:
			safe_mode_button.text = "Safe Mode"
		safe_mode_button.disabled = false
	else:
		safe_mode_button.text = "Unlocks at 300"
		safe_mode_button.disabled = true
	
	if not combined_unlocked:
		hard_mode_button.visible = false
	else:
		hard_mode_button.visible = true
		if diagonal_unlocked:
			var best := SaveManager.get_high_score("diagonal") if SaveManager else 0
			if best > 0:
				hard_mode_button.text = "Hard Mode (Best %d)" % best
			else:
				hard_mode_button.text = "Hard Mode"
			hard_mode_button.disabled = false
		else:
			hard_mode_button.text = "Unlocks at 1000 or 1500 in Safe"
			hard_mode_button.disabled = true


func _update_high_score_display() -> void:
	if not high_score_label:
		return
	var adj := SaveManager.get_high_score("adjacent") if SaveManager else 0
	high_score_label.text = "Best: %d" % adj


func _animate_title() -> void:
	if not title_label:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "modulate:a", 0.75, 1.2)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.2)


func _on_play_pressed(mode: String = "adjacent") -> void:
	if CavernGameManager:
		if not CavernGameManager.is_mode_unlocked(mode):
			return
		CavernGameManager.start_new_game(mode)
	
	var tutorial_done := CavernGameManager.tutorial_completed if CavernGameManager else true
	var target_scene := C.SCREENS.GAME
	if not tutorial_done and mode == "adjacent":
		target_scene = C.SCREENS.TUTORIAL
	
	_change_scene(target_scene)


func _on_continue_pressed() -> void:
	_change_scene(C.SCREENS.GAME)


func _on_tutorial_pressed() -> void:
	_change_scene(C.SCREENS.TUTORIAL)


func _on_settings_pressed() -> void:
	add_child(preload(C.SCREENS.SETTINGS).instantiate())

func _on_quit_pressed() -> void:
	get_tree().quit()


func _change_scene(path: String) -> void:
	STransitions.change_scene_with_transition(path, "circleIn")
