class_name PlayerCard
extends Card

const PLAYER_ICON := preload("res://game/assets/sprites/player.svg")

var _signals_connected := false


func _ready() -> void:
	super._ready()
	card_type = CardType.PLAYER
	is_interactable = false
	_connect_signals()
	_update_visuals()


func _connect_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true
	
	if not CavernGameManager.health_changed.is_connected(_on_health_changed):
		CavernGameManager.health_changed.connect(_on_health_changed)
	if not CavernGameManager.shield_changed.is_connected(_on_shield_changed):
		CavernGameManager.shield_changed.connect(_on_shield_changed)


func _exit_tree() -> void:
	if CavernGameManager.health_changed.is_connected(_on_health_changed):
		CavernGameManager.health_changed.disconnect(_on_health_changed)
	if CavernGameManager.shield_changed.is_connected(_on_shield_changed):
		CavernGameManager.shield_changed.disconnect(_on_shield_changed)


func setup_player(pos: Vector2i) -> void:
	grid_position = pos
	card_subtype = "player"
	card_type = CardType.PLAYER
	is_interactable = false
	_connect_signals()
	call_deferred("_update_visuals")


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	if not value_label or not background:
		return
	
	var health := CavernGameManager.player_health
	var shield := CavernGameManager.player_shield
	
	value_label.text = str(health)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	
	if icon:
		icon.texture = PLAYER_ICON
	
	if type_label:
		type_label.text = ""
	
	var base_style = background.get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if base_style is StyleBoxFlat:
		style = base_style.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
	
	style.bg_color = Color(0.15, 0.5, 0.2)
	
	if shield > 0:
		style.border_color = Color(0.4, 0.6, 1.0)
		style.set_border_width_all(3)
	else:
		style.set_border_width_all(0)
	
	background.add_theme_stylebox_override("panel", style)


func _on_health_changed(_new_health: int, _max_health: int) -> void:
	_update_visuals()


func _on_shield_changed(_new_shield: int) -> void:
	_update_visuals()


func play_move_animation(target_pos: Vector2) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_pos, 0.12)
	await tween.finished
