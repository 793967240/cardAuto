class_name GemEffectChargeOnPlay extends GemEffect

@export var charge_amount: int = 1

func on_card_played(_card: CardRuntime, _ctx: BattleContext, source: Combatant) -> void:
	var charge_status := StatusInstance.new(StatusInstance.ID_CHARGE, charge_amount, -1)
	source.apply_status(charge_status)
