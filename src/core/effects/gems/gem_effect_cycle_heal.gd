class_name GemEffectCycleHeal extends GemEffect

@export var heal_amount: int = 3

func on_cycle_completed(_ctx: BattleContext, owner: Combatant) -> void:
	owner.heal(heal_amount)
