# src/core/effects/traits/trait_effect_cost_reduction.gd
# 词条效果：cost -X
# 阶段 2 §2.1
# 典型词条：迅捷（swift_strike）— 该槽位的卡 cost -1
class_name TraitEffectCostReduction extends TraitEffect

@export var reduction: int = 1
@export var require_tags: Array[StringName] = []

func modify_cost(card: CardRuntime, base: int) -> int:
	if not _matches(card):
		return base
	return base - reduction

func _matches(card: CardRuntime) -> bool:
	if require_tags.is_empty():
		return true
	if card == null or card.data == null:
		return false
	for tag in require_tags:
		if tag in card.data.tags:
			return true
	return false
