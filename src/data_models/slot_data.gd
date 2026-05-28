class_name SlotData extends Resource

@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export var gem_socket_count: int = 1

func serialize() -> Dictionary:
	return {
		"id": id,
		"gem_socket_count": gem_socket_count,
	}
