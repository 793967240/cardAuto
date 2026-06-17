class_name GemEffectCostReduction extends GemEffect

@export var reduction: int = 1
@export var required_tag: StringName = &""

func modify_cost(card: CardRuntime, base: int) -> int:
	if required_tag != &"" and not card.data.tags.has(required_tag):
		return base
	return max(1, base - reduction)
