extends Control

@onready var score_label: Label = %ScoreLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var new_record_label: Label = %NewRecordLabel
@onready var play_again_button: AnimButton = %PlayAgainButton
@onready var menu_button: AnimButton = %MenuButton

var final_score: int = 0
var is_new_record: bool = false


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again)
	menu_button.pressed.connect(_on_menu)
	
	_setup_display()


func _setup_display() -> void:
	final_score = CavernGameManager.score
	var mode_best := SaveManager.get_high_score(CavernGameManager.movement_mode) if SaveManager else CavernGameManager.high_score
	is_new_record = final_score >= mode_best and final_score > 0
	
	score_label.text = str(final_score)
	high_score_label.text = "Best: %d" % mode_best
	
	new_record_label.visible = is_new_record

func _on_play_again() -> void:
	var mode := CavernGameManager.movement_mode if CavernGameManager else "adjacent"
	CavernGameManager.start_new_game(mode)
	STransitions.change_scene_with_transition(C.SCREENS.GAME, "circleIn")


func _on_menu() -> void:
	STransitions.change_scene_with_transition(C.SCREENS.MENU)
