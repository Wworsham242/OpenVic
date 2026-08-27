class_name ModernMapLoader
extends RefCounted

const DEFAULT_MAP_PATH: String = "res://data/wargame/modern-map/bootstrap-map.json"


static func load_default_map() -> Error:
	var file := FileAccess.open(DEFAULT_MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open modern map package: ", DEFAULT_MAP_PATH)
		return FileAccess.get_open_error()

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Modern map package root must be a Dictionary.")
		return ERR_PARSE_ERROR

	var data: Dictionary = parsed

	const required_keys: Array[StringName] = [
		&"format_version",
		&"width",
		&"height",
		&"stable_external_ids",
		&"province_number_raster",
		&"terrain_raster",
	]

	for key: StringName in required_keys:
		if not data.has(key):
			push_error("Modern map package missing key: ", key)
			return ERR_INVALID_DATA

	if int(data[&"format_version"]) != 1:
		push_error("Unsupported modern map format version.")
		return ERR_INVALID_DATA

	var width := int(data[&"width"])
	var height := int(data[&"height"])
	if width <= 0 or height <= 0:
		push_error("Modern map dimensions must be positive.")
		return ERR_INVALID_DATA

	var stable_ids := PackedStringArray()
	for value: Variant in data[&"stable_external_ids"]:
		stable_ids.append(String(value))

	var province_raster := PackedInt32Array()
	for value: Variant in data[&"province_number_raster"]:
		province_raster.append(int(value))

	var terrain_raster := PackedByteArray()
	for value: Variant in data[&"terrain_raster"]:
		terrain_raster.append(int(value))

	var expected_pixel_count := width * height
	if province_raster.size() != expected_pixel_count:
		push_error("Modern province raster size mismatch.")
		return ERR_INVALID_DATA

	if terrain_raster.size() != expected_pixel_count:
		push_error("Modern terrain raster size mismatch.")
		return ERR_INVALID_DATA

	var map_result := GameSingleton.load_modern_map(
		Vector2i(width, height),
		province_raster,
		stable_ids
	)

	if map_result != OK:
		push_error("GameSingleton.load_modern_map failed: ", map_result)
		return map_result

	var render_result := GameSingleton.load_modern_map_render_data(terrain_raster)
	if render_result != OK:
		push_error("GameSingleton.load_modern_map_render_data failed: ", render_result)
		return render_result

	if not GameSingleton.is_modern_map_active():
		push_error("Modern map provider did not become active.")
		return FAILED

	var pick_alpha := GameSingleton.get_province_number_from_uv_coords(Vector2(0.125, 0.125))
	var pick_bravo := GameSingleton.get_province_number_from_uv_coords(Vector2(0.50, 0.125))
	var pick_charlie := GameSingleton.get_province_number_from_uv_coords(Vector2(0.125, 0.75))
	var pick_delta := GameSingleton.get_province_number_from_uv_coords(Vector2(0.50, 0.75))

	if pick_alpha != 1 or pick_bravo != 2 or pick_charlie != 3 or pick_delta != 4:
		push_error(
			"Modern map deterministic pick proof failed: ",
			pick_alpha, ",", pick_bravo, ",", pick_charlie, ",", pick_delta
		)
		return FAILED

	print(
		"WARGAME_MODERN_MAP_PACKAGE_LOADED dims=", width, "x", height,
		" provinces=", stable_ids.size(),
		" picks=", pick_alpha, ",", pick_bravo, ",", pick_charlie, ",", pick_delta
	)

	return OK
