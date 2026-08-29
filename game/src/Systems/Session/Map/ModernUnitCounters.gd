class_name ModernUnitCounters
extends MultiMeshInstance3D

const HEIGHT_OFFSET := Vector3(0.0, 0.01, 0.0)
const STRATEGIC_SCALE := Vector3(0.055, 0.055, 0.055)
const DETAILED_SCALE := Vector3(0.035, 0.035, 0.035)
const DETAILED_SPACING := 0.045

var _map_view
var _place_ids := PackedStringArray()
var _positions := PackedVector2Array()
var _stack_unit_ids: Array[PackedStringArray] = []
var _visible_unit_ids := PackedStringArray()
var _visible_place_ids := PackedStringArray()
var _visible_world_positions := PackedVector3Array()
var _strategic_mode := true

func configure(map_view) -> void:
    _map_view = map_view


func clear_counters() -> void:
    _place_ids = PackedStringArray()
    _positions = PackedVector2Array()
    _stack_unit_ids.clear()
    _visible_unit_ids = PackedStringArray()
    _visible_place_ids = PackedStringArray()
    _visible_world_positions = PackedVector3Array()

    if multimesh != null:
        multimesh.instance_count = 0
        multimesh.visible_instance_count = 0


func set_strategic_mode(strategic: bool) -> void:
    if _strategic_mode == strategic:
        return

    _strategic_mode = strategic
    _rebuild_instances()


func set_counters(
    place_ids: PackedStringArray,
    positions: PackedVector2Array,
    stack_unit_ids: Array[PackedStringArray]
) -> bool:
    if _map_view == null:
        push_error("ModernUnitCounters has no MapView.")
        return false

    if place_ids.size() != positions.size() or place_ids.size() != stack_unit_ids.size():
        push_error("ModernUnitCounters packed columns have mismatched lengths.")
        return false

    _place_ids = place_ids
    _positions = positions
    _stack_unit_ids = stack_unit_ids

    _ensure_multimesh()
    _rebuild_instances()
    return true


func get_stack_unit_ids(index: int) -> PackedStringArray:
    if index < 0 or index >= _stack_unit_ids.size():
        return PackedStringArray()

    return _stack_unit_ids[index]


func get_stack_place_id(index: int) -> String:
    if index < 0 or index >= _place_ids.size():
        return ""

    return _place_ids[index]


func get_stack_unit_ids_by_place_id(place_id: String) -> PackedStringArray:
    var index := _place_ids.find(place_id)
    if index < 0:
        return PackedStringArray()

    return _stack_unit_ids[index]


func get_visible_unit_id(index: int) -> String:
    if index < 0 or index >= _visible_unit_ids.size():
        return ""

    return _visible_unit_ids[index]


func get_visible_place_id(index: int) -> String:
    if index < 0 or index >= _visible_place_ids.size():
        return ""

    return _visible_place_ids[index]


func get_visible_world_position(index: int) -> Vector3:
    if index < 0 or index >= _visible_world_positions.size():
        return Vector3.ZERO

    return _visible_world_positions[index]


func get_visible_instance_count() -> int:
    return _visible_place_ids.size()


func is_strategic_mode() -> bool:
    return _strategic_mode


func _ensure_multimesh() -> void:
    if multimesh != null:
        return

    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D

    var quad := QuadMesh.new()
    quad.size = Vector2(1.0, 1.0)

    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.9, 0.9, 0.9, 0.92)
    quad.material = material
    multimesh.mesh = quad


func _rebuild_instances() -> void:
    if _map_view == null:
        return

    _ensure_multimesh()

    if _strategic_mode:
        _rebuild_strategic_instances()
    else:
        _rebuild_detailed_instances()


func _rebuild_strategic_instances() -> void:
    _visible_unit_ids = PackedStringArray()
    _visible_place_ids = PackedStringArray()
    _visible_world_positions = PackedVector3Array()

    multimesh.instance_count = _positions.size()
    multimesh.visible_instance_count = _positions.size()

    for index in range(_positions.size()):
        var world_position: Vector3 = _map_view._map_to_world_coords(_positions[index]) + HEIGHT_OFFSET
        multimesh.set_instance_transform(
            index,
            Transform3D(Basis().scaled(STRATEGIC_SCALE), world_position)
        )

        _visible_unit_ids.push_back("")
        _visible_place_ids.push_back(_place_ids[index])
        _visible_world_positions.push_back(world_position)


func _rebuild_detailed_instances() -> void:
    _visible_unit_ids = PackedStringArray()
    _visible_place_ids = PackedStringArray()
    _visible_world_positions = PackedVector3Array()

    var total_formations := 0
    for stack_ids: PackedStringArray in _stack_unit_ids:
        total_formations += stack_ids.size()

    multimesh.instance_count = total_formations
    multimesh.visible_instance_count = total_formations

    var instance_index := 0

    for stack_index in range(_place_ids.size()):
        var stack_ids: PackedStringArray = _stack_unit_ids[stack_index]
        var base_world: Vector3 = _map_view._map_to_world_coords(_positions[stack_index]) + HEIGHT_OFFSET
        var center := (float(stack_ids.size()) - 1.0) * 0.5

        for formation_index in range(stack_ids.size()):
            var offset_x := (float(formation_index) - center) * DETAILED_SPACING
            var world_position := base_world + Vector3(offset_x, 0.0, 0.0)

            multimesh.set_instance_transform(
                instance_index,
                Transform3D(Basis().scaled(DETAILED_SCALE), world_position)
            )

            _visible_unit_ids.push_back(stack_ids[formation_index])
            _visible_place_ids.push_back(_place_ids[stack_index])
            _visible_world_positions.push_back(world_position)
            instance_index += 1
