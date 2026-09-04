extends CanvasLayer

# LIVE-ECONOMY-006
# Presentation only. This node owns no economy state and issues no commands.
# All displayed values are snapshots read from the authoritative InstanceManager
# through GameSingleton.

var _panel: PanelContainer
var _tick_label: Label
var _production_label: Label
var _constraint_label: Label
var _inventory_label: Label
var _corridor_label: Label
var _market_label: Label


func _ready() -> void:
	layer = 90

	_panel = PanelContainer.new()
	_panel.name = "LiveEconomyPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-390.0, 54.0)
	_panel.custom_minimum_size = Vector2(370.0, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var title := Label.new()
	title.text = "MODERN ECONOMY"
	title.add_theme_font_size_override("font_size", 17)
	column.add_child(title)

	_tick_label = Label.new()
	_production_label = Label.new()
	_constraint_label = Label.new()
	_inventory_label = Label.new()
	_corridor_label = Label.new()
	_market_label = Label.new()

	_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_market_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	column.add_child(_tick_label)
	column.add_child(_production_label)
	column.add_child(_constraint_label)
	column.add_child(HSeparator.new())
	column.add_child(_inventory_label)
	column.add_child(_corridor_label)
	column.add_child(HSeparator.new())
	column.add_child(_market_label)

	GameSingleton.gamestate_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var status: Dictionary = GameSingleton.get_live_economy_status()
	var configured := bool(status.get(&"configured", false))

	_panel.visible = configured
	if not configured:
		return

	var ticks := int(status.get(&"completed_daily_ticks", 0))
	var upstream := float(status.get(&"upstream_output", 0.0))
	var desired := float(status.get(&"downstream_desired_output", 0.0))
	var downstream := float(status.get(&"downstream_output", 0.0))
	var limited := bool(status.get(&"downstream_input_limited", false))

	var upstream_inventory := float(
		status.get(&"intermediate_upstream_inventory", 0.0)
	)
	var downstream_inventory := float(
		status.get(&"intermediate_downstream_inventory", 0.0)
	)
	var final_inventory := float(status.get(&"final_inventory", 0.0))

	var capacity := float(status.get(&"corridor_capacity", 0.0))
	var deliverable := float(status.get(&"deliverable_intermediate", 0.0))

	var price := float(status.get(&"intermediate_price", 0.0))
	var supply := float(status.get(&"intermediate_supply_yesterday", 0.0))
	var demand := float(status.get(&"intermediate_demand_yesterday", 0.0))
	var traded := float(
		status.get(&"intermediate_quantity_traded_yesterday", 0.0)
	)

	_tick_label.text = "Daily ticks: %d" % ticks
	_production_label.text = (
		"Steel output: %.2f    Machinery: %.2f / %.2f"
		% [upstream, downstream, desired]
	)
	_constraint_label.text = (
		"Production constraint: %s"
		% ("INPUT LIMITED" if limited else "none")
	)
	_inventory_label.text = (
		"Steel inventory â€” source: %.2f    destination: %.2f\n"
		+ "Machinery inventory: %.2f"
	) % [upstream_inventory, downstream_inventory, final_inventory]
	_corridor_label.text = (
		"Corridor: %.2f capacity    %.2f deliverable"
		% [capacity, deliverable]
	)
	_market_label.text = (
		"Steel market â€” price: %.3f\n"
		+ "Yesterday â€” supply: %.2f    demand: %.2f    traded: %.2f"
	) % [price, supply, demand, traded]