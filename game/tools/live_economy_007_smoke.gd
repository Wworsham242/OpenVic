extends SceneTree

func fail(message: String, code: int) -> void:
	push_error(message)
	quit(code)

func _initialize() -> void:
	var vic2_path := OS.get_environment("OPENVIC_VIC2_PATH")
	if vic2_path.is_empty():
		fail("OPENVIC_VIC2_PATH not set", 2)
		return

	var panel_host := root.get_node_or_null("LiveEconomyPanel")
	if panel_host == null:
		fail("LiveEconomyPanel autoload was not instantiated", 3)
		return

	var err := GameSingleton.set_compatibility_mode_roots(vic2_path)
	if err != OK:
		fail("set_compatibility_mode_roots failed: %s" % err, 4)
		return

	err = GameSingleton.load_defines_compatibility_mode()
	if err != OK:
		fail("load_defines_compatibility_mode failed: %s" % err, 5)
		return

	var bookmarks := GameSingleton.get_bookmark_info()
	if bookmarks.is_empty():
		fail("No bookmarks loaded", 6)
		return

	err = GameSingleton.setup_game(0)
	if err != OK:
		fail("setup_game failed: %s" % err, 7)
		return

	var status: Dictionary = GameSingleton.get_live_economy_status()
	if not bool(status.get(&"configured", false)):
		fail("Modern live economy was not configured", 8)
		return

	err = GameSingleton.start_game_session()
	if err != OK:
		fail("start_game_session failed: %s" % err, 9)
		return

	panel_host.call("_refresh")
	var visible_panel := panel_host.get_node_or_null("LiveEconomyPanel")
	if visible_panel == null or not visible_panel.visible:
		GameSingleton.end_game_session()
		fail("Live economy presentation did not become visible", 10)
		return

	print("LIVE-ECONOMY-007 REAL GODOT SESSION/UI SMOKE: PASS")
	GameSingleton.end_game_session()
	quit(0)