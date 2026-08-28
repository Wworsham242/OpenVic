extends Node

# Requirements
# * FS-28

const save_directory_setting := &"openvic/data/saves_directory"

var current_save: SaveResource
var current_session_tag: StringName
var _save_dictionary: Dictionary = {}
var _dirty_save: SaveResource


func _ready() -> void:
	var saves_dir_path: String = ProjectSettings.get_setting_with_override(save_directory_setting)
	assert(saves_dir_path != null, "'%s' setting could not be found." % save_directory_setting)

	DirAccess.make_dir_recursive_absolute(saves_dir_path)
	var saves_dir := DirAccess.open(saves_dir_path)
	for file: String in saves_dir.get_files():
		var save := SaveResource.new()
		save.load_save(saves_dir_path.path_join(file))
		add_or_replace_save(save, true)


func get_save_file_name(
	save_name: StringName,
	session_tag: StringName = current_session_tag,
) -> StringName:
	return ("%s - %s" % [save_name, session_tag]).validate_filename()


func make_new_save(
	save_name: String,
	session_tag: StringName = current_session_tag,
) -> SaveResource:
	var file_name := get_save_file_name(save_name, session_tag) + ".tres"
	var new_save := SaveResource.new()
	new_save.set_file_path(
		save_name,
		ProjectSettings.get_setting_with_override(save_directory_setting).path_join(file_name),
	)
	print(new_save.file_path)
	new_save.session_tag = session_tag
	return new_save


func has_save(save_name: StringName, session_tag: StringName = current_session_tag) -> bool:
	return _save_dictionary.has(get_save_file_name(save_name, session_tag))


func add_or_replace_save(save: SaveResource, ignore_dirty: bool = false) -> void:
	var binded_func := _on_save_deleted_or_moved.bind(save)
	save.deleted.connect(binded_func)
	save.trash_moved.connect(binded_func)
	_save_dictionary[get_save_file_name(save.save_name, save.session_tag)] = save
	if not ignore_dirty:
		_dirty_save = save


func delete_save(save: SaveResource) -> void:
	save.delete()


func save_modern_world(save_name: String) -> Error:
	if not WargameBridge.is_loaded():
		push_error("Cannot save modern world: WargameBridge is not initialized.")
		return ERR_UNCONFIGURED

	var snapshot: PackedByteArray = WargameBridge.save_bytes()
	if snapshot.is_empty():
		push_error("Cannot save modern world: ", WargameBridge.last_error())
		return FAILED

	var saved_hour := WargameBridge.hour()
	var saved_checksum := WargameBridge.checksum()
	var saved_observer := WargameBridge.observer()

	var save := make_new_save(save_name)
	save.set_wargame_snapshot(
		snapshot,
		saved_hour,
		saved_checksum,
		saved_observer,
	)

	add_or_replace_save(save)

	var result := save.flush_save()
	if result != OK:
		push_error("Failed to write modern save: ", result)
		return result

	_dirty_save = null
	current_save = save

	print(
		"WARGAME_MODERN_SAVE_WRITTEN ",
		"name=", save.save_name,
		" hour=", saved_hour,
		" bytes=", snapshot.size(),
		" checksum=", saved_checksum,
	)

	return OK


func load_modern_world(save: SaveResource) -> Error:
	if save == null:
		push_error("Cannot load modern world: save is null.")
		return ERR_INVALID_PARAMETER

	var result := save.load_save()
	if result != OK:
		push_error("Failed to read modern save: ", result)
		return result

	if not save.has_wargame_snapshot():
		push_error("Selected save contains no WargameEngine snapshot.")
		return ERR_FILE_UNRECOGNIZED

	var repository_root := OS.get_environment("WARGAME_ENGINE_ROOT")
	if repository_root.is_empty():
		push_error("WARGAME_ENGINE_ROOT is not configured.")
		return ERR_UNCONFIGURED

	var snapshot := save.get_wargame_snapshot()
	var observer := save.get_wargame_observer()

	if snapshot.is_empty():
		push_error("Selected modern save contains an empty snapshot.")
		return ERR_FILE_CORRUPT

	if observer.is_empty():
		push_error("Selected modern save contains no observer.")
		return ERR_FILE_CORRUPT

	if not WargameBridge.restore_bytes(
		repository_root,
		observer,
		snapshot,
	):
		push_error("Cannot restore modern world: ", WargameBridge.last_error())
		return FAILED

	if WargameBridge.hour() != save.get_wargame_hour():
		push_error(
			"Restored modern save hour mismatch: expected ",
			save.get_wargame_hour(),
			", got ",
			WargameBridge.hour(),
		)
		return FAILED

	if WargameBridge.checksum() != save.get_wargame_checksum():
		push_error(
			"Restored modern save checksum mismatch: expected ",
			save.get_wargame_checksum(),
			", got ",
			WargameBridge.checksum(),
		)
		return FAILED

	current_save = save
	current_session_tag = save.session_tag

	print(
		"WARGAME_MODERN_SAVE_LOADED ",
		"name=", save.save_name,
		" hour=", WargameBridge.hour(),
		" checksum=", WargameBridge.checksum(),
	)

	return OK


func flush_save() -> void:
	if _dirty_save == null: return
	_dirty_save.flush_save()
	_dirty_save = null


func _on_save_deleted_or_moved(save: SaveResource) -> void:
	_save_dictionary.erase(get_save_file_name(save.save_name, save.session_tag))
