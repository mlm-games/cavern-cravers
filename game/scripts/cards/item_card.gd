class_name ItemCard
extends Card

enum ItemType {
	HEALTH_POTION,
	POISON_POTION,
	SHIELD,
	BLAST_SCROLL,
	DIAGONAL_BLAST_SCROLL
}

const ITEM_ICONS := {
	ItemType.HEALTH_POTION: preload("res://game/assets/sprites/health_potion.svg"),
	ItemType.POISON_POTION: preload("res://game/assets/sprites/poison_potion.svg"),
	ItemType.SHIELD: preload("res://game/assets/sprites/shield.svg"),
	ItemType.BLAST_SCROLL: preload("res://game/assets/sprites/bomb.svg"),
	ItemType.DIAGONAL_BLAST_SCROLL: preload("res://game/assets/sprites/dynamite.svg")
}

const ITEM_DATA := {
	ItemType.HEALTH_POTION: {
		"name": "Health Potion",
		"value_range": Vector2i(3, 5),
		"color": Color(0.25, 0.65, 0.35)
	},
	ItemType.POISON_POTION: {
		"name": "Poison Potion",
		"value_range": Vector2i(2, 4),
		"color": Color(0.55, 0.25, 0.55)
	},
	ItemType.SHIELD: {
		"name": "Shield",
		"value_range": Vector2i(2, 5),
		"color": Color(0.3, 0.5, 0.75)
	},
	ItemType.BLAST_SCROLL: {
		"name": "Blast Scroll",
		"value_range": Vector2i(0, 0),
		"color": Color(0.75, 0.55, 0.25)
	},
	ItemType.DIAGONAL_BLAST_SCROLL: {
		"name": "Diagonal Blast",
		"value_range": Vector2i(0, 0),
		"color": Color(0.65, 0.45, 0.3)
	}
}

var item_type: ItemType = ItemType.HEALTH_POTION


func _ready() -> void:
	super._ready()
	card_type = CardType.ITEM
	if has_meta("item_type"):
		item_type = get_meta("item_type")
	_update_visuals()


func setup_item(type: ItemType, pos: Vector2i) -> void:
	item_type = type
	grid_position = pos
	card_type = CardType.ITEM
	card_subtype = ItemType.keys()[type].to_lower()
	
	var data: Dictionary = ITEM_DATA[type]
	if data.value_range.x > 0:
		card_value = randi_range(data.value_range.x, data.value_range.y)
	else:
		card_value = 0
	
	call_deferred("_update_visuals")


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	if not value_label or not background:
		return
	
	var data: Dictionary = ITEM_DATA.get(item_type, ITEM_DATA[ItemType.HEALTH_POTION])
	
	if card_value > 0:
		value_label.text = str(card_value)
	else:
		value_label.text = ""
	
	if item_type == ItemType.POISON_POTION:
		value_label.add_theme_color_override("font_color", Color(1, 0.8, 1))
	else:
		value_label.add_theme_color_override("font_color", Color.WHITE)
	
	if type_label:
		type_label.text = ""
	if icon:
		icon.texture = ITEM_ICONS.get(item_type, ITEM_ICONS[ItemType.HEALTH_POTION])
	
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background.add_theme_stylebox_override("panel", style)


func use_item() -> Dictionary:
	var result := {
		"type": item_type,
		"value": card_value,
		"affects_grid": false,
		"affected_positions": []
	}
	
	match item_type:
		ItemType.HEALTH_POTION:
			CavernGameManager.heal(card_value)
			CavernAudio.play_sfx("heal")
			
		ItemType.POISON_POTION:
			CavernGameManager.take_damage(card_value)
			CavernAudio.play_sfx("hit")
			CavernAudio.vibrate_damage()
			
		ItemType.SHIELD:
			CavernGameManager.add_shield(card_value)
			CavernAudio.play_sfx("shield")
			
		ItemType.BLAST_SCROLL:
			result.affects_grid = true
			result.affected_positions = _get_orthogonal_positions()
			CavernAudio.play_sfx("explosion")
			CavernAudio.vibrate_explosion()
			
		ItemType.DIAGONAL_BLAST_SCROLL:
			result.affects_grid = true
			result.affected_positions = _get_diagonal_positions()
			CavernAudio.play_sfx("explosion")
			CavernAudio.vibrate_explosion()
	
	return result


func _get_orthogonal_positions() -> Array[Vector2i]:
	return [
		grid_position + Vector2i.UP,
		grid_position + Vector2i.DOWN,
		grid_position + Vector2i.LEFT,
		grid_position + Vector2i.RIGHT
	]


func _get_diagonal_positions() -> Array[Vector2i]:
	return [
		grid_position + Vector2i(-1, -1),
		grid_position + Vector2i(1, -1),
		grid_position + Vector2i(-1, 1),
		grid_position + Vector2i(1, 1)
	]


static func get_random_item_type() -> ItemType:
	var weights := {
		ItemType.HEALTH_POTION: 30,
		ItemType.POISON_POTION: 15,
		ItemType.SHIELD: 25,
		ItemType.BLAST_SCROLL: 15,
		ItemType.DIAGONAL_BLAST_SCROLL: 15
	}
	
	var total := 0
	for w in weights.values():
		total += w
	
	var roll := randi() % total
	var cumulative := 0
	
	for type in weights:
		cumulative += weights[type]
		if roll < cumulative:
			return type
	
	return ItemType.HEALTH_POTION
