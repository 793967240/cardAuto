class_name GemEffect extends Resource

func modify_cost(card: CardRuntime, base: int) -> int:
	return base

func modify_damage(card: CardRuntime, base: int) -> int:
	return base

func modify_damage_with_chain(card: CardRuntime, base: int, _chain) -> int:
	return modify_damage(card, base)

func on_card_played(card: CardRuntime, ctx: BattleContext, source: Combatant) -> void:
	pass

func on_cycle_completed(ctx: BattleContext, owner: Combatant) -> void:
	pass
