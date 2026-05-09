# src/core/effects/effect_defense.gd
# 防御效果 - 为施加者增加护盾（减少下次受到的伤害）
# 护盾通过 StatusInstance.ID_SHIELD 实现，take_damage 时优先抵消
class_name EffectDefense extends CardEffect

@export var shield_amount: int = 6

func fire(ctx: BattleContext, source: Combatant) -> void:
	var existing := source.get_status(StatusInstance.ID_SHIELD)
	if existing:
		existing.stacks += shield_amount
	else:
		var shield := StatusInstance.new(StatusInstance.ID_SHIELD, shield_amount)
		source.apply_status(shield)
	ctx.stats.cards_fired += 1
