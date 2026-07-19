class_name GameGrid
extends Control

signal move_completed
signal grid_updated

const GRID_SIZE := 4
const MIN_CELL_SIZE := 60.0
const MAX_CELL_SIZE := 120.0
const MAX_ACTIVE_BOMBS := 2
const MAX_SPAWNS_PER_TURN := 3

@export var card_scene: PackedScene

@onready var grid_container: Control = $GridContainer

var cards: Array = []
var player_card: PlayerCard

var cell_size: Vector2 = Vector2(80, 80)
var cell_padding: float = 6.0

var is_processing_move := false
var is_processing_explosions := false

## Clickable highlights for empty adjacent cells (softlock fix)
var _empty_move_markers: Array[Control] = []

## Serialize bomb explosions so they don't race
var _pending_explosions: Array[Dictionary] = []
var _explosion_drain_running := false


func _ready() -> void:
	add_to_group("grid")
	resized.connect(_on_resized)
	call_deferred("_calculate_cell_size")
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if is_processing_move or is_processing_explosions:
		return
	if CavernGameManager and not CavernGameManager.is_game_active:
		return

	var dir := Vector2i.ZERO
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W):
		dir = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S):
		dir = Vector2i(0, 1)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A):
		dir = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D):
		dir = Vector2i(1, 0)
	elif SettingsManager.get_setting("gameplay", "diagonal_movement", false):
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_KP_7: dir = Vector2i(-1, -1)
				KEY_KP_9: dir = Vector2i(1, -1)
				KEY_KP_1: dir = Vector2i(-1, 1)
				KEY_KP_3: dir = Vector2i(1, 1)

	if dir != Vector2i.ZERO:
		var player_pos := CavernGameManager.player_position if CavernGameManager else Vector2i(1, 1)
		var target := player_pos + dir
		if _is_valid_position(target) and _is_adjacent_to_player(target):
			_process_player_move(target)
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if is_processing_move or is_processing_explosions:
		return
	if CavernGameManager and not CavernGameManager.is_game_active:
		return

	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position

	if not pressed:
		return

	var grid_pos := _pixel_to_grid(pos)
	if not _is_valid_position(grid_pos):
		return
	if not _is_adjacent_to_player(grid_pos):
		return
	if cards[grid_pos.x][grid_pos.y] != null:
		return

	_process_player_move(grid_pos)
	accept_event()


func _pixel_to_grid(pixel: Vector2) -> Vector2i:
	var step_x := cell_size.x + cell_padding
	var step_y := cell_size.y + cell_padding
	var x := int(floor((pixel.x - cell_padding) / step_x))
	var y := int(floor((pixel.y - cell_padding) / step_y))
	return Vector2i(x, y)


func _on_resized() -> void:
	_calculate_cell_size()
	_reposition_all_cards()
	_update_adjacent_highlights()


func _calculate_cell_size() -> void:
	var available_size := size
	if available_size == Vector2.ZERO:
		available_size = custom_minimum_size
	if available_size == Vector2.ZERO:
		available_size = Vector2(320, 320)
	
	var total_padding := cell_padding * (GRID_SIZE + 1)
	var usable_size := Vector2(
		available_size.x - total_padding,
		available_size.y - total_padding
	)
	var cell_dim := minf(usable_size.x, usable_size.y) / GRID_SIZE
	cell_dim = clampf(cell_dim, MIN_CELL_SIZE, MAX_CELL_SIZE)
	cell_size = Vector2(cell_dim, cell_dim)


func initialize_new_game() -> void:
	clear_grid()
	_init_empty_grid()
	_calculate_cell_size()
	_spawn_player()
	_populate_initial_cards()
	_ensure_safe_opening()
	_update_adjacent_highlights()


func initialize_from_save(save_data: Dictionary) -> void:
	clear_grid()
	_init_empty_grid()
	_calculate_cell_size()
	
	var player_data: Dictionary = save_data.get("player", {})
	var player_pos := Vector2i(
		player_data.get("position", {}).get("x", 1),
		player_data.get("position", {}).get("y", 1)
	)
	_spawn_player_at(player_pos)
	
	var grid_data: Array = save_data.get("grid", [])
	for card_data in grid_data:
		_restore_card(card_data)
	
	_update_adjacent_highlights()
	call_deferred("_recover_if_softlocked")


func clear_grid() -> void:
	_clear_empty_markers()
	if grid_container:
		for child in grid_container.get_children():
			child.queue_free()
	cards.clear()
	player_card = null
	_pending_explosions.clear()


func _init_empty_grid() -> void:
	cards.resize(GRID_SIZE)
	for x in GRID_SIZE:
		cards[x] = []
		cards[x].resize(GRID_SIZE)
		for y in GRID_SIZE:
			cards[x][y] = null


func _spawn_player() -> void:
	_spawn_player_at(Vector2i(1, 1))


func _spawn_player_at(pos: Vector2i) -> void:
	var card: Card = _create_card_instance()
	card.set_script(load("res://game/scripts/cards/player_card.gd"))
	player_card = card as PlayerCard
	player_card.setup_player(pos)
	player_card.scale = Vector2.ONE
	_place_card_internal(player_card, pos, false, Vector2i.ZERO)
	
	if CavernGameManager:
		CavernGameManager.player_position = pos


func _populate_initial_cards() -> void:
	var spawn_counts := {
		"enemy": randi_range(5, 6),
		"jewel": randi_range(3, 4),
		"health_potion": randi_range(1, 2),
		"shield": randi_range(1, 2),
		"bomb": 1,
		"poison": 1
	}
	
	var empty_positions := _get_empty_positions()
	empty_positions.shuffle()
	
	var spawn_index := 0
	
	for i in spawn_counts.enemy:
		if spawn_index >= empty_positions.size(): break
		_spawn_enemy_at(empty_positions[spawn_index])
		spawn_index += 1
	
	for i in spawn_counts.jewel:
		if spawn_index >= empty_positions.size(): break
		_spawn_jewel_at(empty_positions[spawn_index])
		spawn_index += 1
	
	for i in spawn_counts.health_potion:
		if spawn_index >= empty_positions.size(): break
		_spawn_item_at(empty_positions[spawn_index], ItemCard.ItemType.HEALTH_POTION)
		spawn_index += 1
	
	for i in spawn_counts.shield:
		if spawn_index >= empty_positions.size(): break
		_spawn_item_at(empty_positions[spawn_index], ItemCard.ItemType.SHIELD)
		spawn_index += 1
	
	if spawn_index < empty_positions.size():
		# Prefer bomb not adjacent to player on open
		var bomb_pos := empty_positions[spawn_index]
		for j in range(spawn_index, empty_positions.size()):
			if not _is_adjacent_to_player(empty_positions[j]):
				bomb_pos = empty_positions[j]
				empty_positions[j] = empty_positions[spawn_index]
				empty_positions[spawn_index] = bomb_pos
				break
		_spawn_bomb_at(empty_positions[spawn_index])
		spawn_index += 1
	
	if spawn_index < empty_positions.size():
		_spawn_item_at(empty_positions[spawn_index], ItemCard.ItemType.POISON_POTION)
		spawn_index += 1
	
	while spawn_index < empty_positions.size():
		_spawn_random_card_at(empty_positions[spawn_index], Vector2i.ZERO, true)
		spawn_index += 1


## Guarantee at least one non-lethal adjacent open (jewel/heal/shield or weak enemy)
func _ensure_safe_opening() -> void:
	if not player_card:
		return
	var adj := _get_adjacent_positions(player_card.grid_position)
	var has_safe := false
	for pos in adj:
		var c: Card = cards[pos.x][pos.y]
		if c == null:
			has_safe = true
			break
		if c.card_type == Card.CardType.JEWEL:
			has_safe = true
			break
		if c.card_type == Card.CardType.ITEM:
			var item := c as ItemCard
			if item and item.item_type != ItemCard.ItemType.POISON_POTION:
				has_safe = true
				break
		if c.card_type == Card.CardType.ENEMY and c.card_value <= 3:
			has_safe = true
			break

	if has_safe:
		return

	for pos in adj:
		var c: Card = cards[pos.x][pos.y]
		if c == null or c == player_card:
			continue
		c.queue_free()
		cards[pos.x][pos.y] = null
		_spawn_jewel_at(pos)
		return


func _create_card_instance() -> Card:
	if card_scene:
		return card_scene.instantiate() as Card
	else:
		# Fallback: create minimal card
		var card := Control.new()
		card.set_script(load("res://game/scripts/cards/card.gd"))
		return card as Card


func _spawn_enemy_at(pos: Vector2i, spawn_direction: Vector2i = Vector2i.ZERO) -> void:
	var card := _create_card_instance()
	card.set_script(load("res://game/scripts/cards/enemy_card.gd"))
	var enemy := card as EnemyCard
	var difficulty := CavernGameManager.get_difficulty_scale() if CavernGameManager else 1.0
	enemy.setup_enemy(EnemyCard.get_random_enemy_type(), pos, difficulty)
	_place_card(enemy, pos, spawn_direction)


func _spawn_jewel_at(pos: Vector2i, spawn_direction: Vector2i = Vector2i.ZERO) -> void:
	var card := _create_card_instance()
	card.set_script(load("res://game/scripts/cards/jewel_card.gd"))
	var jewel := card as JewelCard
	jewel.setup_jewel(JewelCard.get_random_jewel_type(), pos)
	_place_card(jewel, pos, spawn_direction)


func _spawn_item_at(pos: Vector2i, item_type: ItemCard.ItemType, spawn_direction: Vector2i = Vector2i.ZERO) -> void:
	var card := _create_card_instance()
	card.set_script(load("res://game/scripts/cards/item_card.gd"))
	var item := card as ItemCard
	item.setup_item(item_type, pos)
	_place_card(item, pos, spawn_direction)


func _spawn_bomb_at(pos: Vector2i, spawn_direction: Vector2i = Vector2i.ZERO) -> void:
	var card := _create_card_instance()
	card.set_script(load("res://game/scripts/cards/bomb_card.gd"))
	var bomb := card as BombCard
	var difficulty := CavernGameManager.get_difficulty_scale() if CavernGameManager else 1.0
	bomb.setup_bomb(BombCard.get_random_bomb_type(), pos, difficulty)
	_place_card(bomb, pos, spawn_direction)


func _count_bombs() -> int:
	var n := 0
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var c: Card = cards[x][y]
			if c and c.card_type == Card.CardType.BOMB:
				n += 1
	return n


func _spawn_random_card_at(pos: Vector2i, spawn_direction: Vector2i = Vector2i.ZERO, initial_fill: bool = false) -> Card:
	var card := _create_random_card_for_position(pos, initial_fill)
	_place_card(card, pos, spawn_direction)
	return card


func _place_card(card: Card, pos: Vector2i, spawn_direction: Vector2i = Vector2i.ZERO) -> void:
	_place_card_internal(card, pos, true, spawn_direction)


func _place_card_internal(card: Card, pos: Vector2i, animate: bool, spawn_direction: Vector2i) -> void:
	card.position = _grid_to_pixel(pos)
	card.custom_minimum_size = cell_size
	card.size = cell_size
	card.grid_position = pos
	
	if not card.card_pressed.is_connected(_on_card_pressed):
		card.card_pressed.connect(_on_card_pressed)
	
	grid_container.add_child(card)
	cards[pos.x][pos.y] = card
	
	if animate:
		_play_edge_spawn_animation(card, spawn_direction)


func _play_edge_spawn_animation(card: Card, spawn_direction: Vector2i) -> void:
	var duration := 0.2
	
	var initial_scale := Vector2.ONE
	var _initial_offset := Vector2.ZERO
	
	if spawn_direction == Vector2i.ZERO:
		# Center spawn (initial game setup) - expand from center
		card.pivot_offset = cell_size / 2
		card.scale = Vector2(0.0, 0.0)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "scale", Vector2.ONE, duration)
		return
	
	if spawn_direction.x == 1:
		card.pivot_offset = Vector2(0, cell_size.y / 2)
		initial_scale = Vector2(0.0, 1.0)
	elif spawn_direction.x == -1:
		card.pivot_offset = Vector2(cell_size.x, cell_size.y / 2)
		initial_scale = Vector2(0.0, 1.0)
	elif spawn_direction.y == 1:
		card.pivot_offset = Vector2(cell_size.x / 2, 0)
		initial_scale = Vector2(1.0, 0.0)
	elif spawn_direction.y == -1:
		card.pivot_offset = Vector2(cell_size.x / 2, cell_size.y)
		initial_scale = Vector2(1.0, 0.0)
	
	card.scale = initial_scale
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "scale", Vector2.ONE, duration)


func _get_edge_spawn_direction(pos: Vector2i) -> Vector2i:
	if pos.x == 0:
		return Vector2i(1, 0)
	elif pos.x == GRID_SIZE - 1:
		return Vector2i(-1, 0)
	elif pos.y == 0:
		return Vector2i(0, 1)
	elif pos.y == GRID_SIZE - 1:
		return Vector2i(0, -1)
	
	return Vector2i.ZERO


func _on_card_pressed(card: Card) -> void:
	if is_processing_move or is_processing_explosions:
		return
	if CavernGameManager and not CavernGameManager.is_game_active:
		return
	if not _is_adjacent_to_player(card.grid_position):
		return
	
	_process_player_move(card.grid_position)


func _process_player_move(target_pos: Vector2i) -> void:
	if not _is_valid_position(target_pos):
		return
	if is_processing_move or is_processing_explosions:
		return

	is_processing_move = true
	_clear_empty_markers()

	if CavernGameManager:
		CavernGameManager.save_undo_state(serialize_grid())

	var player_pos := CavernGameManager.player_position if CavernGameManager else Vector2i(1, 1)
	var target_card: Card = cards[target_pos.x][target_pos.y]

	if target_card == player_card:
		is_processing_move = false
		_update_adjacent_highlights()
		return

	if target_card:
		match target_card.card_type:
			Card.CardType.ENEMY:
				var enemy := target_card as EnemyCard
				var result := enemy.resolve_combat()
				if result.has("jewel_reward"):
					var jr: Dictionary = result.jewel_reward
					if jr.has("value"):
						CavernGameManager.add_score(int(jr.value))
				await target_card.play_death_animation()

			Card.CardType.ITEM:
				var item := target_card as ItemCard
				var result := item.use_item()
				if result.affects_grid:
					await _handle_blast_effect(result.affected_positions)
				await target_card.play_death_animation()

			Card.CardType.JEWEL:
				var jewel := target_card as JewelCard
				jewel.collect()
				await target_card.play_death_animation()

			Card.CardType.BOMB:
				var bomb := target_card as BombCard
				bomb.defuse()
				await target_card.play_death_animation()

			Card.CardType.PLAYER:
				is_processing_move = false
				_update_adjacent_highlights()
				return

		if is_instance_valid(target_card):
			target_card.queue_free()
		cards[target_pos.x][target_pos.y] = null

	var old_pos := player_pos
	cards[old_pos.x][old_pos.y] = null
	cards[target_pos.x][target_pos.y] = player_card
	player_card.grid_position = target_pos
	if CavernGameManager:
		CavernGameManager.player_position = target_pos

	await player_card.play_move_animation(_grid_to_pixel(target_pos))

	if CavernAudio:
		CavernAudio.play_sfx("move")

	await _shift_and_spawn_cards()

	if CavernGameManager:
		CavernGameManager.end_turn()

	while is_processing_explosions or _explosion_drain_running:
		await get_tree().process_frame

	_update_adjacent_highlights()
	_recover_if_softlocked()

	is_processing_move = false
	move_completed.emit()


func _shift_and_spawn_cards() -> void:
	var shift_tweens: Array[Tween] = []

	var empty_positions := _get_empty_positions()

	for empty_pos in empty_positions:
		if empty_pos == player_card.grid_position:
			continue

		var edge_card_info := _find_edge_card_to_shift(empty_pos)
		if edge_card_info.card != null:
			var card: Card = edge_card_info.card
			var from_pos: Vector2i = edge_card_info.from_pos

			if cards[from_pos.x][from_pos.y] != card:
				continue

			cards[from_pos.x][from_pos.y] = null
			cards[empty_pos.x][empty_pos.y] = card
			card.grid_position = empty_pos

			var tween := create_tween()
			tween.tween_property(card, "position", _grid_to_pixel(empty_pos), 0.15).set_ease(Tween.EASE_OUT)
			shift_tweens.append(tween)

	for tween in shift_tweens:
		if tween.is_running():
			await tween.finished

	var all_empty_edges := _get_empty_edge_positions()
	all_empty_edges.shuffle()

	var spawn_count := 0

	for pos in all_empty_edges:
		if spawn_count >= MAX_SPAWNS_PER_TURN:
			break
		if pos == player_card.grid_position:
			continue
		if cards[pos.x][pos.y] != null:
			continue

		var spawn_dir := _get_edge_spawn_direction(pos)
		var card := _create_random_card_for_position(pos)
		_place_card_internal(card, pos, false, Vector2i.ZERO)
		_play_edge_spawn_animation(card, spawn_dir)
		spawn_count += 1

	if spawn_count > 0:
		await get_tree().create_timer(0.2).timeout


func _create_random_card_for_position(pos: Vector2i, initial_fill: bool = false) -> Card:
	var roll := randf()
	var card: Card
	var bomb_count := _count_bombs()
	var allow_bomb := bomb_count < MAX_ACTIVE_BOMBS and not initial_fill

	if roll < 0.35:
		card = _create_card_instance()
		card.set_script(load("res://game/scripts/cards/enemy_card.gd"))
		var enemy := card as EnemyCard
		var difficulty := CavernGameManager.get_difficulty_scale() if CavernGameManager else 1.0
		enemy.setup_enemy(EnemyCard.get_random_enemy_type(), pos, difficulty)
	elif roll < 0.60:
		card = _create_card_instance()
		card.set_script(load("res://game/scripts/cards/jewel_card.gd"))
		var jewel := card as JewelCard
		jewel.setup_jewel(JewelCard.get_random_jewel_type(), pos)
	elif roll < 0.75:
		card = _create_card_instance()
		card.set_script(load("res://game/scripts/cards/item_card.gd"))
		var item := card as ItemCard
		item.setup_item(ItemCard.ItemType.HEALTH_POTION, pos)
	elif roll < 0.87:
		card = _create_card_instance()
		card.set_script(load("res://game/scripts/cards/item_card.gd"))
		var item := card as ItemCard
		item.setup_item(ItemCard.ItemType.SHIELD, pos)
	elif roll < 0.92 and allow_bomb:
		card = _create_card_instance()
		card.set_script(load("res://game/scripts/cards/bomb_card.gd"))
		var bomb := card as BombCard
		var difficulty := CavernGameManager.get_difficulty_scale() if CavernGameManager else 1.0
		var btype := BombCard.BombType.BOMB
		if SettingsManager.get_setting("gameplay", "diagonal_movement", false):
			btype = BombCard.get_random_bomb_type()
		else:
			if randf() < 0.35:
				btype = BombCard.BombType.DYNAMITE
		bomb.setup_bomb(btype, pos, difficulty)
		if btype == BombCard.BombType.DYNAMITE and not SettingsManager.get_setting("gameplay", "diagonal_movement", false):
			bomb.timer = 4
			bomb.card_value = 4
			bomb._update_visuals()
	else:
		card = _create_card_instance()
		card.set_script(load("res://game/scripts/cards/item_card.gd"))
		var item := card as ItemCard
		item.setup_item(ItemCard.get_random_item_type(), pos)
	
	return card


func _find_edge_card_to_shift(empty_pos: Vector2i) -> Dictionary:
	var edge_candidates: Array[Vector2i] = []
	
	for y in GRID_SIZE:
		edge_candidates.append(Vector2i(0, y))
		edge_candidates.append(Vector2i(GRID_SIZE - 1, y))
	for x in range(1, GRID_SIZE - 1):
		edge_candidates.append(Vector2i(x, 0))
		edge_candidates.append(Vector2i(x, GRID_SIZE - 1))
	
	var best_card: Card = null
	var best_pos := Vector2i(-1, -1)
	var best_dist := INF
	
	for pos in edge_candidates:
		if pos == player_card.grid_position:
			continue
		var card: Card = cards[pos.x][pos.y]
		if card != null and card != player_card:
			var dist: int = abs(pos.x - empty_pos.x) + abs(pos.y - empty_pos.y)
			if dist < best_dist:
				best_dist = dist
				best_card = card
				best_pos = pos
	
	return {"card": best_card, "from_pos": best_pos}


func _is_edge_position(pos: Vector2i) -> bool:
	return pos.x == 0 or pos.x == GRID_SIZE - 1 or pos.y == 0 or pos.y == GRID_SIZE - 1


func _get_empty_edge_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for y in GRID_SIZE:
		if cards[0][y] == null:
			result.append(Vector2i(0, y))
		if cards[GRID_SIZE - 1][y] == null:
			result.append(Vector2i(GRID_SIZE - 1, y))
	
	for x in range(1, GRID_SIZE - 1):
		if cards[x][0] == null:
			result.append(Vector2i(x, 0))
		if cards[x][GRID_SIZE - 1] == null:
			result.append(Vector2i(x, GRID_SIZE - 1))
	
	return result


## Called by BombCard — queues instead of running concurrently
func enqueue_explosion(explosion_data: Dictionary) -> void:
	_pending_explosions.append(explosion_data)
	if not _explosion_drain_running:
		_drain_explosions()


func _drain_explosions() -> void:
	_explosion_drain_running = true
	is_processing_explosions = true
	while not _pending_explosions.is_empty():
		var data: Dictionary = _pending_explosions.pop_front()
		await handle_explosion(data)
	await _shift_and_spawn_cards()
	_update_adjacent_highlights()
	_recover_if_softlocked()
	is_processing_explosions = false
	_explosion_drain_running = false
	grid_updated.emit()


func handle_explosion(explosion_data: Dictionary) -> void:
	var affected: Array = explosion_data.get("affected_positions", [])
	var damage: int = explosion_data.get("damage", 3)
	var source_pos: Vector2i = explosion_data.get("source_position", Vector2i.ZERO)

	if _is_valid_position(source_pos):
		var source_card: Card = cards[source_pos.x][source_pos.y]
		if source_card and source_card.card_type == Card.CardType.BOMB:
			if source_card.has_method("play_death_animation"):
				await source_card.play_death_animation()
			if is_instance_valid(source_card):
				source_card.queue_free()
			cards[source_pos.x][source_pos.y] = null

	for pos in affected:
		if not _is_valid_position(pos):
			continue

		var card: Card = cards[pos.x][pos.y]
		if card == null:
			continue

		if card == player_card:
			if CavernGameManager:
				CavernGameManager.take_damage(damage)
			player_card.play_damage_flash()
		elif card is EnemyCard:
			card.card_value -= damage
			if card.card_value <= 0:
				await card.play_death_animation()
				if is_instance_valid(card):
					card.queue_free()
				cards[pos.x][pos.y] = null
			else:
				card._update_visuals()
		else:
			if card.has_method("play_death_animation"):
				await card.play_death_animation()
			if is_instance_valid(card):
				card.queue_free()
			cards[pos.x][pos.y] = null


func _handle_blast_effect(positions: Array) -> void:
	for pos in positions:
		if not _is_valid_position(pos):
			continue
		
		var card: Card = cards[pos.x][pos.y]
		if card == null or card == player_card:
			continue
		
		await card.play_death_animation()
		card.queue_free()
		cards[pos.x][pos.y] = null


func _get_adjacent_positions(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var diagonals = SettingsManager.get_setting("gameplay", "diagonal_movement", false)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if not diagonals and absi(dx) + absi(dy) != 1:
				continue
			if diagonals and maxi(absi(dx), absi(dy)) != 1:
				continue
			var p := origin + Vector2i(dx, dy)
			if _is_valid_position(p):
				result.append(p)
	return result


func _is_adjacent_to_player(pos: Vector2i) -> bool:
	var player_pos := CavernGameManager.player_position if CavernGameManager else Vector2i(1, 1)
	var diff := pos - player_pos
	if SettingsManager.get_setting("gameplay", "diagonal_movement", false):
		return maxi(absi(diff.x), absi(diff.y)) == 1
	else:
		return absi(diff.x) + absi(diff.y) == 1


func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


func _get_empty_positions() -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if cards[x][y] == null:
				empty.append(Vector2i(x, y))
	return empty


func _grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * (cell_size.x + cell_padding) + cell_padding,
		grid_pos.y * (cell_size.y + cell_padding) + cell_padding
	)


func _reposition_all_cards() -> void:
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var card: Card = cards[x][y]
			if card:
				card.position = _grid_to_pixel(Vector2i(x, y))
				card.custom_minimum_size = cell_size
				card.size = cell_size


func _clear_empty_markers() -> void:
	for m in _empty_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	_empty_move_markers.clear()


func _update_adjacent_highlights() -> void:
	_clear_empty_markers()

	if not player_card:
		return

	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if cards[x][y]:
				var card: Card = cards[x][y]
				if card != player_card:
					card.set_highlight_adjacent(_is_adjacent_to_player(Vector2i(x, y)))

	for pos in _get_adjacent_positions(player_card.grid_position):
		if cards[pos.x][pos.y] != null:
			continue
		var marker := _make_empty_move_marker(pos)
		grid_container.add_child(marker)
		_empty_move_markers.append(marker)


func _make_empty_move_marker(pos: Vector2i) -> Control:
	var marker := Control.new()
	marker.position = _grid_to_pixel(pos)
	marker.custom_minimum_size = cell_size
	marker.size = cell_size
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	marker.z_index = 5

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.9, 0.4, 0.12)
	style.border_color = Color(1, 0.9, 0.4, 0.75)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	marker.add_child(panel)

	marker.gui_input.connect(func(event: InputEvent) -> void:
		if is_processing_move or is_processing_explosions:
			return
		var tap := false
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tap = true
		elif event is InputEventScreenTouch and event.pressed:
			tap = true
		if tap:
			_process_player_move(pos)
			marker.accept_event()
	)
	return marker


#NOTE: If somehow no adjacent target exists
func _recover_if_softlocked() -> void:
	if not player_card or not CavernGameManager or not CavernGameManager.is_game_active:
		return
	if is_processing_move or is_processing_explosions:
		return

	var adj := _get_adjacent_positions(player_card.grid_position)
	if adj.is_empty():
		return

	var only_lethal_bombs := true
	var any_empty := false
	for pos in adj:
		var c: Card = cards[pos.x][pos.y]
		if c == null:
			any_empty = true
			only_lethal_bombs = false
			break
		if c.card_type != Card.CardType.BOMB:
			only_lethal_bombs = false
			break
		var bomb := c as BombCard
		if bomb and bomb.timer > 1:
			only_lethal_bombs = false

	if any_empty:
		return

	if only_lethal_bombs and not CavernGameManager.undo_available:
		CavernGameManager.grant_emergency_undo()
		_update_adjacent_highlights()


func serialize_grid() -> Array:
	var result := []
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			if cards[x][y]:
				var card: Card = cards[x][y]
				if card != player_card:
					result.append(card.serialize())
	return result


func _restore_card(data: Dictionary) -> void:
	var pos := Vector2i(
		data.get("position", {}).get("x", 0),
		data.get("position", {}).get("y", 0)
	)
	var card_type: int = data.get("type", Card.CardType.EMPTY)
	var subtype: String = data.get("subtype", "")
	var value: int = data.get("value", 0)
	
	var card := _create_card_instance()
	
	match card_type:
		Card.CardType.ENEMY:
			card.set_script(load("res://game/scripts/cards/enemy_card.gd"))
			var enemy := card as EnemyCard
			enemy.setup_enemy(subtype, pos)
			enemy.card_value = value
			_place_card(enemy, pos)
		
		Card.CardType.ITEM:
			card.set_script(load("res://game/scripts/cards/item_card.gd"))
			var item := card as ItemCard
			var item_type := ItemCard.ItemType.HEALTH_POTION
			match subtype.to_upper():
				"POISON_POTION": item_type = ItemCard.ItemType.POISON_POTION
				"SHIELD": item_type = ItemCard.ItemType.SHIELD
				"BLAST_SCROLL": item_type = ItemCard.ItemType.BLAST_SCROLL
				"DIAGONAL_BLAST_SCROLL": item_type = ItemCard.ItemType.DIAGONAL_BLAST_SCROLL
			item.setup_item(item_type, pos)
			item.card_value = value
			_place_card(item, pos)
		
		Card.CardType.JEWEL:
			card.set_script(load("res://game/scripts/cards/jewel_card.gd"))
			var jewel := card as JewelCard
			jewel.setup_jewel(subtype, pos)
			_place_card(jewel, pos)
		
		Card.CardType.BOMB:
			card.set_script(load("res://game/scripts/cards/bomb_card.gd"))
			var bomb := card as BombCard
			var bomb_type := BombCard.BombType.BOMB if subtype == "bomb" else BombCard.BombType.DYNAMITE
			bomb.setup_bomb(bomb_type, pos)
			bomb.timer = value
			bomb.card_value = value
			_place_card(bomb, pos)


func restore_from_undo(undo_state: Dictionary) -> void:
	if undo_state.is_empty():
		return

	_clear_empty_markers()
	_pending_explosions.clear()
	is_processing_explosions = false
	_explosion_drain_running = false

	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var card: Card = cards[x][y]
			if card and card != player_card:
				card.queue_free()
				cards[x][y] = null
	
	var pos_data: Dictionary = undo_state.get("position", {"x": 1, "y": 1})
	var old_player_pos := Vector2i(int(pos_data.get("x", 1)), int(pos_data.get("y", 1)))
	var current_pos := CavernGameManager.player_position if CavernGameManager else Vector2i(1, 1)
	cards[current_pos.x][current_pos.y] = null
	cards[old_player_pos.x][old_player_pos.y] = player_card
	player_card.grid_position = old_player_pos
	player_card.position = _grid_to_pixel(old_player_pos)
	
	var grid_data: Array = undo_state.grid
	for card_data in grid_data:
		_restore_card(card_data)
	
	_update_adjacent_highlights()
