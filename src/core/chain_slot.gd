class_name ChainSlot extends RefCounted

var card: CardRuntime
var gems: Array = []  # Array[GemInstance]
var base_id: StringName = &""

func _init(c: CardRuntime, base: StringName = &"") -> void:
	card = c
	base_id = base

func active_gems() -> Array:
	return gems
