class_name GemInstance extends RefCounted

var data: GemData

func _init(gem_data: GemData) -> void:
	data = gem_data

func get_effect() -> GemEffect:
	return data.effect if data else null
