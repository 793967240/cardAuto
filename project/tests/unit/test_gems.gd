extends GutTest

func _make_player(hp: int = 80) -> Combatant:
	return Combatant.new(&"sword", "Sword", hp)

func _make_enemy(hp: int = 40) -> Combatant:
	return Combatant.new(&"dummy", "Dummy", hp)

func _make_ctx(player: Combatant, enemy: Combatant) -> BattleContext:
	return BattleContext.new(player, [enemy])

func _make_attack_card(cost: int = 1, damage: int = 5) -> CardData:
	var card := CardData.new()
	card.id = &"test_attack"
	card.cost = cost
	card.tags = [&"sword"]
	var fx := EffectAttack.new()
	fx.damage = damage
	card.effect = fx
	return card

func _make_slot(id: StringName) -> SlotData:
	var slot := SlotData.new()
	slot.id = id
	slot.gem_socket_count = 1
	return slot

func _make_gem(id: StringName, trigger: GemData.Trigger, effect: GemEffect) -> GemData:
	var gem := GemData.new()
	gem.id = id
	gem.trigger = trigger
	gem.effect = effect
	return gem

func test_chain_composer_attaches_gems_to_matching_base() -> void:
	var card := _make_attack_card()
	var ruby_fx := GemEffectDamageBonus.new()
	var ruby := _make_gem(&"ruby", GemData.Trigger.PASSIVE, ruby_fx)

	var spec := ChainComposer.Spec.new()
	spec.bases = [_make_slot(&"base_0")]
	spec.base_cards = {&"base_0": card}
	spec.base_gems = {&"base_0": [ruby]}

	var result := ChainComposer.compose(spec)

	assert_eq(result.errors.size(), 0, "Composer should accept one card in one base")
	assert_eq(result.layout.size(), 1, "Composer should produce one chain slot")
	assert_eq(result.layout[0].base_id, &"base_0", "Chain slot should keep base id")
	assert_eq(result.layout[0].gems.size(), 1, "Chain slot should include attached gem")
	assert_eq(result.layout[0].gems[0].data.id, &"ruby", "Attached gem should be ruby")

func test_damage_bonus_gem_modifies_attached_card_damage() -> void:
	var player := _make_player()
	var enemy := _make_enemy(20)
	var ctx := _make_ctx(player, enemy)

	var card := _make_attack_card(1, 5)
	var ruby_fx := GemEffectDamageBonus.new()
	ruby_fx.bonus = 2
	var ruby := _make_gem(&"ruby", GemData.Trigger.PASSIVE, ruby_fx)

	var slot := ChainSlot.new(CardRuntime.new(card), &"base_0")
	slot.gems.append(GemInstance.new(ruby))
	player.chain.set_layout([slot])

	player.chain.on_tick(ctx)

	assert_eq(enemy.hp, 13, "Ruby should add +2 damage to the attached card")

func test_cost_reduction_gem_reduces_ticks_to_fire() -> void:
	var player := _make_player()
	var enemy := _make_enemy(20)
	var ctx := _make_ctx(player, enemy)

	var card := _make_attack_card(3, 5)
	var sapphire_fx := GemEffectCostReduction.new()
	sapphire_fx.reduction = 1
	var sapphire := _make_gem(&"sapphire", GemData.Trigger.PASSIVE, sapphire_fx)

	var slot := ChainSlot.new(CardRuntime.new(card), &"base_0")
	slot.gems.append(GemInstance.new(sapphire))
	player.chain.set_layout([slot])

	var fired_count: Array[int] = [0]
	player.chain.card_fired.connect(func(_c, _i): fired_count[0] += 1)

	player.chain.on_tick(ctx)
	assert_eq(fired_count[0], 0, "Cost 3 reduced by 1 should not fire on first tick")

	player.chain.on_tick(ctx)
	assert_eq(fired_count[0], 1, "Cost 3 reduced by 1 should fire on second tick")

func test_charge_on_play_gem_adds_charge_after_card_fires() -> void:
	var player := _make_player()
	var enemy := _make_enemy(20)
	var ctx := _make_ctx(player, enemy)

	var amber_fx := GemEffectChargeOnPlay.new()
	amber_fx.charge_amount = 2
	var amber := _make_gem(&"amber", GemData.Trigger.ON_PLAY, amber_fx)

	var slot := ChainSlot.new(CardRuntime.new(_make_attack_card()), &"base_0")
	slot.gems.append(GemInstance.new(amber))
	player.chain.set_layout([slot])

	player.chain.on_tick(ctx)

	assert_eq(player.get_status(StatusInstance.ID_CHARGE).stacks, 2, "Amber should add charge after attached card fires")

func test_cycle_heal_gem_heals_owner_when_chain_completes() -> void:
	var player := _make_player(80)
	player.take_damage(10)
	var enemy := _make_enemy(40)
	var ctx := _make_ctx(player, enemy)

	var jade_fx := GemEffectCycleHeal.new()
	jade_fx.heal_amount = 3
	var jade := _make_gem(&"jade", GemData.Trigger.ON_CYCLE, jade_fx)

	var slot := ChainSlot.new(CardRuntime.new(_make_attack_card()), &"base_0")
	slot.gems.append(GemInstance.new(jade))
	player.chain.set_layout([slot])

	player.chain.on_tick(ctx)

	assert_eq(player.hp, 73, "Jade should heal owner when the chain completes a cycle")
