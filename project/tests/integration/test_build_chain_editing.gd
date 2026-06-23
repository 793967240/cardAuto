extends GutTest

func before_each() -> void:
	GameState.current_run = null
	GameState.is_simulation = false

func after_each() -> void:
	GameState.current_run = null
	GameState.is_simulation = false

func _compose_run(run: RunState) -> ChainComposer.Result:
	var spec := ChainComposer.Spec.new()
	spec.bases = run.bases.duplicate()
	spec.base_cards = run.base_cards.duplicate()
	spec.base_gems = run.base_gems.duplicate()
	return ChainComposer.compose(spec)

func test_empty_base_composes_default_strike() -> void:
	GameState.start_run(&"sword")
	var run := GameState.current_run
	var base_id: StringName = run.bases[0].id
	run.base_cards[base_id] = null

	var result := _compose_run(run)

	assert_eq(result.errors.size(), 0, "Empty bases should be filled by default strike")
	assert_eq(result.layout.size(), run.bases.size(), "Composer should preserve all base positions")
	assert_eq(result.layout[0].base_id, base_id, "Default strike should keep source base id")
	assert_eq(result.layout[0].card.data.id, &"default_strike", "Empty base should compile to default strike")
	assert_eq(result.layout[0].card.data.cost, ChainComposer.DEFAULT_STRIKE_COST, "Default strike should be low cost")
	assert_eq(result.total_cost, _expected_total_cost(run), "Total cost should include default strike")

func test_drop_deck_card_replaces_chain_slot() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var target_id: StringName = run.bases[1].id
	var card: CardData = load("res://data/cards/sword/zhan.tres") as CardData
	run.deck.append(card)

	assert_true(BuildScene.apply_chain_slot_drop(run, 1, {"source": "deck_item", "card": card}),
		"Card repository drop should be accepted")

	assert_eq(run.base_cards[target_id].id, card.id, "Card repository card drop should replace target chain card")

func test_drop_chain_card_swaps_occupied_slots() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var first_id: StringName = run.bases[0].id
	var second_id: StringName = run.bases[1].id
	var first_before: CardData = run.base_cards[first_id]
	var second_before: CardData = run.base_cards[second_id]

	assert_true(BuildScene.apply_chain_slot_drop(run, 1, {
		"source": "slot",
		"slot_index": 0,
		"card": first_before,
	}), "Slot drop should be accepted")

	assert_eq(run.base_cards[first_id].id, second_before.id, "Source slot should receive target card")
	assert_eq(run.base_cards[second_id].id, first_before.id, "Target slot should receive dragged card")

func test_drop_chain_card_to_empty_slot_moves_and_leaves_empty() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var source_id: StringName = run.bases[0].id
	var target_id: StringName = run.bases[3].id
	var source_before: CardData = run.base_cards[source_id]
	run.base_cards[target_id] = null

	assert_true(BuildScene.apply_chain_slot_drop(run, 3, {
		"source": "slot",
		"slot_index": 0,
		"card": source_before,
	}), "Slot drop to empty should be accepted")

	assert_null(run.base_cards[source_id], "Source slot should become empty after moving to empty slot")
	assert_eq(run.base_cards[target_id].id, source_before.id, "Target empty slot should receive dragged card")

func test_drop_chain_card_to_deck_area_unloads_slot() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var source_id: StringName = run.bases[0].id
	assert_not_null(run.base_cards[source_id], "Source starts occupied")

	assert_true(BuildScene.apply_deck_area_drop(run, {
		"source": "slot",
		"slot_index": 0,
		"card": run.base_cards[source_id],
	}), "Slot drop to card repository area should be accepted")

	assert_null(run.base_cards[source_id], "Source slot should become empty after unloading")

func test_empty_deck_grid_keeps_drop_target_size() -> void:
	var scene := load("res://scenes/build/build_scene.tscn").instantiate() as BuildScene
	add_child(scene)
	await get_tree().process_frame

	assert_gte(int(scene.deck_grid.custom_minimum_size.y), 120,
		"Empty card repository grid should keep enough height to accept slot drops")

	scene.queue_free()

func test_default_strike_view_uses_chain_card_size() -> void:
	var view := load("res://scenes/components/card_view.tscn").instantiate() as CardView
	add_child(view)
	view.setup_build_chain_slot(null)

	assert_eq(view.custom_minimum_size, Vector2(CardView.BUILD_CHAIN_SLOT_WIDTH, CardView.BUILD_CHAIN_SLOT_HEIGHT),
		"Default Strike should use the same visual card size as occupied chain cards")

	view.queue_free()

func test_available_count_tracks_individual_duplicate_cards() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var zhan: CardData = run.deck[0]
	assert_eq(BuildScene.available_count_for_card(run, zhan), 0,
		"Both starter Slash copies begin on the chain")

	assert_true(BuildScene.apply_deck_area_drop(run, {
		"source": "slot",
		"slot_index": 0,
		"card": zhan,
	}), "Unloading one Slash should work")

	assert_eq(BuildScene.available_count_for_card(run, zhan), 1,
		"Unloading one duplicate should expose exactly one hand card")

func test_install_gem_instance_moves_from_previous_base() -> void:
	GameState.start_run(&"sword")
	var run := GameState.current_run
	var first_id: StringName = run.bases[0].id
	var second_id: StringName = run.bases[1].id
	var ruby := load("res://data/gems/ruby.tres") as GemData
	assert_not_null(ruby, "load ruby")
	var gem := GemInstance.new(ruby)
	run.gems.append(gem)

	assert_true(BuildScene.install_gem_instance(run, first_id, gem), "Gem should install on first base")
	assert_true(BuildScene.install_gem_instance(run, second_id, gem), "Gem should move to second base")

	assert_eq(run.base_gems[first_id].size(), 0, "Moving a gem should unload its previous base")
	assert_eq(run.base_gems[second_id].size(), 1, "Target base should receive moved gem")
	assert_true(run.base_gems[second_id][0] == gem, "Target base should keep the same gem instance")

func test_consumable_cards_are_limited_to_two_in_chain() -> void:
	GameState.start_run(&"sword")
	var run := GameState.current_run
	var consumable := load("res://data/cards/sword/qian_zhan.tres") as CardData
	run.deck = [consumable, consumable, consumable]
	for i in range(3):
		run.base_cards[run.bases[i].id] = null

	assert_true(BuildScene.apply_chain_slot_drop(run, 0, {"source": "deck_item", "card": consumable}),
		"First Consumable card should be accepted")
	assert_true(BuildScene.apply_chain_slot_drop(run, 1, {"source": "deck_item", "card": consumable}),
		"Second Consumable card should be accepted")
	assert_false(BuildScene.apply_chain_slot_drop(run, 2, {"source": "deck_item", "card": consumable}),
		"Third Consumable card should be rejected")
	assert_null(run.base_cards[run.bases[2].id], "Rejected Consumable card should not occupy the target base")

func test_duplicate_named_gems_remain_separate_instances() -> void:
	var ruby := load("res://data/gems/ruby.tres") as GemData
	var first := GemInstance.new(ruby)
	var second := GemInstance.new(ruby)
	var run := RunState.new()
	var base_a := SlotData.new()
	base_a.id = &"base_a"
	var base_b := SlotData.new()
	base_b.id = &"base_b"
	run.bases = [base_a, base_b]
	run.base_gems = {&"base_a": [], &"base_b": []}
	run.gems = [first, second]

	assert_true(BuildScene.install_gem_instance(run, &"base_a", first), "First ruby should install")
	assert_true(BuildScene.install_gem_instance(run, &"base_b", second), "Second ruby should install independently")

	assert_true(run.base_gems[&"base_a"][0] == first, "First base should keep first ruby instance")
	assert_true(run.base_gems[&"base_b"][0] == second, "Second base should keep second ruby instance")

func _expected_total_cost(run: RunState) -> int:
	var total := 0
	for base in run.bases:
		var card: CardData = run.base_cards.get(base.id, null)
		total += card.cost if card != null else ChainComposer.DEFAULT_STRIKE_COST
	return total
