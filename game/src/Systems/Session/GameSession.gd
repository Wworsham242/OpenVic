extends Node

@export var _map_view: MapView
@export var _model_manager: ModelManager
@export var _game_session_menu: Control

const _MODERN_SPEED_INTERVALS: PackedFloat32Array = [
	1.0,
	0.5,
	0.25,
	0.125,
]

var _modern_paused := true
var _modern_speed_index := 0
var _modern_time_accumulator := 0.0


func _enter_tree() -> void:
	if not GameLoader.modern_mode:
		return

	for child_name: StringName in [&"ModelManager", &"BillboardManager", &"UICanvasLayer"]:
		var child := get_node_or_null(String(child_name))
		if child != null:
			remove_child(child)
			child.queue_free()

	print("WARGAME_MODERN_SESSION_PRUNED victoria_children=true")


func _ready() -> void:
	if GameLoader.modern_mode:
		var bootstrap_summary := _present_modern_province(1)
		if bootstrap_summary.is_empty():
			push_error("Modern semantic bootstrap proof failed.")
			return

		print(
			"WARGAME_MODERN_SEMANTIC_PROOF province=1 id=",
			bootstrap_summary[&"id"],
			" layer=", bootstrap_summary[&"layer"],
			" units=", bootstrap_summary[&"presented_unit_count"],
			" strength=", bootstrap_summary[&"presented_unit_strength"]
		)
		print("WARGAME_MODERN_SESSION_READY map_view_only=true")
		print(
			"WARGAME_MODERN_TIME_READY paused=true speed=1 ",
			"hour=", WargameBridge.hour(),
			" revision=", WargameBridge.presentation_revision()
		)
		return
	if GameSingleton.start_game_session() != OK:
		push_error("Failed to setup game")

	_model_manager.generate_units()
	_model_manager.generate_buildings()
	MusicManager.generate_playlist()
	MusicManager.select_next_song()
	# In game, the province selector uses the normal glove cursor.
	CursorManager.set_compat_cursor(&"normal", Input.CURSOR_IBEAM)


func _unhandled_input(event: InputEvent) -> void:
	if not GameLoader.modern_mode:
		return

	if event.is_action_pressed(&"time_pause"):
		_modern_paused = not _modern_paused
		_modern_time_accumulator = 0.0
		print(
			"WARGAME_MODERN_TIME_PAUSE paused=", _modern_paused,
			" hour=", WargameBridge.hour(),
			" revision=", WargameBridge.presentation_revision()
		)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"time_speed_increase"):
		_modern_speed_index = mini(
			_modern_speed_index + 1,
			_MODERN_SPEED_INTERVALS.size() - 1
		)
		_modern_time_accumulator = 0.0
		print("WARGAME_MODERN_TIME_SPEED speed=", _modern_speed_index + 1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"time_speed_decrease"):
		_modern_speed_index = maxi(_modern_speed_index - 1, 0)
		_modern_time_accumulator = 0.0
		print("WARGAME_MODERN_TIME_SPEED speed=", _modern_speed_index + 1)
		get_viewport().set_input_as_handled()
		return


func _notification(what: int) -> void:
	if GameLoader.modern_mode:
		return

	match what:
		NOTIFICATION_PREDELETE:
			if GameSingleton.end_game_session() != OK:
				push_error("Failed to end game session")


func _process(delta: float) -> void:
	if GameLoader.modern_mode:
		if _modern_paused:
			return

		_modern_time_accumulator += delta
		var interval := float(_MODERN_SPEED_INTERVALS[_modern_speed_index])

		while _modern_time_accumulator >= interval:
			_modern_time_accumulator -= interval

			var before_hour := WargameBridge.hour()
			var before_revision := WargameBridge.presentation_revision()

			if not WargameBridge.advance_hour():
				push_error(
					"Modern authoritative advance failed: ",
					WargameBridge.last_error()
				)
				_modern_paused = true
				return

			var after_hour := WargameBridge.hour()
			var after_revision := WargameBridge.presentation_revision()

			if after_hour != before_hour + 1:
				push_error(
					"Modern authoritative hour transition invalid: ",
					before_hour, "->", after_hour
				)
				_modern_paused = true
				return

			if after_revision <= before_revision:
				push_error(
					"Modern presentation revision did not advance: ",
					before_revision, "->", after_revision
				)
				_modern_paused = true
				return

			print(
				"WARGAME_MODERN_TIME_ADVANCE ",
				"hour=", before_hour, "->", after_hour,
				" revision=", before_revision, "->", after_revision,
				" speed=", _modern_speed_index + 1
			)

		return

	GameSingleton.update_clock()

# REQUIREMENTS:
# * SS-42


func _on_game_session_menu_button_pressed() -> void:
	_game_session_menu.visible = not _game_session_menu.visible


func _on_map_view_ready() -> void:
	if GameLoader.modern_mode:
		_map_view._camera.position = _map_view._map_to_world_coords(Vector2(0.5, 0.5))
		print("WARGAME_MODERN_MAPVIEW_READY camera=center")
		return

	# Set the camera's starting position
	_map_view._camera.position = _map_view._map_to_world_coords(
		# Start at the player country's capital position (when loading a save game in the lobby or
		# entering the actual game)
		PlayerSingleton.get_player_country_capital_position()
	)


func _on_map_view_province_hovered(province_number: int) -> void:
	_map_view.set_hovered_province_number(province_number)


func _on_map_view_province_unhovered() -> void:
	_map_view.unset_hovered_province()


func _present_modern_province(province_number: int) -> Dictionary:
	if province_number <= 0:
		return {}

	var stable_id := GameSingleton.get_stable_external_id_from_province_number(province_number)
	if stable_id.is_empty():
		push_error("No stable external ID for modern province number: ", province_number)
		return {}

	var summary: Dictionary = WargameBridge.presented_place_summary(stable_id)
	if summary.is_empty():
		push_error(
			"No observer-filtered WargameEngine presentation for ", stable_id,
			": ", WargameBridge.last_error()
		)
		return {}

	if not summary.get(&"exists", false):
		push_error("Presented place summary did not exist for ", stable_id)
		return {}

	if String(summary.get(&"id", "")) != stable_id:
		push_error(
			"Presented place identity mismatch: map=", stable_id,
			" engine=", summary.get(&"id", "")
		)
		return {}

	return summary


func _on_map_view_province_clicked(province_number: int) -> void:
	if GameLoader.modern_mode:
		var summary := _present_modern_province(province_number)
		if summary.is_empty():
			print("WARGAME_MODERN_PROVINCE_CLICK number=", province_number, " presented=false")
			return

		print(
			"WARGAME_MODERN_PROVINCE_CLICK number=", province_number,
			" id=", summary[&"id"],
			" layer=", summary[&"layer"],
			" units=", summary[&"presented_unit_count"],
			" strength=", summary[&"presented_unit_strength"]
		)
		return

	PlayerSingleton.set_selected_province_by_number(province_number)


func _on_map_view_province_right_clicked(province_number: int) -> void:
	if GameLoader.modern_mode:
		print("WARGAME_MODERN_PROVINCE_RIGHT_CLICK number=", province_number)
		return

	# TODO - open diplomacy screen on province owner or viewed country if province has no owner
	#Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
	PlayerSingleton.set_player_country_by_province_number(province_number)
