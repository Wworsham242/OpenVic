extends Node

var ShaderManager: ShaderManagerClass
var modern_mode: bool


func _init() -> void:
	ShaderManager = ShaderManagerClass.new()
	modern_mode = ArgumentParser.get_option_value(&"modern")
