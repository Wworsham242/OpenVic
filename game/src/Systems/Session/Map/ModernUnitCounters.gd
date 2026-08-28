class_name ModernUnitCounters
extends MultiMeshInstance3D

const HEIGHT_OFFSET := Vector3(0.0, 0.01, 0.0)
const STRATEGIC_SCALE := Vector3(0.055, 0.055, 0.055)
const DETAILED_SCALE := Vector3(0.035, 0.035, 0.035)

var _map_view
var _place_ids := PackedStringArray()
var _stack_unit_ids: Array[PackedStringArray] = []
var _strategic_mode := true

func configure(map_view) -> void:
    _map_view = map_view

func clear_counters() -> void:
    _place_ids = PackedStringArray()
    _stack_unit_ids.clear()

    if multimesh != null:
        multimesh.instance_count = 0
        multimesh.visible_instance_count = 0

func set_strategic_mode(strategic: bool) -> void:
    _strategic_mode = strategic
    _apply_scales()

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
    _stack_unit_ids = stack_unit_ids

    if multimesh == null:
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

    multimesh.instance_count = positions.size()
    multimesh.visible_instance_count = positions.size()

    var scale := STRATEGIC_SCALE if _strategic_mode else DETAILED_SCALE

    for index in range(positions.size()):
        var world_position: Vector3 = _map_view._map_to_world_coords(positions[index]) + HEIGHT_OFFSET
        multimesh.set_instance_transform(
            index,
            Transform3D(Basis().scaled(scale), world_position)
        )

    return true

func get_stack_unit_ids(index: int) -> PackedStringArray:
    if index < 0 or index >= _stack_unit_ids.size():
        return PackedStringArray()

    return _stack_unit_ids[index]

func get_stack_place_id(index: int) -> String:
    if index < 0 or index >= _place_ids.size():
        return ""

    return _place_ids[index]

func _apply_scales() -> void:
    if multimesh == null:
        return

    var scale := STRATEGIC_SCALE if _strategic_mode else DETAILED_SCALE

    for index in range(multimesh.instance_count):
        var transform := multimesh.get_instance_transform(index)
        transform.basis = Basis().scaled(scale)
        multimesh.set_instance_transform(index, transform)