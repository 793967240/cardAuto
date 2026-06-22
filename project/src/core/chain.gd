class_name Chain extends RefCounted

var slots: Array[CardRuntime] = []
var layout: Array = []
var current_index: int = 0
var current_card_progress: int = 0
var next_card_cost_reduction: int = 0
var next_card_half_cost: bool = false
var next_tag_cost_reductions: Array[Dictionary] = []
var next_tag_half_costs: Array[StringName] = []
var next_tag_damage_bonuses: Array[Dictionary] = []
var next_tag_status_stack_bonuses: Array[Dictionary] = []
var cycle_played_count: int = 0
var cycle_tag_counts: Dictionary = {}
var cycle_shield_gained: int = 0
var pending_cycle_damage: int = 0
var pending_cycle_heal: int = 0
var pending_cycle_haste: int = 0
var _haste_bonus_progress: int = 0

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
	_process_one_tick(ctx)
	if owner and owner.has_status(StatusInstance.ID_HASTE) and not slots.is_empty():
		_haste_bonus_progress += 1
		if _haste_bonus_progress >= 2:
			_haste_bonus_progress = 0
			_process_one_tick(ctx)

func _process_one_tick(ctx: BattleContext) -> void:
	if slots.is_empty():
		return

	var card := slots[current_index]

	if card.is_consumed:
		_advance_index(ctx)
		return

	current_card_progress += 1
	if current_card_progress >= _effective_cost(card, ctx):
		_consume_next_cost_modifiers_for_card(card)
		if owner and owner.relic_runtime != null:
			owner.relic_runtime.before_card_fired(ctx, owner, card, current_index)
		card.fire(ctx, owner)
		_record_card_played(card)
		_fire_gem_hook(current_index, &"on_card_played", [card, ctx, owner])
		card_fired.emit(card, current_index)
		if owner and owner.relic_runtime != null:
			owner.relic_runtime.after_card_fired(ctx, owner, card, current_index)
		current_card_progress = 0
		_advance_index(ctx)

func _advance_index(ctx: BattleContext) -> void:
	current_index += 1
	if current_index >= slots.size():
		_complete_cycle(ctx)

func _complete_cycle(ctx: BattleContext) -> void:
	_apply_cycle_end_effects(ctx)
	_fire_gem_hook_all(&"on_cycle_completed", [ctx, owner])
	cycle_completed.emit()
	if owner and owner.relic_runtime != null:
		owner.relic_runtime.on_cycle_completed(ctx, owner)
	_clear_cycle_modifiers()
	cycle_played_count = 0
	cycle_tag_counts.clear()
	cycle_shield_gained = 0
	pending_cycle_damage = 0
	pending_cycle_heal = 0
	pending_cycle_haste = 0
	if owner:
		owner.reset_cycle_stats()
	current_index = 0
	current_card_progress = 0

func reset_current_card_progress() -> void:
	current_card_progress = 0

func _effective_cost(card: CardRuntime, ctx: BattleContext) -> int:
	var base := card.effective_cost(ctx)
	for g in _active_gems_for_index(current_index):
		var eff := (g as GemInstance).get_effect()
		if eff != null and (g as GemInstance).data.trigger == GemData.Trigger.PASSIVE:
			if eff.has_method(&"modify_cost_with_chain"):
				base = eff.modify_cost_with_chain(card, base, self)
			else:
				base = eff.modify_cost(card, base)
	if owner and owner.has_status(StatusInstance.ID_VULNERABLE):
		base += 1
	base = _apply_passive_cost_modifiers(card, base)
	base = _apply_next_cost_modifiers(card, base)
	if owner and owner.relic_runtime != null:
		base = owner.relic_runtime.modify_cost(card, base, self, current_index)
	return max(1, base)

func modify_damage(card: CardRuntime, base: int, slot_index: int = -1) -> int:
	var idx := slot_index if slot_index >= 0 else current_index
	var out := base
	if owner and card != null and card.data != null and card.data.tags.has(&"attack"):
		var strength := owner.get_status(StatusInstance.ID_STRENGTH)
		if strength:
			out += strength.stacks
	for g in _active_gems_for_index(idx):
		var eff := (g as GemInstance).get_effect()
		if eff != null and (g as GemInstance).data.trigger == GemData.Trigger.PASSIVE:
			out = eff.modify_damage_with_chain(card, out, self)
	out = _apply_next_damage_bonuses(card, out)
	if owner and owner.relic_runtime != null:
		out = owner.relic_runtime.modify_damage(card, out, self, idx)
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
			_push_source_label(args, gi.data.get_name_key())
			eff.callv(method, args)
			_pop_source_label(args)

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
				_push_source_label(args, gi.data.get_name_key())
				eff.callv(method, args)
				_pop_source_label(args)

func modify_gem_number(base: int) -> int:
	if owner and owner.relic_runtime != null:
		return owner.relic_runtime.modify_gem_number(base)
	return base

func _push_source_label(args: Array, label_key: String) -> void:
	if args.is_empty() or not (args[0] is BattleContext):
		return
	var ctx: BattleContext = args[0]
	ctx.push_source_label_key(label_key)

func _pop_source_label(args: Array) -> void:
	if args.is_empty() or not (args[0] is BattleContext):
		return
	var ctx: BattleContext = args[0]
	ctx.pop_source_label_key()

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
	_clear_cycle_modifiers()

func set_layout(chain_slots: Array) -> void:
	layout = chain_slots
	slots.clear()
	for s in chain_slots:
		var cs: ChainSlot = s
		slots.append(cs.card)
	current_index = 0
	current_card_progress = 0
	_clear_cycle_modifiers()

func get_current_card() -> CardRuntime:
	if slots.is_empty() or current_index >= slots.size():
		return null
	return slots[current_index]

func add_next_card_cost_reduction(amount: int) -> void:
	next_card_cost_reduction += amount

func add_next_card_half_cost() -> void:
	next_card_half_cost = true

func add_next_tag_cost_reduction(tag: StringName, amount: int) -> void:
	next_tag_cost_reductions.append({"tag": tag, "amount": amount})

func add_next_tag_half_cost(tag: StringName) -> void:
	next_tag_half_costs.append(tag)

func add_next_tag_damage_bonus(tag: StringName, amount: int, required_target_status: StringName = &"") -> void:
	next_tag_damage_bonuses.append({"tag": tag, "amount": amount, "required_target_status": required_target_status})

func add_next_tag_status_stack_bonus(tag: StringName, status_id: StringName, amount: int) -> void:
	next_tag_status_stack_bonuses.append({"tag": tag, "status_id": status_id, "amount": amount})

func consume_status_stack_bonus(card: CardRuntime, status_id: StringName) -> int:
	var bonus := 0
	for i in range(next_tag_status_stack_bonuses.size() - 1, -1, -1):
		var item := next_tag_status_stack_bonuses[i]
		if card.data.tags.has(item.get("tag", &"")) and item.get("status_id", &"") == status_id:
			bonus += int(item.get("amount", 0))
			next_tag_status_stack_bonuses.remove_at(i)
	return bonus

func add_cycle_damage(amount: int) -> void:
	pending_cycle_damage += amount

func add_cycle_heal(amount: int) -> void:
	pending_cycle_heal += amount

func add_cycle_haste(duration_ticks: int) -> void:
	pending_cycle_haste += duration_ticks

func add_cycle_shield(amount: int) -> void:
	cycle_shield_gained += amount

func _apply_passive_cost_modifiers(card: CardRuntime, base: int) -> int:
	var out := base
	if layout.is_empty() or current_index < 0 or current_index >= layout.size():
		return out
	for i in range(layout.size()):
		var slot: ChainSlot = layout[i]
		if slot == null or slot.card == null or slot.card.data == null:
			continue
		if slot.card.data.passive_adjacent_cost_reduction <= 0:
			continue
		var distance: int = abs(i - current_index)
		if distance != 1:
			continue
		var tag := slot.card.data.passive_adjacent_required_tag
		if tag != &"" and not card.data.tags.has(tag):
			continue
		out -= slot.card.data.passive_adjacent_cost_reduction
	return out

func _apply_next_cost_modifiers(card: CardRuntime, base: int) -> int:
	var out := base
	if next_card_half_cost:
		out = maxi(1, int(ceil(float(out) / 2.0)))
	if next_card_cost_reduction > 0:
		out -= next_card_cost_reduction
	for i in range(next_tag_half_costs.size() - 1, -1, -1):
		var tag := next_tag_half_costs[i]
		if card.data.tags.has(tag):
			out = maxi(1, int(ceil(float(out) / 2.0)))
			break
	for i in range(next_tag_cost_reductions.size() - 1, -1, -1):
		var item := next_tag_cost_reductions[i]
		if card.data.tags.has(item.get("tag", &"")):
			out -= int(item.get("amount", 0))
			break
	return out

func _consume_next_cost_modifiers_for_card(card: CardRuntime) -> void:
	if next_card_half_cost:
		next_card_half_cost = false
	if next_card_cost_reduction > 0:
		next_card_cost_reduction = 0
	for i in range(next_tag_half_costs.size() - 1, -1, -1):
		var tag := next_tag_half_costs[i]
		if card.data.tags.has(tag):
			next_tag_half_costs.remove_at(i)
			break
	for i in range(next_tag_cost_reductions.size() - 1, -1, -1):
		var item := next_tag_cost_reductions[i]
		if card.data.tags.has(item.get("tag", &"")):
			next_tag_cost_reductions.remove_at(i)
			break

func _apply_next_damage_bonuses(card: CardRuntime, base: int) -> int:
	var out := base
	var target: Combatant = null
	if owner:
		target = null
	for i in range(next_tag_damage_bonuses.size() - 1, -1, -1):
		var item := next_tag_damage_bonuses[i]
		if not card.data.tags.has(item.get("tag", &"")):
			continue
		var required := StringName(item.get("required_target_status", &""))
		if required != &"":
			# 目标状态检查由具体效果脚本处理更准确；这里仅支持无条件流转增伤。
			continue
		out += int(item.get("amount", 0))
		next_tag_damage_bonuses.remove_at(i)
	return out

func _record_card_played(card: CardRuntime) -> void:
	cycle_played_count += 1
	if owner:
		owner.cycle_stats["played_count"] = cycle_played_count
	for tag in card.data.tags:
		cycle_tag_counts[tag] = int(cycle_tag_counts.get(tag, 0)) + 1
		if owner:
			owner.cycle_stats["tag_%s" % str(tag)] = cycle_tag_counts[tag]

func _apply_cycle_end_effects(ctx: BattleContext) -> void:
	if owner == null:
		return
	var target: Combatant = ctx.choose_target(owner)
	if pending_cycle_damage > 0 and target and target.is_alive():
		var dealt := target.take_damage(pending_cycle_damage, owner.tags)
		ctx.record_damage(owner, target, dealt)
	if pending_cycle_heal > 0:
		var healed := owner.heal(pending_cycle_heal)
		ctx.record_heal(owner, owner, healed)
	if pending_cycle_haste > 0:
		owner.apply_status(StatusInstance.new(StatusInstance.ID_HASTE, 1, pending_cycle_haste))

func _clear_cycle_modifiers() -> void:
	next_card_cost_reduction = 0
	next_card_half_cost = false
	next_tag_cost_reductions.clear()
	next_tag_half_costs.clear()
	next_tag_damage_bonuses.clear()
	next_tag_status_stack_bonuses.clear()
	_haste_bonus_progress = 0
