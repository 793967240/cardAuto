# src/core/effects/traits/trait_effect_damage_bonus.gd
# 词条效果：所有卡牌伤害 +X
# 阶段 2 §2.1 / TC-2-DATA-003
# 典型词条：锋锐（sharp_blade）— 该槽位的卡 +2 伤害
class_name TraitEffectDamageBonus extends TraitEffect

@export var bonus: int = 2
## 仅修饰带指定 tag 的卡（空数组 = 修饰所有卡）
@export var require_tags: Array[StringName] = []

func modify_damage(card: CardRuntime, base: int) -> int:
	if not _matches(card):
		return base
	return base + bonus

func _matches(card: CardRuntime) -> bool:
	if require_tags.is_empty():
		return true
	if card == null or card.data == null:
		return false
	for tag in require_tags:
		if tag in card.data.tags:
			return true
	return false
