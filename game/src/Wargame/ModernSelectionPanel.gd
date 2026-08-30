extends PanelContainer

# Presentation-only UI. All simulation truth comes through WargameBridge;
# this node owns no authoritative world state.

var _title: Label
var _place_line: Label
var _strength_line: Label
var _time_line: Label
var _formation_list: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	_title = Label.new()
	_title.text = "Modern Selection"
	_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_title)

	_place_line = Label.new()
	column.add_child(_place_line)

	_strength_line = Label.new()
	column.add_child(_strength_line)

	_time_line = Label.new()
	column.add_child(_time_line)

	var separator := HSeparator.new()
	column.add_child(separator)

	var formations_heading := Label.new()
	formations_heading.text = "Observed formations"
	formations_heading.add_theme_font_size_override("font_size", 16)
	column.add_child(formations_heading)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330.0, 220.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_formation_list = VBoxContainer.new()
	_formation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_formation_list)


func clear_selection() -> void:
	visible = false
	_clear_formations()


func show_selection(
	summary: Dictionary,
	unit_ids: PackedStringArray,
	unit_details_by_id: Dictionary,
	hour: int,
	revision: int
) -> void:
	var place_id := String(summary.get(&"id", ""))
	var layer := String(summary.get(&"layer", ""))
	var total_strength := int(summary.get(&"presented_unit_strength", 0))
	var presented_count := int(summary.get(&"presented_unit_count", 0))

	_title.text = place_id if not place_id.is_empty() else "Modern Selection"
	_place_line.text = "Layer: %s" % layer
	_strength_line.text = "Observed formations: %d    Estimated strength: %d" % [
		presented_count,
		total_strength,
	]
	_time_line.text = "Hour %d    Presentation revision %d" % [hour, revision]

	_clear_formations()

	if unit_ids.is_empty():
		var empty := Label.new()
		empty.text = "No observed formations at this location."
		_formation_list.add_child(empty)
	else:
		for unit_id: String in unit_ids:
			var details: Dictionary = unit_details_by_id.get(unit_id, {})
			var actor := String(details.get(&"actor", "unknown"))
			var estimated_strength := int(details.get(&"estimated_strength", 0))
			var confidence := int(details.get(&"confidence", 0))
			var movement_state := int(details.get(&"movement_state", 0))

			var row := Label.new()
			row.text = "%s\n  actor=%s  strength=%d  confidence=%d  movement=%d" % [
				unit_id,
				actor,
				estimated_strength,
				confidence,
				movement_state,
			]
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_formation_list.add_child(row)

	visible = true


func _clear_formations() -> void:
	if _formation_list == null:
		return

	for child: Node in _formation_list.get_children():
		_formation_list.remove_child(child)
		child.queue_free()