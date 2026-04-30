# tests/headless_runner.gd
# Headless CI 测试入口 - 用 preload 显式加载，不依赖编辑器插件注册
# 用法: godot --headless --script tests/headless_runner.gd
extends SceneTree

var _pass := 0
var _fail := 0
var _errors: Array[String] = []

func _init() -> void:
	print("\n====== TimeChain Headless Tests ======\n")
	_run_timeline_tests()
	_run_chain_tests()
	_run_simulator_tests()
	print("\n====== RESULTS ======")
	print("PASSED: %d  FAILED: %d" % [_pass, _fail])
	for e in _errors:
		print("  FAIL: ", e)
	if _fail > 0:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASSED")
		quit(0)

func _assert(condition: bool, name: String) -> void:
	if condition:
		print("  v ", name)
		_pass += 1
	else:
		print("  x ", name)
		_fail += 1
		_errors.append(name)

func _assert_eq(a, b, name: String) -> void:
	_assert(a == b, "%s (got %s, want %s)" % [name, str(a), str(b)])

func _assert_gt(a, b, name: String) -> void:
	_assert(a > b, "%s (%s > %s)" % [name, str(a), str(b)])

func _run_timeline_tests() -> void:
	print("--- Timeline ---")
	var Timeline = preload("res://src/core/timeline.gd")
	var t: RefCounted

	t = Timeline.new()
	var ticks := 0
	t.tick_advanced.connect(func(_n): ticks += 1)
	t.update(1.0)
	_assert_eq(ticks, 2, "1s @1x = 2 ticks")

	t = Timeline.new()
	t.set_speed_multiplier(2.0)
	ticks = 0
	t.tick_advanced.connect(func(_n): ticks += 1)
	t.update(1.0)
	_assert_eq(ticks, 4, "1s @2x = 4 ticks")

	t = Timeline.new()
	t.set_speed_multiplier(4.0)
	ticks = 0
	t.tick_advanced.connect(func(_n): ticks += 1)
	t.update(1.0)
	_assert_eq(ticks, 8, "1s @4x = 8 ticks")

	t = Timeline.new()
	ticks = 0
	t.tick_advanced.connect(func(_n): ticks += 1)
	t.update(0.4)
	_assert_eq(ticks, 0, "0.4s = 0 ticks")
	t.update(0.2)
	_assert_eq(ticks, 1, "0.6s total = 1 tick")

	t = Timeline.new()
	t.update(2.0)
	t.reset()
	_assert_eq(t.get_current_tick(), 0, "reset clears tick")

	t = Timeline.new()
	var received: Array = []
	t.tick_advanced.connect(func(n): received.append(n))
	t.advance_ticks(3)
	_assert_eq(received, [1, 2, 3], "advance_ticks(3) = [1,2,3]")

func _run_chain_tests() -> void:
	print("\n--- Chain ---")
	var Combatant = preload("res://src/core/combatant.gd")
	var CardData = preload("res://src/data_models/card_data.gd")
	var CardRuntime = preload("res://src/core/card_runtime.gd")
	var BattleContext = preload("res://src/core/battle_context.gd")

	var dummy := Combatant.new(&"e", "E", 999)

	var player := Combatant.new(&"p", "P", 80)
	var ctx := BattleContext.new(player, [dummy])
	var card := CardData.new()
	card.cost = 2
	player.chain.set_slots([CardRuntime.new(card)])
	var fired := 0
	player.chain.card_fired.connect(func(_c, _i): fired += 1)
	player.chain.on_tick(ctx)
	_assert_eq(fired, 0, "cost-2: no fire after 1 tick")
	player.chain.on_tick(ctx)
	_assert_eq(fired, 1, "cost-2: fires after 2 ticks")

	var p2 := Combatant.new(&"p2", "P2", 80)
	var ctx2 := BattleContext.new(p2, [dummy])
	var card2 := CardData.new()
	card2.cost = 1
	p2.chain.set_slots([CardRuntime.new(card2)])
	var recovered := false
	p2.chain.recovery_started.connect(func(_d): recovered = true)
	p2.chain.on_tick(ctx2)
	_assert(recovered, "enters recovery after all cards done")

	var p3 := Combatant.new(&"p3", "P3", 80)
	var ctx3 := BattleContext.new(p3, [dummy])
	p3.chain.set_slots([])
	var empty_emitted := false
	p3.chain.chain_empty.connect(func(): empty_emitted = true)
	p3.chain.on_tick(ctx3)
	_assert(empty_emitted, "empty chain emits chain_empty")

	var dur := ctx.compute_recovery_duration(player)
	_assert(dur >= BattleContext.RECOVERY_MIN_TICKS, "recovery >= min")

func _run_simulator_tests() -> void:
	print("\n--- BattleSimulator ---")
	var BattleSimulator = preload("res://src/core/battle_simulator.gd")
	var Combatant = preload("res://src/core/combatant.gd")
	var BattleContext = preload("res://src/core/battle_context.gd")
	var CardData = preload("res://src/data_models/card_data.gd")
	var CardRuntime = preload("res://src/core/card_runtime.gd")
	var EffectAttack = preload("res://src/core/effects/effect_attack.gd")

	var sim = BattleSimulator.new()
	_assert(sim != null, "BattleSimulator instantiates")

	var player := Combatant.new(&"sword", "Sword", 80)
	var slots: Array = []
	for i in 3:
		var c := CardData.new()
		c.cost = 1
		c.effect_script = EffectAttack
		slots.append(CardRuntime.new(c))
	player.chain.set_slots(slots)
	var enemy := Combatant.new(&"slime", "Slime", 30)
	var result = sim.simulate(player, [enemy], 0)
	_assert_eq(result.winner, BattleContext.Winner.PLAYER, "player beats weak enemy")
	_assert_gt(result.ticks_elapsed, 0, "ticks_elapsed > 0")

	var p2 := Combatant.new(&"p", "P", 80)
	var e2 := Combatant.new(&"e", "E", 999)
	var r2 = sim.simulate(p2, [e2], 0, 10)
	_assert_eq(r2.winner, BattleContext.Winner.TIMEOUT, "timeout when nobody wins")

	var results: Array = []
	for i in 3:
		var r = BattleSimulator.BattleResult.new()
		r.winner = BattleContext.Winner.PLAYER
		results.append(r)
	_assert_eq(BattleSimulator.calc_win_rate(results), 1.0, "3/3 wins = 100%")
	_assert_eq(BattleSimulator.calc_win_rate([]), 0.0, "empty = 0%")
