class_name CavernHUD
extends Control

@onready var health_label: Label = %HealthLabel
@onready var shield_label: Label = %ShieldLabel
@onready var score_label: Label = %ScoreLabel
@onready var undo_button: AnimButton = %UndoButton
@onready var menu_button: AnimButton = %MenuButton
@onready var damage_flash: ColorRect = %DamageFlash

var _grid: GameGrid
var _signals_connected := false


func _ready() -> void:
	_connect_signals()
	_connect_buttons()
	call_deferred("_update_display")
	
	if damage_flash:
		damage_flash.color.a = 0


func _connect_signals() -> void:
	if _signals_connected or not CavernGameManager:
		return
	_signals_connected = true
	
	CavernGameManager.health_changed.connect(_on_health_changed)
	CavernGameManager.score_changed.connect(_on_score_changed)
	CavernGameManager.shield_changed.connect(_on_shield_changed)
	CavernGameManager.undo_used.connect(_on_undo_used)


func _connect_buttons() -> void:
	if undo_button and not undo_button.pressed.is_connected(_on_undo_pressed):
		undo_button.pressed.connect(_on_undo_pressed)
	if menu_button and not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)


func set_grid(grid: GameGrid) -> void:
	_grid = grid


func _update_display() -> void:
	if not CavernGameManager:
		return
	_on_health_changed(CavernGameManager.player_health, CavernGameManager.MAX_HEALTH)
	_on_score_changed(CavernGameManager.score)
	_on_shield_changed(CavernGameManager.player_shield)
	if undo_button:
		undo_button.disabled = not CavernGameManager.undo_available


func _on_health_changed(new_health: int, max_health: int) -> void:
	if health_label:
		health_label.text = "%d/%d" % [new_health, max_health]
		
		var health_percent := float(new_health) / float(max_health) if max_health > 0 else 0.0
		if health_percent <= 0.25:
			health_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			_flash_damage()
		elif health_percent <= 0.5:
			health_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		else:
			health_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))


func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = str(new_score)
		var tween := create_tween()
		tween.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.08)
		tween.tween_property(score_label, "scale", Vector2.ONE, 0.08)


func _on_shield_changed(new_shield: int) -> void:
	if shield_label:
		shield_label.text = str(new_shield)
		if new_shield > 0:
			shield_label.modulate.a = 1.0
			shield_label.get_parent().get_child(0).modulate.a = 1.0
		else:
			shield_label.modulate.a = 0.4
			shield_label.get_parent().get_child(0).modulate.a = 0.4


func _on_undo_used() -> void:
	if undo_button:
		undo_button.disabled = true


func _flash_damage() -> void:
	if damage_flash:
		damage_flash.color.a = 0.35
		var tween := create_tween()
		tween.tween_property(damage_flash, "color:a", 0.0, 0.4)


func _on_undo_pressed() -> void:
	if not CavernGameManager or not CavernGameManager.undo_available:
		return
	
	if CavernAudio:
		CavernAudio.play_sfx("undo")
	
	var undo_state := CavernGameManager.perform_undo()
	if _grid and not undo_state.is_empty():
		_grid.restore_from_undo(undo_state)


func _on_menu_pressed() -> void:
	PauseMenu.pause()
