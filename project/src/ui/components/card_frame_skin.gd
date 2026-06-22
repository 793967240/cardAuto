class_name CardFrameSkin extends TextureRect

const FRAME_TEXTURES: Dictionary = {
	0: preload("res://assets/ui/cards/card_frame_common.png"),
	1: preload("res://assets/ui/cards/card_frame_uncommon.png"),
	2: preload("res://assets/ui/cards/card_frame_rare.png"),
	3: preload("res://assets/ui/cards/card_frame_rare.png"),
}

func setup_for_rarity(rarity: int) -> void:
	texture = FRAME_TEXTURES.get(rarity, FRAME_TEXTURES[0])
