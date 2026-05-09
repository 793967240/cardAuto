# src/core/effects/traits/trait_effect_chain_end_replay.gd
# 词条效果：一轮链条结束时，重新触发指定槽位的卡
# 阶段 2 §2.1 / GDD §3.5 节奏型
# 典型词条：连击气（combo_breath）— 修整结束时重新触发链条最后一张卡
#
# 注意：on_chain_ended 在 _restart_chain 中调用，此时 layout 还在
# 但 owner.chain.current_index 已被重置为 0 → 用 layout.size() - 1 取末位
class_name TraitEffectChainEndReplay extends TraitEffect

@export var slot_offset_from_end: int = 0  # 0 = 链条最后一张；1 = 倒数第二张
@export var max_triggers_per_battle: int = 99

var _triggered_count: int = 0

func on_chain_ended(ctx: BattleContext, owner: Combatant) -> void:
	if owner == null or owner.chain == null:
		return
	if _triggered_count >= max_triggers_per_battle:
		return
	var idx := owner.chain.layout.size() - 1 - slot_offset_from_end
	if idx < 0 or idx >= owner.chain.layout.size():
		return
	var slot: ChainSlot = owner.chain.layout[idx]
	if slot == null or slot.card == null or slot.card.data == null:
		return
	_triggered_count += 1
	if slot.card.data.effect:
		slot.card.data.effect.fire(ctx, owner)

func reset() -> void:
	_triggered_count = 0
