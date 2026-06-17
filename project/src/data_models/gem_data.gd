class_name GemData extends Resource

enum Trigger { PASSIVE, ON_PLAY, ON_CYCLE }

@export var id: StringName
@export var display_name_key: String
@export var desc_key: String

@export var trigger: Trigger = Trigger.PASSIVE

@export var tags: Array[StringName] = []
@export var mutex_tags: Array[StringName] = []

@export var effect: GemEffect

@export_multiline var description_template: String
@export var icon: Texture2D

func get_name_key() -> String:
	return "gem.%s.name" % id

func get_desc_key() -> String:
	return "gem.%s.desc" % id

func is_mutex_with(other: GemData) -> bool:
	if other == null:
		return false
	for tag in tags:
		if tag in other.mutex_tags:
			return true
	for mt in mutex_tags:
		if mt in other.tags:
			return true
	return false
