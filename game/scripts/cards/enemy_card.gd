class_name EnemyCard
extends Card

const ENEMY_ICONS := {
	"bat": preload("res://game/assets/sprites/bat.svg"),
	"snake": preload("res://game/assets/sprites/snake.svg"),
	"spider": preload("res://game/assets/sprites/spider.svg")
}

const ENEMIES := {
	"bat": {"health_range": Vector2i(1, 3), "color": Color(0.5, 0.35, 0.5)},
	"snake": {"health_range": Vector2i(2, 5), "color": Color(0.35, 0.55, 0.3)},
	"spider": {"health_range": Vector2i(2, 4), "color": Color(0.4, 0.35, 0.35)}
}


func _ready() -> void:
	super._ready()
	card_type = CardType.ENEMY
	_update_visuals()


func setup_enemy(enemy_type: String, pos: Vector2i, difficulty_scale: float = 1.0) -> void:
	card_subtype = enemy_type
	grid_position = pos
	card_type = CardType.ENEMY
	
	var enemy_data: Dictionary = ENEMIES.get(enemy_type, ENEMIES["bat"])
	var base_health := randi_range(enemy_data.health_range.x, enemy_data.health_range.y)
	card_value = maxi(1, int(base_health * difficulty_scale))
	
	call_deferred("_update_visuals")


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	if not value_label or not background:
		return
	
	value_label.text = str(card_value)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	
	var enemy_data: Dictionary = ENEMIES.get(card_subtype, ENEMIES["bat"])
	
	if icon:
		icon.texture = ENEMY_ICONS.get(card_subtype, ENEMY_ICONS["bat"])
	
	var style := StyleBoxFlat.new()
	style.bg_color = enemy_data.color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background.add_theme_stylebox_override("panel", style)


func resolve_combat() -> Dictionary:
	var damage := card_value
	var result := {
		"damage_dealt": damage,
		"enemy_killed": true,
		"jewel_reward": _get_jewel_reward()
	}
	
	CavernGameManager.take_damage(damage)
	CavernAudio.play_sfx("hit")
	CavernAudio.vibrate_kill()
	
	return result


func _get_jewel_reward() -> Dictionary:
	var jewel_type: String
	
	if card_value <= 2:
		jewel_type = ["quartz", "amethyst"].pick_random()
	elif card_value <= 4:
		jewel_type = ["amethyst", "emerald"].pick_random()
	elif card_value <= 6:
		jewel_type = ["emerald", "sapphire"].pick_random()
	else:
		jewel_type = ["sapphire", "ruby"].pick_random()
	
	var value := CavernGameManager.get_jewel_value(jewel_type) if CavernGameManager else 1
	return {"type": jewel_type, "value": value}


static func get_random_enemy_type() -> String:
	return ENEMIES.keys().pick_random()
