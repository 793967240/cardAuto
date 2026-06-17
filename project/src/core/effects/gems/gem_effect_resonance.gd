class_name GemEffectResonance extends GemEffect

@export var bonus_per_match: int = 1
@export var required_tag: StringName = &""

func modify_damage_with_chain(card: CardRuntime, base: int, chain) -> int:
	if required_tag == &"" or not card.data.tags.has(required_tag):
		return base
	var count: int = 0
	for slot in chain.slots:
		if slot.data.tags.has(required_tag):
			count += 1
	return base + bonus_per_match * count
