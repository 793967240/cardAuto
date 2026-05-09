# src/core/effects/effect_buildup.gd
# 蓄力效果 - 积累充能层数（不造成直接伤害）
class_name EffectBuildup extends CardEffect

@export var charge_amount: int = 2
@export var charge_cap: int = 99

func fire(ctx: BattleContext, source: Combatant) -> void:
	var existing := source.get_status(StatusInstance.ID_CHARGE)
	if existing:
		existing.stacks = min(existing.stacks + charge_amount, charge_cap)
	else:
		var charge := StatusInstance.new(StatusInstance.ID_CHARGE, charge_amount)
		source.apply_status(charge)
	ctx.stats.cards_fired += 1
