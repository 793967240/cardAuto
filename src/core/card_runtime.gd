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
	# TODO: 阶段 2 加入词条和状态修正
	return max(0, base)

## 触发卡牌效果
func fire(ctx: BattleContext, source: Combatant) -> void:
	if is_consumed:
		return
	if data.effect_script:
		var effect: CardEffect = data.effect_script.new()
		effect.fire(ctx, source)
	if data.consumable:
		is_consumed = true
