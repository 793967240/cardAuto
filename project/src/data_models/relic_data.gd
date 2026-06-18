class_name RelicData extends Resource

enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName
@export var display_name_key: String
@export var desc_key: String
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var description_template: String
@export var icon: Texture2D

func get_name_key() -> String:
	return "relic.%s.name" % id

func get_desc_key() -> String:
	return "relic.%s.desc" % id
