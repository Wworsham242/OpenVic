extends SceneTree

func _initialize() -> void:
	var vic2_path := OS.get_environment("OPENVIC_VIC2_PATH")
	if vic2_path.is_empty():
		push_error("OPENVIC_VIC2_PATH not set")
		quit(2)
		return

	var err := GameSingleton.set_compatibility_mode_roots(vic2_path)
	if err != OK:
		push_error("set_compatibility_mode_roots failed: %s" % err)
		quit(3)
		return

	err = GameSingleton.load_defines_compatibility_mode()
	if err != OK:
		push_error("load_defines_compatibility_mode failed: %s" % err)
		quit(4)
		return

	var bookmarks := GameSingleton.get_bookmark_info()
	if bookmarks.is_empty():
		push_error("No bookmarks loaded")
		quit(5)
		return

	err = GameSingleton.setup_game(0)
	if err != OK:
		push_error("setup_game failed: %s" % err)
		quit(6)
		return

	if not GameSingleton.is_live_economy_configured():
		push_error("Live economy was not configured from application overlay")
		quit(7)
		return

	err = GameSingleton.start_game_session()
	if err != OK:
		push_error("start_game_session failed: %s" % err)
		quit(8)
		return

	print("LIVE-ECONOMY-004 REAL SESSION SMOKE: PASS")
	GameSingleton.end_game_session()
	quit(0)