extends VBoxContainer

@export var repository_root: String = ""
@export var observer_id: String = "modern:blue"
@export var actor_id: String = "modern:blue"

var _hour_label: Label
var _treasury_label: Label
var _approval_label: Label
var _checksum_label: Label
var _status_label: Label

func _ready() -> void:
    _hour_label = Label.new()
    _treasury_label = Label.new()
    _approval_label = Label.new()
    _checksum_label = Label.new()
    _status_label = Label.new()
    add_child(_hour_label)
    add_child(_treasury_label)
    add_child(_approval_label)
    add_child(_checksum_label)
    add_child(_status_label)

    var advance_button := Button.new()
    advance_button.text = "Advance WargameEngine 1 hour"
    advance_button.pressed.connect(_advance_hour)
    add_child(advance_button)

    if repository_root.is_empty():
        repository_root = OS.get_environment("WARGAME_ENGINE_ROOT")
    if repository_root.is_empty():
        _status_label.text = "Set repository_root or WARGAME_ENGINE_ROOT."
        return

    if not WargameBridge.initialize(repository_root, observer_id, 49374):
        _status_label.text = "WargameEngine load failed: %s" % WargameBridge.last_error()
        return

    _status_label.text = "WargameEngine authoritative host loaded."
    _refresh()


func _advance_hour() -> void:
    if not WargameBridge.advance_hour():
        _status_label.text = "Advance failed: %s" % WargameBridge.last_error()
        return
    _status_label.text = "Advanced through ScenarioHost authoritative command path."
    _refresh()


func _refresh() -> void:
    _hour_label.text = "Simulation hour: %d" % WargameBridge.hour()
    _treasury_label.text = "Actor treasury: %s" % WargameBridge.actor_treasury(actor_id)
    _approval_label.text = "Actor approval: %s" % WargameBridge.actor_approval(actor_id)
    _checksum_label.text = "World checksum: %s" % WargameBridge.checksum()
