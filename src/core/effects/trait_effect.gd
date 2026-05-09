# src/core/effects/trait_effect.gd
# 词条效果基类（策略模式，继承 Resource 以支持 .tres 序列化）
# 阶段 2 §2.1
#
# 一个 TraitData 持有一个 TraitEffect。具体子类按 Trigger 类别实现：
#   PASSIVE      → modify_cost / modify_damage hook
#   ON_PLAY      → on_card_played(card, ctx, source)
#   ON_RECOVERY  → on_recovery_started(ctx, owner)
#   ON_CHAIN_END → on_chain_ended(ctx, owner)
#
# 子类按需 override 对应 hook，未 override 的默认空实现。
class_name TraitEffect extends Resource

## ===== Passive 修饰 hook（由 Chain 计算 effective_cost / effective_damage 时聚合调用） =====

## 修饰卡牌 cost（base_cost → 返回新 cost）
## @param card  - 被修饰的卡
## @param base  - 当前 cost（已含其它词条的累积修饰）
## @return 修饰后的 cost
func modify_cost(card: CardRuntime, base: int) -> int:
	return base

## 修饰卡牌伤害（base_damage → 返回新 damage）
## 简单词条 override 这个即可
func modify_damage(card: CardRuntime, base: int) -> int:
	return base

## 修饰卡牌伤害（带 chain 上下文版本，给共鸣型/扫链型词条用）
## Chain.modify_damage 优先调用本方法；默认实现 fallback 到 modify_damage(card, base)
## 子类按需 override
func modify_damage_with_chain(card: CardRuntime, base: int, _chain) -> int:
	return modify_damage(card, base)

## ===== 事件 hook =====

## 卡牌打出时触发
func on_card_played(card: CardRuntime, ctx: BattleContext, source: Combatant) -> void:
	pass

## 进入修整时触发
func on_recovery_started(ctx: BattleContext, owner: Combatant) -> void:
	pass

## 整轮链条结束（即修整结束、重启链条）时触发
func on_chain_ended(ctx: BattleContext, owner: Combatant) -> void:
	pass
