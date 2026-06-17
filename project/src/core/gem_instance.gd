class_name GemInstance extends RefCounted

static var _next_instance_id: int = 1

var data: GemData
var instance_id: StringName = &""

func _init(gem_data: GemData, id: StringName = &"") -> void:
	data = gem_data
	if id != &"":
		instance_id = id
	else:
		instance_id = StringName("gem_%d" % _next_instance_id)
		_next_instance_id += 1

func get_effect() -> GemEffect:
	return data.effect if data else null

func get_id() -> StringName:
	return data.id if data else &""
