# src/core/card_runtime.gd
# 卡牌运行时实例 - 持有 CardData 引用和运行时状态
class_name CardRuntime extends RefCounted

var data: CardData
var is_consumed: bool = false  # 一次性卡用完即标记

func _init(card_data: CardData) -> void:
	data = card_data

## 计算当前有效 cost（考虑 debuff、词条、催化剂效果等）
func effective_cost(ctx: BattleContext) -> int:
	var base := data.cost
	# 易伤：cost +1（影响持有该状态的 chain.owner）
	# CardRuntime 属于某个 Combatant 的 chain，owner 通过 ctx 无法直接获得
	# 设计上由 chain.on_tick 传入 owner，这里暂不处理（阶段 2 补全）
	return max(1, base)

## 触发卡牌效果
func fire(ctx: BattleContext, source: Combatant) -> void:
	if is_consumed:
		return
	if data.effect:
		ctx.push_source_label_key(data.display_name_key)
		data.effect.fire(ctx, source)
		ctx.pop_source_label_key()
	if data.consumable:
		is_consumed = true
