class_name GemEffectCycleHeal extends GemEffect

@export var heal_amount: int = 3

func on_cycle_completed(ctx: BattleContext, owner: Combatant) -> void:
	var healed := owner.heal(heal_amount)
	ctx.record_heal(owner, owner, healed)
