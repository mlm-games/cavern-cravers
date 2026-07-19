class_name BombCard
extends Card

enum BombType {
	BOMB,
	DYNAMITE
}

const BOMB_ICON := preload("res://game/assets/sprites/bomb.svg")
const DYNAMITE_ICON := preload("res://game/assets/sprites/dynamite.svg")

var bomb_type: BombType = BombType.BOMB
var timer: int = 3
var base_damage: int = 3
var _turn_signal_connected := false


func _ready() -> void:
	super._ready()
	card_type = CardType.BOMB
	
	if has_meta("bomb_type"):
		bomb_type = get_meta("bomb_type")
	if has_meta("base_damage"):
		base_damage = get_meta("base_damage")
	
	_connect_turn_signal()
	_update_visuals()


func _connect_turn_signal() -> void:
	if _turn_signal_connected:
		return
	if not CavernGameManager.turn_ended.is_connected(_on_turn_ended):
		CavernGameManager.turn_ended.connect(_on_turn_ended)
		_turn_signal_connected = true


func _exit_tree() -> void:
	if CavernGameManager.turn_ended.is_connected(_on_turn_ended):
		CavernGameManager.turn_ended.disconnect(_on_turn_ended)
		_turn_signal_connected = false


func setup_bomb(type: BombType, pos: Vector2i, difficulty_scale: float = 1.0) -> void:
	bomb_type = type
	grid_position = pos
	card_type = CardType.BOMB
	card_subtype = "bomb" if type == BombType.BOMB else "dynamite"
	
	timer = 3
	base_damage = maxi(3, int(randi_range(3, 6) * difficulty_scale))
	card_value = timer
	
	_connect_turn_signal()
	call_deferred("_update_visuals")


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	if not value_label or not background:
		return
	
	value_label.text = str(timer)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	
	if icon:
		icon.texture = BOMB_ICON if bomb_type == BombType.BOMB else DYNAMITE_ICON
	
	var style := StyleBoxFlat.new()
	
	if timer <= 1:
		style.bg_color = Color(0.88, 0.18, 0.12)
		_pulse_urgent()
	elif timer == 2:
		style.bg_color = Color(0.88, 0.48, 0.12)
	else:
		style.bg_color = Color(0.68, 0.38, 0.14)
	style.border_color = style.bg_color.darkened(0.5)
	
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	background.add_theme_stylebox_override("panel", style)


func _pulse_urgent() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.3, 1.0, 1.0), 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _on_turn_ended() -> void:
	if not is_inside_tree():
		return
	
	timer -= 1
	card_value = timer
	_update_visuals()
	
	if timer <= 0:
		explode()


func explode() -> void:
	var affected_positions := get_explosion_positions()

	var explosion_data := {
		"source_position": grid_position,
		"affected_positions": affected_positions,
		"damage": base_damage,
		"bomb_type": bomb_type
	}

	CavernAudio.play_sfx("explosion")
	CavernAudio.vibrate_explosion()

	var grid := get_tree().get_first_node_in_group("grid")
	if grid and grid.has_method("enqueue_explosion"):
		grid.enqueue_explosion(explosion_data)
	elif grid and grid.has_method("handle_explosion"):
		grid.handle_explosion(explosion_data)


func get_explosion_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var diagonals_enabled = SettingsManager.get_setting("gameplay", "diagonal_movement", false)

	match bomb_type:
		BombType.BOMB:
			positions = [
				grid_position + Vector2i.UP,
				grid_position + Vector2i.DOWN,
				grid_position + Vector2i.LEFT,
				grid_position + Vector2i.RIGHT
			]
		BombType.DYNAMITE:
			if diagonals_enabled:
				positions = [
					grid_position + Vector2i(-1, -1),
					grid_position + Vector2i(1, -1),
					grid_position + Vector2i(-1, 1),
					grid_position + Vector2i(1, 1)
				]
			else:
				positions = [
					grid_position + Vector2i.UP,
					grid_position + Vector2i.DOWN,
					grid_position + Vector2i.LEFT,
					grid_position + Vector2i.RIGHT,
					grid_position + Vector2i(-1, -1),
					grid_position + Vector2i(1, -1),
					grid_position + Vector2i(-1, 1),
					grid_position + Vector2i(1, 1)
				]

	return positions


func defuse() -> void:
	var defuse_damage := maxi(1, int(timer * base_damage / 3.0))
	CavernGameManager.take_damage(defuse_damage)


static func get_random_bomb_type() -> BombType:
	return BombType.BOMB if randf() < 0.5 else BombType.DYNAMITE
