# tests/integration/test_gem_run_flow.gd
# 阶段 2 宝石循环集成测试：
# Run 初始化 → 宝石挂载 → ChainComposer 编译 → 战斗模拟 → 存档复水。
extends GutTest

var _save: SaveSystem

func before_each() -> void:
	_save = SaveSystem.new()
	if _save.has_active_run():
		_save.delete_run()
	GameState.current_run = null
	GameState.is_simulation = false

func after_each() -> void:
	if _save.has_active_run():
		_save.delete_run()
	GameState.current_run = null
	GameState.is_simulation = false

func _load_gem(id: String) -> GemData:
	var gem := load("res://data/gems/%s.tres" % id) as GemData
	assert_not_null(gem, "load gem %s" % id)
	return gem

func _compose_run(run: RunState) -> ChainComposer.Result:
	var spec := ChainComposer.Spec.new()
	spec.bases = run.bases.duplicate()
	spec.base_cards = run.base_cards.duplicate()
	spec.base_gems = run.base_gems.duplicate()
	return ChainComposer.compose(spec)

func _make_player_from_run(run: RunState) -> Combatant:
	var player := Combatant.new(&"player", "Sword", run.max_hp)
	player.hp = run.hp
	player.tags = [&"sword"]
	var result := _compose_run(run)
	assert_eq(result.errors.size(), 0, "Run should compose without errors")
	assert_gt(result.layout.size(), 0, "Run should compose at least one chain slot")
	player.chain.set_layout(result.layout)
	return player

func _make_empty_enemy(hp: int = 40) -> Combatant:
	return Combatant.new(&"dummy", "Dummy", hp)

func test_start_run_initializes_bases_and_gem_inventory() -> void:
	GameState.start_run(&"sword")
	var run := GameState.current_run

	assert_not_null(run, "start_run should create current_run")
	assert_eq(run.bases.size(), Tuning.get_default().base_count, "Run should create tuning base count")
	assert_eq(run.deck.size(), 0, "Run should start with an empty card repository before starter card repository selection")
	assert_eq(GameState._flatten_chain_cards(run).size(), 0, "Run should start with an empty real card chain")
	assert_eq(run.gems.size(), GameState.STARTER_GEMS.size(), "Run should grant starter gems")
	assert_eq(run.base_gems.size(), run.bases.size(), "Every base should have a gem entry")

	for base in run.bases:
		assert_true(run.base_gems.has(base.id), "base_gems should contain %s" % str(base.id))

func test_apply_starter_deck_fills_three_cards_and_bases() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run

	assert_eq(run.deck.size(), 3, "Starter card repository choice should grant 3 cards")
	assert_eq(run.chain_cards.size(), 3, "Starter card repository choice should put 3 cards on the real chain")
	assert_eq(run.deck[0].rarity, CardData.Rarity.UNCOMMON, "Starter card repository starts with one uncommon card")
	assert_eq(run.deck[1].rarity, CardData.Rarity.COMMON, "Starter card repository has a common card")
	assert_eq(run.deck[2].rarity, CardData.Rarity.COMMON, "Starter card repository has a second common card")
	assert_eq(run.base_cards[run.bases[0].id].id, run.deck[0].id, "First base should receive first starter card")
	assert_eq(run.base_cards[run.bases[1].id].id, run.deck[1].id, "Second base should receive second starter card")
	assert_eq(run.base_cards[run.bases[2].id].id, run.deck[2].id, "Third base should receive third starter card")

func test_guard_counter_starter_uses_shield_payoff_card() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(2)
	var run := GameState.current_run

	assert_eq(run.deck[2].id, &"fan_shou",
		"Guard-counter starter should include Riposte as the shield payoff")
	assert_eq(run.base_cards[run.bases[2].id].id, &"fan_shou",
		"Riposte should begin on the chain")

func test_run_gem_assignment_composes_into_battle_layout() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var ruby := GemInstance.new(_load_gem("ruby"))
	var base_id: StringName = run.bases[0].id

	run.base_gems[base_id] = [ruby]
	var result := _compose_run(run)

	assert_eq(result.errors.size(), 0, "Gem assignment should compose cleanly")
	assert_gt(result.layout.size(), 0, "Composer should produce layout")
	assert_eq(result.layout[0].base_id, base_id, "First chain slot should keep source base id")
	assert_eq(result.layout[0].gems.size(), 1, "First chain slot should include assigned gem")
	assert_eq(result.layout[0].gems[0].data.id, &"ruby", "Assigned ruby should reach battle layout")

func test_run_layout_with_ruby_changes_battle_damage() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	run.base_gems[run.bases[0].id] = [GemInstance.new(_load_gem("ruby"))]

	var player := _make_player_from_run(run)
	var enemy := _make_empty_enemy(40)
	var sim := BattleSimulator.new()
	var result := sim.simulate(player, [enemy], 123, 20)

	assert_eq(result.winner, BattleContext.Winner.PLAYER, "Starter run with ruby should beat empty enemy")
	assert_gte(result.damage_dealt, 40, "Ruby-modified layout should deal enough damage through the battle path")

func test_save_load_preserves_base_gems_for_composer() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var ruby := GemInstance.new(_load_gem("ruby"))
	var sapphire := GemInstance.new(_load_gem("sapphire"))

	run.base_gems[run.bases[0].id] = [ruby]
	run.base_gems[run.bases[1].id] = [sapphire]

	assert_true(_save.save_run(run), "save_run should succeed")
	var loaded := _save.load_run()

	assert_not_null(loaded, "load_run should return RunState")
	if loaded == null:
		return

	var result := _compose_run(loaded)
	assert_eq(result.errors.size(), 0, "Loaded run should compose without errors")
	assert_eq(result.layout[0].gems[0].data.id, &"ruby", "Ruby should survive save/load")
	assert_eq(result.layout[1].gems[0].data.id, &"sapphire", "Sapphire should survive save/load")

func test_loaded_sapphire_layout_reduces_second_card_fire_timing() -> void:
	GameState.start_run(&"sword")
	GameState.apply_starter_deck(0)
	var run := GameState.current_run
	var quick_attack := load("res://data/cards/sword/qing_feng_zhan.tres") as CardData
	run.deck.append(quick_attack)
	run.base_cards[run.bases[1].id] = quick_attack
	var sapphire := GemInstance.new(_load_gem("sapphire"))
	run.base_gems[run.bases[1].id] = [sapphire]

	assert_true(_save.save_run(run), "save_run should succeed")
	var loaded := _save.load_run()
	var player := _make_player_from_run(loaded)
	var ctx := BattleContext.new(player, [_make_empty_enemy(999)])

	var fired_indices: Array[int] = []
	player.chain.card_fired.connect(func(_card, idx): fired_indices.append(idx))

	player.chain.on_tick(ctx)
	assert_eq(fired_indices, [0], "First base card should fire on tick 1")

	player.chain.on_tick(ctx)
	assert_eq(fired_indices, [0, 1], "Sapphire should reduce second card cost enough to fire on tick 2")
