class_name Card
extends Control

signal card_pressed(card: Card)
signal card_animation_finished

enum CardType {
	EMPTY,
	PLAYER,
	ENEMY,
	ITEM,
	JEWEL,
	BOMB
}

@export var card_type: CardType = CardType.EMPTY

@onready var background: Panel = $Background
@onready var icon: TextureRect = $Icon
@onready var value_label: Label = $ValueLabel
@onready var type_label: Label = $TypeLabel
@onready var highlight: Panel = $Highlight
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var grid_position: Vector2i = Vector2i.ZERO
var card_value: int = 0
var card_subtype: String = ""
var is_interactable: bool = true

var _click_cooldown: float = 0.0


func _ready() -> void:
	if highlight:
		highlight.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if _click_cooldown > 0:
		_click_cooldown -= delta


func _gui_input(event: InputEvent) -> void:
	if not is_interactable:
		return
	if _click_cooldown > 0:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_click_cooldown = 0.2
			CavernAudio.play_sfx("button")
			card_pressed.emit(self)
			accept_event()
	
	if event is InputEventScreenTouch:
		if event.pressed:
			_click_cooldown = 0.2
			CavernAudio.play_sfx("button")
			card_pressed.emit(self)
			accept_event()


func _on_gui_input(event: InputEvent) -> void:
	_gui_input(event)


func _on_mouse_entered() -> void:
	if is_interactable and card_type != CardType.PLAYER and highlight:
		highlight.visible = true


func _on_mouse_exited() -> void:
	if highlight:
		highlight.visible = false


func setup(type: CardType, subtype: String, value: int, pos: Vector2i) -> void:
	card_type = type
	card_subtype = subtype
	card_value = value
	grid_position = pos
	_update_visuals()


func _update_visuals() -> void:
	if value_label:
		value_label.text = str(card_value) if card_value > 0 else ""
	_set_color_for_type()


func _set_color_for_type() -> void:
	if not background:
		return
	
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
	
	match card_type:
		CardType.PLAYER:
			style.bg_color = Color(0.2, 0.6, 0.2)
		CardType.ENEMY:
			style.bg_color = Color(0.7, 0.2, 0.2)
			if value_label:
				value_label.add_theme_color_override("font_color", Color.WHITE)
		CardType.ITEM:
			style.bg_color = Color(0.2, 0.4, 0.7)
		CardType.JEWEL:
			style.bg_color = Color(0.8, 0.7, 0.2)
		CardType.BOMB:
			style.bg_color = Color(0.8, 0.4, 0.1)
		_:
			style.bg_color = Color(0.3, 0.3, 0.3)
	
	background.add_theme_stylebox_override("panel", style)


## Animations

func play_spawn_animation() -> void:
	animation_player.play("spawn")
	await animation_player.animation_finished
	card_animation_finished.emit()


func play_death_animation() -> void:
	animation_player.play("death")
	await animation_player.animation_finished
	card_animation_finished.emit()


func play_damage_flash() -> void:
	var original_modulate := modulate
	modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "modulate", original_modulate, 0.15)


func play_slide_animation(target_pos: Vector2, duration: float = 0.15) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", target_pos, duration)
	await tween.finished


func set_highlight_adjacent(is_adjacent: bool) -> void:
	if not highlight:
		return
	if is_adjacent and card_type != CardType.PLAYER:
		highlight.visible = true
	else:
		highlight.visible = false


func serialize() -> Dictionary:
	return {
		"type": card_type,
		"subtype": card_subtype,
		"value": card_value,
		"position": {"x": grid_position.x, "y": grid_position.y}
	}


static func deserialize(data: Dictionary) -> Dictionary:
	return {
		"type": data.get("type", CardType.EMPTY),
		"subtype": data.get("subtype", ""),
		"value": data.get("value", 0),
		"position": Vector2i(data.position.x, data.position.y)
	}
