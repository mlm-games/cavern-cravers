class_name CardFactory
extends RefCounted

const CARD_SCENE_PATH := "res://game/scenes/cards/card_base.tscn"

static var _card_scene: PackedScene


static func _get_card_scene() -> PackedScene:
	if not _card_scene:
		_card_scene = load(CARD_SCENE_PATH)
	return _card_scene


static func create_player(pos: Vector2i) -> Card:
	var card := _get_card_scene().instantiate() as Card
	card.set_script(load("res://game/scripts/cards/player_card.gd"))
	card.card_type = Card.CardType.PLAYER
	card.grid_position = pos
	card.card_subtype = "player"
	card.is_interactable = false
	return card


static func create_enemy(enemy_type: String, pos: Vector2i, difficulty_scale: float = 1.0) -> Card:
	var card := _get_card_scene().instantiate() as Card
	card.set_script(load("res://game/scripts/cards/enemy_card.gd"))
	card.card_type = Card.CardType.ENEMY
	card.grid_position = pos
	card.card_subtype = enemy_type
	
	var enemy_data: Dictionary = EnemyCard.ENEMIES.get(enemy_type, EnemyCard.ENEMIES["bat"])
	var base_health := randi_range(enemy_data.health_range.x, enemy_data.health_range.y)
	card.card_value = maxi(1, int(base_health * difficulty_scale))
	
	return card


static func create_item(item_type: ItemCard.ItemType, pos: Vector2i) -> Card:
	var card := _get_card_scene().instantiate() as Card
	card.set_script(load("res://game/scripts/cards/item_card.gd"))
	card.card_type = Card.CardType.ITEM
	card.grid_position = pos
	card.card_subtype = ItemCard.ItemType.keys()[item_type].to_lower()
	
	var data: Dictionary = ItemCard.ITEM_DATA[item_type]
	if data.value_range.x > 0:
		card.card_value = randi_range(data.value_range.x, data.value_range.y)
	
	card.set_meta("item_type", item_type)
	
	return card


static func create_jewel(jewel_type: String, pos: Vector2i) -> Card:
	var card := _get_card_scene().instantiate() as Card
	card.set_script(load("res://game/scripts/cards/jewel_card.gd"))
	card.card_type = Card.CardType.JEWEL
	card.grid_position = pos
	card.card_subtype = jewel_type
	card.card_value = JewelCard.JEWEL_DATA[jewel_type].value
	
	return card


static func create_bomb(bomb_type: BombCard.BombType, pos: Vector2i, difficulty_scale: float = 1.0) -> Card:
	var card := _get_card_scene().instantiate() as Card
	card.set_script(load("res://game/scripts/cards/bomb_card.gd"))
	card.card_type = Card.CardType.BOMB
	card.grid_position = pos
	card.card_subtype = "bomb" if bomb_type == BombCard.BombType.BOMB else "dynamite"
	card.card_value = 3
	
	card.set_meta("bomb_type", bomb_type)
	card.set_meta("base_damage", maxi(3, int(randi_range(3, 6) * difficulty_scale)))
	
	return card
