class_name GemEffectDamageBonus extends GemEffect

@export var bonus: int = 2
@export var required_tag: StringName = &""

func modify_damage(card: CardRuntime, base: int) -> int:
	if required_tag != &"" and not card.data.tags.has(required_tag):
		return base
	return base + bonus
