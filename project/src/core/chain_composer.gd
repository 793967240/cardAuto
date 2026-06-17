class_name ChainComposer extends RefCounted

class Spec extends RefCounted:
	var bases: Array = []  # Array[SlotData] — 固定 8 个底座
	var base_cards: Dictionary = {}  # base_id → CardData（每底座 1 张卡，可 null）
	var base_gems: Dictionary = {}   # base_id → Array[GemInstance]

class Result extends RefCounted:
	var layout: Array = []  # Array[ChainSlot]
	var total_cost: int = 0
	var errors: Array = []  # Array[StringName]

const DEFAULT_STRIKE_DAMAGE := 2
const DEFAULT_STRIKE_COST := 1

static var _default_strike_card: CardData = null

static func compose(spec: Spec) -> Result:
	var result := Result.new()

	if spec.bases.is_empty():
		result.errors.append(&"no_bases")
		return result

	for sd_var in spec.bases:
		var sd: SlotData = sd_var
		var card_data: CardData = spec.base_cards.get(sd.id, null)
		if card_data == null:
			card_data = get_default_strike_card()
		var rt := CardRuntime.new(card_data)
		var cs := ChainSlot.new(rt, sd.id)
		result.total_cost += card_data.cost

		var gem_instances: Array = spec.base_gems.get(sd.id, [])
		for gem_var in gem_instances:
			if gem_var is GemInstance:
				cs.gems.append(gem_var as GemInstance)
			elif gem_var is GemData:
				cs.gems.append(GemInstance.new(gem_var as GemData))

		result.layout.append(cs)

	return result

static func get_default_strike_card() -> CardData:
	if _default_strike_card != null:
		return _default_strike_card
	var card := CardData.new()
	card.id = &"default_strike"
	card.display_name_key = "card.default_strike.name"
	card.desc_key = "card.default_strike.desc"
	card.cost = DEFAULT_STRIKE_COST
	card.card_type = CardData.CardType.ATTACK
	card.tags = [&"sword", &"attack", &"default"]
	card.rarity = CardData.Rarity.COMMON
	card.description_template = "造成 2 点伤害。"
	var fx := EffectAttack.new()
	fx.damage = DEFAULT_STRIKE_DAMAGE
	fx.hits = 1
	card.effect = fx
	_default_strike_card = card
	return _default_strike_card
