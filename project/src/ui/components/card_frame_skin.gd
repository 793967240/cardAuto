class_name CardFrameSkin extends TextureRect

const FRAME_TEXTURES: Dictionary = {
	0: preload("res://assets/ui/cards/card_frame_common.png"),
}

func setup_for_rarity(rarity: int) -> void:
	texture = FRAME_TEXTURES[0]
