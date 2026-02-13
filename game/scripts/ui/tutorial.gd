extends Control

enum TutorialStep {
	WELCOME,
	MOVEMENT,
	COMBAT,
	ITEMS,
	BOMBS,
	SCORING,
	COMPLETE
}

@onready var instruction_label: Label = %InstructionLabel
@onready var skip_button: AnimButton = %SkipButton
@onready var next_button: AnimButton = %NextButton

var current_step: TutorialStep = TutorialStep.WELCOME

const INSTRUCTIONS := {
	TutorialStep.WELCOME: "Welcome to Cavern Cravers!\n\n If you've played dungeon cards before, you can skip this as the core gameplay is essential the same. ",
	TutorialStep.MOVEMENT: "Tap any adjacent card to move.\n\n You can move diagonally depending on the game mode",
	TutorialStep.COMBAT: "Move onto enemies to attack them.\n\nYou'll take damage equal to their remaining health.",
	TutorialStep.ITEMS: "Green potions heal you. Purple potions hurt.\n\nBlue shields absorb damage before your health.",
	TutorialStep.BOMBS: "Orange bombs count down each turn.\n\nWhen they reach 0, they explode! Defuse them by moving onto them.",
	TutorialStep.SCORING: "Collect jewels for points.\n\nDefeated enemies can drop jewels too based on their strength.",
	TutorialStep.COMPLETE: "You're knowledgable enough to play now!\n\nSurvive as long as you can and build your score!"
}


func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	next_button.pressed.connect(_on_next)
	
	_show_step(TutorialStep.WELCOME)


func _show_step(step: TutorialStep) -> void:
	current_step = step
	instruction_label.text = INSTRUCTIONS[step]
	
	if step == TutorialStep.COMPLETE:
		next_button.text = "Start Game"
	else:
		next_button.text = "Next"


func _on_next() -> void:
	if current_step == TutorialStep.COMPLETE:
		_complete_tutorial()
		return
	
	var next_step: int = current_step + 1
	_show_step(next_step as TutorialStep)


func _on_skip() -> void:
	_complete_tutorial()


func _complete_tutorial() -> void:
	CavernGameManager.mark_tutorial_complete()
	STransitions.change_scene_with_transition(C.SCREENS.GAME, "circleIn", false, 2)
