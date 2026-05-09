# src/core/effects/effect_power_strike.gd
# 强力一击效果 - 消耗充能造成倍增伤害
class_name EffectPowerStrike extends CardEffect

@export var base_damage: int = 10
@export var charge_multiplier: float = 2.0  # 每层充能的额外伤害系数
@export var consume_all_charge: bool = true  # 是否消耗全部充能

func fire(ctx: BattleContext, source: Combatant) -> void:
	var target := ctx.choose_target(source)
	if not target or not target.is_alive():
		return

	var charge_stacks := 0
	var charge_status := source.get_status(StatusInstance.ID_CHARGE)
	if charge_status:
		charge_stacks = charge_status.stacks
		if consume_all_charge:
			source.remove_status(StatusInstance.ID_CHARGE)

	var total_damage := base_damage + int(charge_stacks * charge_multiplier)
	# 词条修饰：PASSIVE 词条对最终伤害的修饰
	if source.chain:
		total_damage = source.chain.modify_damage(source.chain.get_current_card(), total_damage)
	var dealt := target.take_damage(total_damage, source.tags)
	ctx.stats.damage_dealt += dealt
	ctx.stats.cards_fired += 1
