class_name JewelCard
extends Card

const JEWEL_ICONS := {
	"quartz": preload("res://game/assets/sprites/jewel.svg"),
	"amethyst": preload("res://game/assets/sprites/jewel.svg"),
	"emerald": preload("res://game/assets/sprites/jewel.svg"),
	"sapphire": preload("res://game/assets/sprites/jewel.svg"),
	"ruby": preload("res://game/assets/sprites/jewel.svg"),
	"diamond": preload("res://game/assets/sprites/jewel.svg")
}

const JEWEL_DATA := {
	"quartz": {"value": 1, "color": Color(0.85, 0.85, 0.9), "rarity": 30},
	"amethyst": {"value": 2, "color": Color(0.6, 0.35, 0.7), "rarity": 25},
	"emerald": {"value": 3, "color": Color(0.25, 0.75, 0.45), "rarity": 20},
	"sapphire": {"value": 5, "color": Color(0.25, 0.45, 0.85), "rarity": 12},
	"ruby": {"value": 8, "color": Color(0.85, 0.25, 0.35), "rarity": 10},
	"diamond": {"value": 13, "color": Color(0.75, 0.9, 1.0), "rarity": 3}
}


func _ready() -> void:
	super._ready()
	card_type = CardType.JEWEL
	_update_visuals()


func setup_jewel(jewel_type: String, pos: Vector2i) -> void:
	card_subtype = jewel_type
	grid_position = pos
	card_type = CardType.JEWEL
	card_value = JEWEL_DATA.get(jewel_type, JEWEL_DATA["quartz"]).value
	call_deferred("_update_visuals")


func _update_visuals() -> void:
	if not is_inside_tree():
		return
	if not value_label or not background:
		return
	
	value_label.text = str(card_value)
	
	var data: Dictionary = JEWEL_DATA.get(card_subtype, JEWEL_DATA["quartz"])
	
	var luminance: float = data.color.r * 0.299 + data.color.g * 0.587 + data.color.b * 0.114
	if luminance > 0.5:
		value_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	else:
		value_label.add_theme_color_override("font_color", Color.WHITE)
	
	if icon:
		icon.texture = JEWEL_ICONS.get(card_subtype, JEWEL_ICONS["quartz"])
	
	if type_label:
		type_label.text = ""
	
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.set_corner_radius_all(10)
	style.border_color = data.color.darkened(0.5)
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	background.add_theme_stylebox_override("panel", style)


func collect() -> void:
	CavernGameManager.add_score(card_value)
	CavernAudio.play_sfx("jewel")
	CavernAudio.vibrate_collect()


static func get_random_jewel_type() -> String:
	var total := 0
	for data in JEWEL_DATA.values():
		total += data.rarity
	
	var roll := randi() % total
	var cumulative := 0
	
	for jewel_type in JEWEL_DATA:
		cumulative += JEWEL_DATA[jewel_type].rarity
		if roll < cumulative:
			return jewel_type
	
	return "quartz"
