# src/core/effects/effect_charge.gd
# 充能效果 - 为施加者增加充能层数
class_name EffectCharge extends CardEffect

@export var charge_amount: int = 1
@export var charge_cap: int = 99  # 充能上限

func fire(ctx: BattleContext, source: Combatant) -> void:
	var existing := source.get_status(StatusInstance.ID_CHARGE)
	if existing:
		existing.stacks = min(existing.stacks + charge_amount, charge_cap)
	else:
		var charge := StatusInstance.new(StatusInstance.ID_CHARGE, charge_amount)
		source.apply_status(charge)
	ctx.stats.cards_fired += 1
