extends Control

@onready var title_label: Label = %TitleLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var play_button: AnimButton = %PlayButton
@onready var continue_button: AnimButton = %ContinueButton
@onready var settings_button: AnimButton = %SettingsButton
@onready var tutorial_button: AnimButton = %TutorialButton
@onready var quit_button: AnimButton = %QuitButton


func _ready() -> void:
	_setup_buttons()
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
	
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	if OS.has_feature("web") or OS.has_feature("mobile"):
		quit_button.visible = false


func _update_high_score_display() -> void:
	if high_score_label and CavernGameManager:
		high_score_label.text = "Best: %d" % CavernGameManager.high_score


func _animate_title() -> void:
	if not title_label:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "modulate:a", 0.75, 1.2)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.2)


func _on_play_pressed() -> void:
	if CavernGameManager:
		CavernGameManager.start_new_game()
	
	var tutorial_done := CavernGameManager.tutorial_completed if CavernGameManager else true
	var target_scene := C.SCREENS.GAME
	if not tutorial_done:
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
