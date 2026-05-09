# src/core/effects/traits/trait_effect_fragile_cost.gd
# 词条效果：cost -1 但每次打出 owner 失血 N
# 阶段 2 §2.1 / GDD §3.5 取舍型
# 典型词条：脆刃（fragile_edge）— 该槽位的卡 cost -1，但打出时 owner -1 HP
#
# 演示「PASSIVE 修饰 + ON_PLAY 副作用」组合在同一词条上的可行性
# Trigger 设为 PASSIVE 时事件 hook 不会被 chain 调用 → 改设 ON_PLAY，
# 同时仍 override modify_cost（被 _effective_cost 在 PASSIVE 检查中调用）
#
# **重要发现**：Chain._effective_cost 仅在 trigger==PASSIVE 时调 modify_cost。
# 所以如果想让一个词条同时有 PASSIVE 修饰和 ON_PLAY 副作用，要么改架构（移除 trigger
# 检查、让所有 trait 都参与 modify_*），要么拆成两个词条。
# 阶段 2 决议：拆成两个词条更清晰，本类示范前一种用法 — 仅 PASSIVE.modify_cost
# 副作用通过 effect_apply_status 在卡牌层实现（不属于词条）
class_name TraitEffectFragileCost extends TraitEffect

@export var reduction: int = 1
@export var owner_hp_loss: int = 1

func modify_cost(_card: CardRuntime, base: int) -> int:
	return base - reduction

# 注：本词条 trigger 设 PASSIVE，下面 hook 不会被 chain 调用
# 真正的"打出失血"副作用需要在卡牌层 effect 处理或拆词条
# 此处保留 hook 占位以便阶段 3 重构
