# tests/integration/test_battle_simulator.gd
# 战斗模拟器集成测试
extends GutTest

func _make_player_with_attack_deck() -> Combatant:
	var player := Combatant.new(&"sword", "剑修", 80)
	# 简单攻击链条：3 张攻击卡，各 1 tick，伤害 10
	var slots: Array[CardRuntime] = []
	for i in 3:
		var card := CardData.new()
		card.id = StringName("test_atk_%d" % i)
		card.cost = 1
		var effect := preload("res://src/core/effects/effect_attack.gd").new()
		effect.damage = 10
		# 注意：effect_script 是 GDScript 引用，这里模拟一下
		card.effect_script = preload("res://src/core/effects/effect_attack.gd")
		slots.append(CardRuntime.new(card))
	player.chain.set_slots(slots)
	return player

func _make_weak_enemy() -> Combatant:
	# 30 HP 的弱敌，链条空
	var e := Combatant.new(&"slime", "史莱姆", 30)
	return e

func test_simulator_instantiates() -> void:
	var sim := BattleSimulator.new()
	assert_not_null(sim, "BattleSimulator should instantiate")

func test_player_wins_vs_empty_enemy() -> void:
	var sim := BattleSimulator.new()
	var player := _make_player_with_attack_deck()
	var enemy := _make_weak_enemy()

	var result := sim.simulate(player, [enemy], 0)
	assert_eq(result.winner, BattleContext.Winner.PLAYER,
		"Player with attack deck should beat empty-chain enemy")

func test_result_has_ticks_elapsed() -> void:
	var sim := BattleSimulator.new()
	var player := _make_player_with_attack_deck()
	var enemy := _make_weak_enemy()

	var result := sim.simulate(player, [enemy], 0)
	assert_gt(result.ticks_elapsed, 0, "ticks_elapsed should be > 0")

func test_timeout_when_nobody_can_win() -> void:
	# 双方都没有攻击手段 → 应该超时
	var sim := BattleSimulator.new()
	var player := Combatant.new(&"sword", "剑修", 80)  # 无链条
	var enemy := Combatant.new(&"golem", "石像鬼", 999)  # 无链条

	var result := sim.simulate(player, [enemy], 0, 10)  # 最大 10 tick
	assert_eq(result.winner, BattleContext.Winner.TIMEOUT,
		"Should timeout when neither side can win")
	assert_lte(result.ticks_elapsed, 10, "Should respect max_ticks")

func test_calc_win_rate_all_wins() -> void:
	var results: Array[BattleSimulator.BattleResult] = []
	for i in 3:
		var r := BattleSimulator.BattleResult.new()
		r.winner = BattleContext.Winner.PLAYER
		results.append(r)
	assert_eq(BattleSimulator.calc_win_rate(results), 1.0, "All wins = 100% win rate")

func test_calc_win_rate_empty() -> void:
	assert_eq(BattleSimulator.calc_win_rate([]), 0.0, "Empty results = 0% win rate")
