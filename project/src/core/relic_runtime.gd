class_name RelicRuntime extends RefCounted

var relics: Array[RelicData] = []
var battle_first_card_pending := true
var attack_cards_played := 0
var total_cards_played := 0
var cycles_completed := 0
var cycle_first_high_cost_used := false
var cycle_first_attack_used := false
var cycle_third_card_echo_used := false
var first_recovery_entered := false
var recovery_damage_block_used := false
var elixir_used := false
var furnace_used := false
var charge_gained_since_bonus := 0
var current_cycle_cost_reduction_index := -1
var mind_lamp_used := false

func _init(source_relics: Array = []) -> void:
	for relic in source_relics:
		if relic is RelicData:
			relics.append(relic as RelicData)

func has_relic(id: StringName) -> bool:
	for relic in relics:
		if relic != null and relic.id == id:
			return true
	return false

func on_battle_start(ctx: BattleContext, owner) -> void:
	battle_first_card_pending = true
	attack_cards_played = 0
	total_cards_played = 0
	cycles_completed = 0
	first_recovery_entered = false
	recovery_damage_block_used = false
	elixir_used = false
	furnace_used = false
	charge_gained_since_bonus = 0
	mind_lamp_used = false
	if has_relic(&"cracked_jade_charm"):
		owner.apply_status(StatusInstance.make_shield(6))
	if has_relic(&"bronze_bell"):
		owner.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, 1, -1))
	if has_relic(&"wooden_sword_case"):
		var attacks := _count_cards_with_tag(owner.chain, &"attack", false)
		if attacks >= 3:
			owner.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, attacks / 3, -1))
	on_cycle_start(ctx, owner)
	if has_relic(&"mind_cutting_lamp"):
		_trigger_first_non_rare_card(ctx, owner)

func on_cycle_start(_ctx: BattleContext, owner) -> void:
	cycle_first_high_cost_used = false
	cycle_first_attack_used = false
	cycle_third_card_echo_used = false
	current_cycle_cost_reduction_index = -1
	if has_relic(&"myriad_array_plate") and owner != null and owner.chain != null:
		var candidates: Array[int] = []
		for i in range(owner.chain.layout.size()):
			var slot: ChainSlot = owner.chain.layout[i]
			if slot != null and slot.card != null and slot.card.data != null and slot.card.data.id != &"default_strike":
				candidates.append(i)
		if not candidates.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = Time.get_ticks_usec()
			current_cycle_cost_reduction_index = candidates[rng.randi_range(0, candidates.size() - 1)]

func modify_cost(card: CardRuntime, base: int, chain, index: int) -> int:
	var out := base
	if card == null or card.data == null:
		return out
	if has_relic(&"loose_page") and battle_first_card_pending:
		out -= 1
	if has_relic(&"wind_return_jade") and not cycle_first_high_cost_used and base >= 2:
		out -= 1
	if has_relic(&"myriad_array_plate") and index == current_cycle_cost_reduction_index:
		out -= 1
	if has_relic(&"short_incense") and card.data.id == &"default_strike":
		out -= 1
	return maxi(1, out)

func modify_damage(card: CardRuntime, base: int, chain, index: int) -> int:
	if card == null or card.data == null:
		return base
	var out := base
	var is_attack := card.data.tags.has(&"attack")
	if has_relic(&"sword_tassel") and is_attack:
		out += 1
	if has_relic(&"black_iron_scabbard") and is_attack and _count_cards_with_tag(chain, &"attack", false) >= 4:
		out += 2
	if has_relic(&"needle_compass") and _chain_total_cost(chain, false) <= 8:
		out += 2
	if has_relic(&"star_sand_inkstone") and _slot_has_gem(chain, index):
		out += 2
	if has_relic(&"empty_seat_lantern") and is_attack and not cycle_first_attack_used:
		out += _empty_base_count(chain) * 2
	if has_relic(&"yin_yang_fish_talisman") and is_attack and _previous_card_type(chain, index) == CardData.CardType.DEFENSE:
		out = int(floor(float(out) * 1.5))
	return out

func modify_gem_number(base: int) -> int:
	if has_relic(&"exquisite_pagoda"):
		return int(floor(float(base) * 1.5))
	return base

func before_card_fired(ctx: BattleContext, owner, card: CardRuntime, index: int) -> void:
	if card == null or card.data == null:
		return
	if card.data.id == &"default_strike":
		on_recovery_entered(owner)
	if has_relic(&"heavenly_river_case") and card.data.tags.has(&"attack") and not cycle_first_attack_used:
		_trigger_card_effect(ctx, owner, card)
	if has_relic(&"jade_chain_ring") and owner.chain != null and owner.chain.cycle_played_count == 2 and not cycle_third_card_echo_used:
		cycle_third_card_echo_used = true
		_trigger_card_effect(ctx, owner, card)

func after_card_fired(ctx: BattleContext, owner, card: CardRuntime, _index: int) -> void:
	if card == null or card.data == null:
		return
	battle_first_card_pending = false
	total_cards_played += 1
	if card.data.tags.has(&"attack"):
		attack_cards_played += 1
		cycle_first_attack_used = true
		if has_relic(&"whetstone") and attack_cards_played % 4 == 0 and owner.chain != null:
			owner.chain.add_next_tag_damage_bonus(&"attack", 3)
	if has_relic(&"thunder_trial_wood") and total_cards_played % 5 == 0:
		var target := ctx.choose_target(owner)
		if target != null and target.is_alive():
			ctx.push_source_label_key("relic.thunder_trial_wood.name")
			var dealt := target.take_damage(10, owner.tags)
			ctx.record_damage(owner, target, dealt)
			ctx.pop_source_label_key()
	if card.data.cost >= 2:
		cycle_first_high_cost_used = true

func on_cycle_completed(ctx: BattleContext, owner) -> void:
	cycles_completed += 1
	if has_relic(&"cloth_bracer"):
		ctx.push_source_label_key("relic.cloth_bracer.name")
		var healed: int = owner.heal(2)
		ctx.record_heal(owner, owner, healed)
		ctx.pop_source_label_key()
	if has_relic(&"heart_guard_mirror") and owner.chain != null and owner.chain.cycle_shield_gained > 0:
		var shield: StatusInstance = owner.get_status(StatusInstance.ID_SHIELD)
		if shield != null and shield.stacks > 0:
			shield.stacks = int(ceil(float(shield.stacks) * 0.3))
	if has_relic(&"taixu_sword_seal") and cycles_completed % 2 == 0 and owner.chain != null:
		owner.chain.add_next_tag_damage_bonus(&"attack", 12)
	on_cycle_start(ctx, owner)

func on_recovery_entered(owner) -> void:
	if has_relic(&"warding_umbrella") and not first_recovery_entered:
		first_recovery_entered = true
		owner.apply_status(StatusInstance.make_shield(12))

func modify_incoming_damage(owner, amount: int) -> int:
	var out := amount
	var in_recovery: bool = owner.chain != null and owner.chain.get_current_card() != null and owner.chain.get_current_card().data.id == &"default_strike"
	if in_recovery and has_relic(&"flawless_golden_body") and not recovery_damage_block_used:
		recovery_damage_block_used = true
		return 0
	if in_recovery and has_relic(&"old_banner"):
		out -= 2
	return maxi(0, out)

func after_hp_changed(owner, old_hp: int, _new_hp: int) -> void:
	if has_relic(&"small_elixir") and not elixir_used and owner.hp > 0 and old_hp >= int(ceil(owner.max_hp * 0.5)) and owner.hp < int(ceil(owner.max_hp * 0.5)):
		elixir_used = true
		owner.heal(8)

func prevent_death(owner) -> bool:
	if not has_relic(&"nine_turn_furnace") or furnace_used:
		return false
	furnace_used = true
	owner.hp = 1
	owner.heal(20)
	return true

func modify_outgoing_status(status: StatusInstance) -> void:
	if status.status_id == StatusInstance.ID_BURN and has_relic(&"ember_talisman"):
		status.stacks += 1

func modify_charge_gain(amount: int) -> int:
	if not has_relic(&"qi_gourd") or amount <= 0:
		return amount
	charge_gained_since_bonus += amount
	var extra := charge_gained_since_bonus / 3
	if extra > 0:
		charge_gained_since_bonus %= 3
	return amount + extra

func _trigger_first_non_rare_card(ctx: BattleContext, owner) -> void:
	if owner == null or owner.chain == null or mind_lamp_used:
		return
	for card in owner.chain.slots:
		if card != null and card.data != null and card.data.rarity != CardData.Rarity.RARE and card.data.effect != null:
			mind_lamp_used = true
			ctx.push_source_label_key("relic.mind_cutting_lamp.name")
			card.data.effect.fire(ctx, owner)
			ctx.pop_source_label_key()
			return

func _trigger_card_effect(ctx: BattleContext, owner, card: CardRuntime) -> void:
	if card == null or card.data == null or card.data.effect == null:
		return
	ctx.push_source_label_key(card.data.display_name_key)
	card.data.effect.fire(ctx, owner)
	ctx.pop_source_label_key()

func _count_cards_with_tag(chain, tag: StringName, include_default: bool) -> int:
	if chain == null:
		return 0
	var count := 0
	for card in chain.slots:
		if card != null and card.data != null and card.data.tags.has(tag):
			if include_default or card.data.id != &"default_strike":
				count += 1
	return count

func _chain_total_cost(chain, include_default: bool) -> int:
	if chain == null:
		return 0
	var total := 0
	for card in chain.slots:
		if card != null and card.data != null:
			if include_default or card.data.id != &"default_strike":
				total += card.data.cost
	return total

func _slot_has_gem(chain, index: int) -> bool:
	if chain == null or index < 0 or index >= chain.layout.size():
		return false
	var slot: ChainSlot = chain.layout[index]
	return slot != null and not slot.gems.is_empty()

func _empty_base_count(chain) -> int:
	if chain == null:
		return 0
	var count := 0
	for card in chain.slots:
		if card != null and card.data != null and card.data.id == &"default_strike":
			count += 1
	return count

func _previous_card_type(chain, index: int) -> int:
	if chain == null or index <= 0 or index > chain.slots.size() - 1:
		return -1
	var prev: CardRuntime = chain.slots[index - 1]
	return prev.data.card_type if prev != null and prev.data != null else -1
