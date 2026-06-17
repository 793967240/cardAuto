class_name RelicData extends Resource

@export var id: StringName
@export var display_name_key: String
@export var desc_key: String
@export_multiline var description_template: String
@export var icon: Texture2D

func get_name_key() -> String:
	return "relic.%s.name" % id

func get_desc_key() -> String:
	return "relic.%s.desc" % id
