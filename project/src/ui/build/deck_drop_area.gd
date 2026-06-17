class_name DeckDropArea extends GridContainer

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	return String(data.get("source", "")) == "slot" and int(data.get("slot_index", -1)) >= 0

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var on_drop: Callable = get_meta(&"on_drop", Callable())
	if on_drop.is_valid():
		on_drop.call(data)
