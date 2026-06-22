class_name GemEffectCycleHeal extends GemEffect

@export var heal_amount: int = 3

func on_cycle_completed(ctx: BattleContext, owner: Combatant) -> void:
	var amount: int = owner.chain.modify_gem_number(heal_amount) if owner.chain else heal_amount
	var healed := owner.heal(amount)
	ctx.record_heal(owner, owner, healed)
