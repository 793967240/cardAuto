class_name GemEffectDamageBonus extends GemEffect

@export var bonus: int = 2
@export var required_tag: StringName = &""

func modify_damage(card: CardRuntime, base: int) -> int:
	if required_tag != &"" and not card.data.tags.has(required_tag):
		return base
	return base + bonus

func modify_damage_with_chain(card: CardRuntime, base: int, chain) -> int:
	if required_tag != &"" and not card.data.tags.has(required_tag):
		return base
	return base + chain.modify_gem_number(bonus)
