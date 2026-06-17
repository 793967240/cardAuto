class_name EffectTimechain extends CardEffect

@export var damage: int = 0
@export var hits: int = 1
@export var bonus_damage: int = 0
@export var bonus_if_prev_tag: StringName = &""
@export var bonus_if_self_status: StringName = &""
@export var bonus_if_target_status: StringName = &""
@export var bonus_per_target_status_stack: StringName = &""
@export var bonus_per_stack: int = 0
@export var bonus_per_debuff_kind: int = 0

@export var shield: int = 0
@export var shield_damage_ratio: float = 0.0
@export var shield_before_damage: bool = false
@export var shield_bonus_if_had_shield: bool = false
@export var shield_bonus_damage_ratio: float = 1.0

@export var charge: int = 0
@export var bonus_charge_if_prev_tag: StringName = &""
@export var charge_consume: bool = false
@export var charge_base_damage: int = 0
@export var charge_multiplier: float = 0.0
@export var charge_refund_threshold: int = 0
@export var charge_refund: int = 0
@export var preserve_charge: int = 0

@export var burn_stacks: int = 0
@export var burn_duration: int = 0
@export var burn_extend: int = 0
@export var burn_detonate_ratio: float = 0.0
@export var status_stack_bonus_tag: StringName = &"fire"

@export var vulnerable_duration: int = 0
@export var weakness_duration: int = 0

@export var interrupt: bool = false
@export var interrupt_damage: int = 0
@export var interrupt_immune_duration: int = 4
@export var pierce_interrupt_resistance: bool = false
@export var haste_on_interrupt_success: int = 0

@export var haste_duration: int = 0
@export var next_card_cost_reduction: int = 0
@export var next_card_half_cost: bool = false
@export var next_tag_cost_reduction_tag: StringName = &""
@export var next_tag_cost_reduction: int = 0
@export var next_tag_half_cost: StringName = &""
@export var next_tag_damage_bonus_tag: StringName = &""
@export var next_tag_damage_bonus: int = 0
@export var next_tag_status_bonus_tag: StringName = &""
@export var next_tag_status_bonus_status: StringName = &""
@export var next_tag_status_bonus: int = 0

@export var cycle_damage: int = 0
@export var cycle_damage_per_tag: StringName = &""
@export var cycle_damage_per_tag_amount: int = 0
@export var cycle_heal: int = 0
@export var cycle_haste: int = 0
@export var cycle_threshold_played: int = 0
@export var cycle_threshold_heal: int = 0
@export var cycle_threshold_haste: int = 0

@export var echo_previous: int = 0
@export var echo_exclude_tag: StringName = &"echo"
@export var echo_haste_on_success: int = 0

func fire(ctx: BattleContext, source: Combatant) -> void:
	if source == null:
		return
	var target: Combatant = ctx.choose_target(source)
	var had_shield: bool = source.has_status(StatusInstance.ID_SHIELD)

	_apply_timing_modifiers(source)
	_apply_statuses(ctx, source, target)
	_apply_interrupt(ctx, source, target)
	_apply_shield(ctx, source, had_shield)
	_apply_charge_before_damage(source)
	_apply_damage(ctx, source, target, had_shield)
	_apply_echo(ctx, source)
	_apply_cycle_rewards(source)

	ctx.stats.cards_fired += 1

func _apply_timing_modifiers(source: Combatant) -> void:
	if haste_duration > 0:
		source.apply_status(StatusInstance.new(StatusInstance.ID_HASTE, 1, haste_duration))
	if source.chain == null:
		return
	if next_card_cost_reduction > 0:
		source.chain.add_next_card_cost_reduction(next_card_cost_reduction)
	if next_card_half_cost:
		source.chain.add_next_card_half_cost()
	if next_tag_cost_reduction_tag != &"" and next_tag_cost_reduction > 0:
		source.chain.add_next_tag_cost_reduction(next_tag_cost_reduction_tag, next_tag_cost_reduction)
	if next_tag_half_cost != &"":
		source.chain.add_next_tag_half_cost(next_tag_half_cost)
	if next_tag_damage_bonus_tag != &"" and next_tag_damage_bonus > 0:
		source.chain.add_next_tag_damage_bonus(next_tag_damage_bonus_tag, next_tag_damage_bonus)
	if next_tag_status_bonus_tag != &"" and next_tag_status_bonus_status != &"" and next_tag_status_bonus > 0:
		source.chain.add_next_tag_status_stack_bonus(next_tag_status_bonus_tag, next_tag_status_bonus_status, next_tag_status_bonus)

func _apply_statuses(_ctx: BattleContext, source: Combatant, target: Combatant) -> void:
	if target == null or not target.is_alive():
		return
	if burn_stacks > 0 and burn_duration > 0:
		var extra := 0
		if source.chain:
			extra = source.chain.consume_status_stack_bonus(source.chain.get_current_card(), StatusInstance.ID_BURN)
		var burn := StatusInstance.make_burn(burn_stacks + extra, burn_duration)
		burn.source_owner = source
		target.apply_status(burn)
	if burn_extend > 0:
		var existing := target.get_status(StatusInstance.ID_BURN)
		if existing and existing.remaining_ticks > 0:
			existing.remaining_ticks += burn_extend
	if vulnerable_duration > 0:
		target.apply_status(StatusInstance.make_vulnerable(vulnerable_duration))
	if weakness_duration > 0:
		target.apply_status(StatusInstance.make_weakness(weakness_duration))

func _apply_interrupt(ctx: BattleContext, source: Combatant, target: Combatant) -> void:
	if not interrupt or target == null or not target.is_alive():
		return
	var landed := false
	if not pierce_interrupt_resistance and target.has_status(StatusInstance.ID_INTERRUPT_RESISTANCE):
		landed = false
	elif not target.has_status(StatusInstance.ID_INTERRUPT_IMMUNE):
		target.chain.reset_current_card_progress()
		target.apply_status(StatusInstance.new(StatusInstance.ID_INTERRUPT_IMMUNE, 1, interrupt_immune_duration))
		ctx.stats.interrupts_landed += 1
		landed = true
	if landed and haste_on_interrupt_success > 0:
		source.apply_status(StatusInstance.new(StatusInstance.ID_HASTE, 1, haste_on_interrupt_success))

func _apply_shield(ctx: BattleContext, source: Combatant, had_shield: bool) -> void:
	var amount := shield
	if shield_bonus_if_had_shield and had_shield:
		amount += int(shield * shield_bonus_damage_ratio)
	if amount <= 0:
		return
	var _before := 0
	var existing := source.get_status(StatusInstance.ID_SHIELD)
	if existing:
		_before = existing.stacks
	source.apply_status(StatusInstance.make_shield(amount))
	if source.chain:
		source.chain.add_cycle_shield(amount)
	ctx.record_heal(source, source, 0)

func _apply_charge_before_damage(source: Combatant) -> void:
	var amount := charge
	if bonus_charge_if_prev_tag != &"" and _previous_card_has_tag(source, bonus_charge_if_prev_tag):
		amount += 1
	if amount <= 0:
		return
	var existing := source.get_status(StatusInstance.ID_CHARGE)
	if existing:
		existing.stacks += amount
	else:
		source.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, amount, -1))

func _apply_damage(ctx: BattleContext, source: Combatant, target: Combatant, had_shield: bool) -> void:
	if target == null or not target.is_alive():
		return
	var total := 0
	if charge_consume:
		var charge_status := source.get_status(StatusInstance.ID_CHARGE)
		var charge_stacks := charge_status.stacks if charge_status else 0
		var spent: int = maxi(0, charge_stacks - preserve_charge)
		if charge_status:
			if preserve_charge > 0:
				charge_status.stacks = mini(charge_status.stacks, preserve_charge)
			else:
				source.remove_status(StatusInstance.ID_CHARGE)
		total += charge_base_damage + int(spent * charge_multiplier)
		if charge_refund_threshold > 0 and spent >= charge_refund_threshold:
			source.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, charge_refund, -1))
	if shield_damage_ratio > 0.0:
		var shield_status := source.get_status(StatusInstance.ID_SHIELD)
		if shield_status:
			total += int(shield_status.stacks * shield_damage_ratio)
	if damage > 0:
		var dmg := damage
		if bonus_if_prev_tag != &"" and _previous_card_has_tag(source, bonus_if_prev_tag):
			dmg += bonus_damage
		if bonus_if_self_status != &"" and source.has_status(bonus_if_self_status):
			dmg += bonus_damage
		if bonus_if_target_status != &"" and target.has_status(bonus_if_target_status):
			dmg += bonus_damage
		if bonus_per_target_status_stack != &"":
			var st := target.get_status(bonus_per_target_status_stack)
			if st:
				dmg += st.stacks * bonus_per_stack
		if bonus_per_debuff_kind > 0:
			dmg += _count_debuffs(target) * bonus_per_debuff_kind
		if had_shield and shield_bonus_if_had_shield:
			dmg += int(shield * shield_bonus_damage_ratio)
		total += dmg
	if interrupt_damage > 0:
		total += interrupt_damage
	if burn_detonate_ratio > 0.0:
		var burn := target.get_status(StatusInstance.ID_BURN)
		if burn:
			total += int(float(burn.stacks * max(1, burn.remaining_ticks)) * burn_detonate_ratio)
			target.remove_status(StatusInstance.ID_BURN)
	if source.chain:
		total = source.chain.modify_damage(source.chain.get_current_card(), total)
	for _i in range(maxi(1, hits)):
		if total <= 0 or not target.is_alive():
			return
		var dealt := target.take_damage(total, source.tags)
		ctx.record_damage(source, target, dealt)

func _apply_echo(ctx: BattleContext, source: Combatant) -> void:
	if echo_previous <= 0 or source.chain == null:
		return
	var copied := 0
	var idx := source.chain.current_index - 1
	while idx >= 0 and copied < echo_previous:
		var prev: CardRuntime = source.chain.slots[idx]
		if prev and not prev.is_consumed and not prev.data.tags.has(echo_exclude_tag):
			if prev.data.effect:
				prev.data.effect.fire(ctx, source)
				copied += 1
		idx -= 1
	if copied > 0 and echo_haste_on_success > 0:
		source.apply_status(StatusInstance.new(StatusInstance.ID_HASTE, 1, echo_haste_on_success))

func _apply_cycle_rewards(source: Combatant) -> void:
	if source.chain == null:
		return
	if cycle_damage > 0:
		source.chain.add_cycle_damage(cycle_damage)
	if cycle_damage_per_tag != &"" and cycle_damage_per_tag_amount > 0:
		var count := int(source.chain.cycle_tag_counts.get(cycle_damage_per_tag, 0))
		source.chain.add_cycle_damage(count * cycle_damage_per_tag_amount)
	if cycle_heal > 0:
		source.chain.add_cycle_heal(cycle_heal)
	if cycle_haste > 0:
		source.chain.add_cycle_haste(cycle_haste)
	if cycle_threshold_played > 0 and source.chain.cycle_played_count >= cycle_threshold_played:
		if cycle_threshold_heal > 0:
			source.chain.add_cycle_heal(cycle_threshold_heal)
		if cycle_threshold_haste > 0:
			source.chain.add_cycle_haste(cycle_threshold_haste)

func _previous_card_has_tag(source: Combatant, tag: StringName) -> bool:
	if source.chain == null:
		return false
	var idx := source.chain.current_index - 1
	if idx < 0 or idx >= source.chain.slots.size():
		return false
	var prev: CardRuntime = source.chain.slots[idx]
	return prev != null and prev.data.tags.has(tag)

func _count_debuffs(target: Combatant) -> int:
	var ids := [
		StatusInstance.ID_WEAKNESS,
		StatusInstance.ID_VULNERABLE,
		StatusInstance.ID_SLOW,
		StatusInstance.ID_BURN,
		StatusInstance.ID_FREEZE,
		StatusInstance.ID_MARK,
	]
	var count := 0
	for id in ids:
		if target.has_status(id):
			count += 1
	return count
