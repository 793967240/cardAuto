class_name Chain extends RefCounted

var slots: Array[CardRuntime] = []
var layout: Array = []
var current_index: int = 0
var current_card_progress: int = 0

var owner: Combatant

signal card_fired(card: CardRuntime, index: int)
signal cycle_completed()
signal chain_empty()

func _init(combatant: Combatant) -> void:
	owner = combatant

func on_tick(ctx: BattleContext) -> void:
	if slots.is_empty():
		chain_empty.emit()
		return

	var card := slots[current_index]

	if card.is_consumed:
		_advance_index(ctx)
		return

	current_card_progress += 1
	if current_card_progress >= _effective_cost(card, ctx):
		card.fire(ctx, owner)
		_fire_gem_hook(current_index, &"on_card_played", [card, ctx, owner])
		card_fired.emit(card, current_index)
		current_card_progress = 0
		_advance_index(ctx)

func _advance_index(ctx: BattleContext) -> void:
	current_index += 1
	if current_index >= slots.size():
		_complete_cycle(ctx)

func _complete_cycle(ctx: BattleContext) -> void:
	_fire_gem_hook_all(&"on_cycle_completed", [ctx, owner])
	cycle_completed.emit()
	current_index = 0
	current_card_progress = 0

func reset_current_card_progress() -> void:
	current_card_progress = 0

func _effective_cost(card: CardRuntime, ctx: BattleContext) -> int:
	var base := card.effective_cost(ctx)
	for g in _active_gems_for_index(current_index):
		var eff := (g as GemInstance).get_effect()
		if eff != null and (g as GemInstance).data.trigger == GemData.Trigger.PASSIVE:
			base = eff.modify_cost(card, base)
	if owner and owner.has_status(StatusInstance.ID_VULNERABLE):
		base += 1
	return max(1, base)

func modify_damage(card: CardRuntime, base: int, slot_index: int = -1) -> int:
	var idx := slot_index if slot_index >= 0 else current_index
	var out := base
	for g in _active_gems_for_index(idx):
		var eff := (g as GemInstance).get_effect()
		if eff != null and (g as GemInstance).data.trigger == GemData.Trigger.PASSIVE:
			out = eff.modify_damage_with_chain(card, out, self)
	return out

func _fire_gem_hook(idx: int, method: StringName, args: Array) -> void:
	for g in _active_gems_for_index(idx):
		var gi: GemInstance = g
		if gi.data.trigger == GemData.Trigger.PASSIVE:
			continue
		var eff := gi.get_effect()
		if eff == null:
			continue
		if eff.has_method(method):
			eff.callv(method, args)

func _fire_gem_hook_all(method: StringName, args: Array) -> void:
	for cs in layout:
		var slot: ChainSlot = cs
		if slot == null:
			continue
		for g in slot.gems:
			var gi: GemInstance = g
			if gi.data.trigger == GemData.Trigger.PASSIVE:
				continue
			var eff := gi.get_effect()
			if eff != null and eff.has_method(method):
				eff.callv(method, args)

func _active_gems_for_index(idx: int) -> Array:
	if idx < 0 or idx >= layout.size():
		return []
	var slot: ChainSlot = layout[idx]
	if slot == null:
		return []
	return slot.active_gems()

func set_slots(cards: Array[CardRuntime]) -> void:
	slots = cards
	layout.clear()
	for c in cards:
		layout.append(ChainSlot.new(c))
	current_index = 0
	current_card_progress = 0

func set_layout(chain_slots: Array) -> void:
	layout = chain_slots
	slots.clear()
	for s in chain_slots:
		var cs: ChainSlot = s
		slots.append(cs.card)
	current_index = 0
	current_card_progress = 0

func get_current_card() -> CardRuntime:
	if slots.is_empty() or current_index >= slots.size():
		return null
	return slots[current_index]
