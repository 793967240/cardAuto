extends GutTest

func _make_combatant(hp: int = 80) -> Combatant:
	return Combatant.new(&"test_combatant", "Test", hp)

func _make_card(cost: int = 1, damage: int = 5) -> CardData:
	var card := CardData.new()
	card.id = &"test_card_%d" % randi()
	card.cost = cost
	var fx := EffectAttack.new()
	fx.damage = damage
	card.effect = fx
	return card

func _make_runtime(card: CardData) -> CardRuntime:
	return CardRuntime.new(card)

func _make_ctx(player: Combatant, enemies: Array[Combatant] = []) -> BattleContext:
	if enemies.is_empty():
		var dummy := Combatant.new(&"dummy", "Dummy", 999)
		enemies = [dummy]
	return BattleContext.new(player, enemies)

func test_chain_with_one_card_fires_after_cost_ticks() -> void:
	var player := _make_combatant()
	var card := _make_card(2)
	var runtime := _make_runtime(card)

	var ctx := _make_ctx(player)
	player.chain.set_slots([runtime])

	var fired: Array[int] = [0]
	player.chain.card_fired.connect(func(_c, _i): fired[0] += 1)

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 0, "Card with cost 2 should not fire after 1 tick")

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 1, "Card with cost 2 should fire after 2 ticks")

func test_chain_cycles_after_all_cards() -> void:
	var player := _make_combatant()
	var card := _make_card(1)
	var runtime := _make_runtime(card)

	var ctx := _make_ctx(player)
	player.chain.set_slots([runtime])

	var cycled: Array = [false]
	player.chain.cycle_completed.connect(func(): cycled[0] = true)

	player.chain.on_tick(ctx)
	assert_true(cycled[0], "Chain should cycle after all cards fire")
	assert_eq(player.chain.current_index, 0, "Index should reset to 0 after cycle")

func test_chain_restarts_and_fires_again() -> void:
	var player := _make_combatant()
	var card := _make_card(1)
	var ctx := _make_ctx(player)
	player.chain.set_slots([_make_runtime(card)])

	var fired: Array[int] = [0]
	player.chain.card_fired.connect(func(_c, _i): fired[0] += 1)

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 1)

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 2, "Chain should restart and fire again immediately")

func test_empty_chain_emits_chain_empty() -> void:
	var player := _make_combatant()
	var ctx := _make_ctx(player)
	player.chain.set_slots([])

	var emitted: Array = [false]
	player.chain.chain_empty.connect(func(): emitted[0] = true)
	player.chain.on_tick(ctx)
	assert_true(emitted[0], "Empty chain should emit chain_empty signal")

func test_reset_current_card_progress() -> void:
	var player := _make_combatant()
	var card := _make_card(3)
	var ctx := _make_ctx(player)
	player.chain.set_slots([_make_runtime(card)])

	var fired: Array[int] = [0]
	player.chain.card_fired.connect(func(_c, _i): fired[0] += 1)

	player.chain.on_tick(ctx)
	player.chain.on_tick(ctx)
	assert_eq(fired[0], 0)

	player.chain.reset_current_card_progress()

	player.chain.on_tick(ctx)
	player.chain.on_tick(ctx)
	assert_eq(fired[0], 0, "After reset, card should not fire until full cost")

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 1, "Card should fire after 3 ticks from reset")

func test_multi_card_chain_cycles_correctly() -> void:
	var player := _make_combatant()
	var card1 := _make_card(1, 3)
	var card2 := _make_card(1, 5)
	var ctx := _make_ctx(player)
	player.chain.set_slots([_make_runtime(card1), _make_runtime(card2)])

	var fired: Array[int] = [0]
	player.chain.card_fired.connect(func(_c, _i): fired[0] += 1)

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 1)
	assert_eq(player.chain.current_index, 1)

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 2)
	assert_eq(player.chain.current_index, 0, "Should cycle back to index 0")

	player.chain.on_tick(ctx)
	assert_eq(fired[0], 3, "Second cycle should start firing again")
