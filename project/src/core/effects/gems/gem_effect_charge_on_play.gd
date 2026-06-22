class_name GemEffectChargeOnPlay extends GemEffect

@export var charge_amount: int = 1

func on_card_played(_card: CardRuntime, _ctx: BattleContext, source: Combatant) -> void:
	var amount: int = source.chain.modify_gem_number(charge_amount) if source.chain else charge_amount
	var charge_status := StatusInstance.new(StatusInstance.ID_CHARGE, amount, -1)
	source.apply_status(charge_status)
