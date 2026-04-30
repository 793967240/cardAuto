# src/core/effects/card_effect.gd
# 卡牌效果基类（策略模式）
class_name CardEffect extends RefCounted

## 触发效果
## @param ctx - 战斗上下文
## @param source - 触发者（玩家/敌人）
func fire(ctx: BattleContext, source: Combatant) -> void:
	push_error("CardEffect.fire() must be overridden by subclass")
