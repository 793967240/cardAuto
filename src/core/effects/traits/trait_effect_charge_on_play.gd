# src/core/effects/traits/trait_effect_charge_on_play.gd
# 词条效果：卡牌打出时给 owner +X 充能
# 阶段 2 §2.1 / GDD §3.5 充能型
# 典型词条：蓄能井（charge_well）— 该槽位的卡打出时额外 +1 充能
class_name TraitEffectChargeOnPlay extends TraitEffect

@export var charge_amount: int = 1
@export var charge_cap: int = 99

func on_card_played(_card: CardRuntime, _ctx: BattleContext, source: Combatant) -> void:
	if source == null:
		return
	var existing := source.get_status(StatusInstance.ID_CHARGE)
	if existing:
		existing.stacks = min(existing.stacks + charge_amount, charge_cap)
	else:
		source.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, charge_amount))
