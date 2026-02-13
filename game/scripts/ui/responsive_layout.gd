class_name CavernResponsiveLayout
extends Control
## portrait layout, others later if needed

@onready var top_bar: Control = %TopBar
@onready var grid_holder: Control = $GridHolder if has_node("GridHolder") else null

func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	call_deferred("_update_layout")

func _update_layout() -> void:
	#var vp_size := get_viewport_rect().size
	var bar_height := 56.0
	
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = bar_height
	
	grid_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_holder.offset_top = bar_height + 8
	grid_holder.offset_bottom = -8
