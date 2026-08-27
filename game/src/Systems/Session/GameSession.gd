extends Node

@export var _map_view: MapView
@export var _model_manager: ModelManager
@export var _game_session_menu: Control


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
		print("WARGAME_MODERN_SESSION_READY map_view_only=true")
		return
	if GameSingleton.start_game_session() != OK:
		push_error("Failed to setup game")

	_model_manager.generate_units()
	_model_manager.generate_buildings()
	MusicManager.generate_playlist()
	MusicManager.select_next_song()
	# In game, the province selector uses the normal glove cursor.
	CursorManager.set_compat_cursor(&"normal", Input.CURSOR_IBEAM)


func _notification(what: int) -> void:
	if GameLoader.modern_mode:
		return

	match what:
		NOTIFICATION_PREDELETE:
			if GameSingleton.end_game_session() != OK:
				push_error("Failed to end game session")


func _process(_delta: float) -> void:
	if GameLoader.modern_mode:
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


func _on_map_view_province_clicked(province_number: int) -> void:
	if GameLoader.modern_mode:
		print("WARGAME_MODERN_PROVINCE_CLICK number=", province_number)
		return

	PlayerSingleton.set_selected_province_by_number(province_number)


func _on_map_view_province_right_clicked(province_number: int) -> void:
	if GameLoader.modern_mode:
		print("WARGAME_MODERN_PROVINCE_RIGHT_CLICK number=", province_number)
		return

	# TODO - open diplomacy screen on province owner or viewed country if province has no owner
	#Events.NationManagementScreens.open_nation_management_screen(NationManagement.Screen.DIPLOMACY)
	PlayerSingleton.set_player_country_by_province_number(province_number)
