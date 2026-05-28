class_name ChainComposer extends RefCounted

class Spec extends RefCounted:
	var bases: Array = []  # Array[SlotData] — 固定 8 个底座
	var base_cards: Dictionary = {}  # base_id → CardData（每底座 1 张卡，可 null）
	var base_gems: Dictionary = {}   # base_id → Array[GemData]

class Result extends RefCounted:
	var layout: Array = []  # Array[ChainSlot]
	var total_cost: int = 0
	var errors: Array = []  # Array[StringName]

static func compose(spec: Spec) -> Result:
	var result := Result.new()

	if spec.bases.is_empty():
		result.errors.append(&"no_bases")
		return result

	for sd_var in spec.bases:
		var sd: SlotData = sd_var
		var card_data: CardData = spec.base_cards.get(sd.id, null)
		if card_data == null:
			continue
		var rt := CardRuntime.new(card_data)
		var cs := ChainSlot.new(rt, sd.id)
		result.total_cost += card_data.cost

		var gem_datas: Array = spec.base_gems.get(sd.id, [])
		for gd_var in gem_datas:
			var gd: GemData = gd_var
			if gd != null:
				cs.gems.append(GemInstance.new(gd))

		result.layout.append(cs)

	if result.layout.is_empty():
		result.errors.append(&"no_cards_in_bases")

	return result
