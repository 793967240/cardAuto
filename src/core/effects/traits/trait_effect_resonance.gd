# src/core/effects/traits/trait_effect_resonance.gd
# 词条效果：共鸣型 — 链条中每有一张同 tag 卡，所有同 tag 卡 +X 伤害
# 阶段 2 §2.1 / GDD §3.5 共鸣型
# 典型词条：火焰光环（flame_aura）— 链条每有一张「火」标签卡，所有火卡 +1 伤
class_name TraitEffectResonance extends TraitEffect

@export var per_card_bonus: int = 1
@export var require_tag: StringName = &"fire"

## override 带 chain 上下文版本，扫描整链同 tag 卡数
func modify_damage_with_chain(card: CardRuntime, base: int, chain) -> int:
	if card == null or card.data == null:
		return base
	if not (require_tag in card.data.tags):
		return base
	if chain == null:
		return base
	var count := 0
	for cs in chain.layout:
		var slot: ChainSlot = cs
		if slot == null or slot.card == null or slot.card.data == null:
			continue
		if require_tag in slot.card.data.tags:
			count += 1
	return base + per_card_bonus * count
