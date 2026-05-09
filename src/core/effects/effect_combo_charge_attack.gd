# src/core/effects/effect_combo_charge_attack.gd
# 充能攻击组合效果 - 同时造成伤害 + 获得充能
class_name EffectComboChargeAttack extends CardEffect

@export var damage: int = 5
@export var charge_amount: int = 1
@export var charge_cap: int = 99

func fire(ctx: BattleContext, source: Combatant) -> void:
	# 攻击
	var target := ctx.choose_target(source)
	if target and target.is_alive():
		var dealt := target.take_damage(damage, source.tags)
		ctx.stats.damage_dealt += dealt

	# 充能
	var existing := source.get_status(StatusInstance.ID_CHARGE)
	if existing:
		existing.stacks = min(existing.stacks + charge_amount, charge_cap)
	else:
		source.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, charge_amount))

	ctx.stats.cards_fired += 1
