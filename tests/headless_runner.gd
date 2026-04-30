# tests/headless_runner.gd
# Headless CI 测试入口
extends SceneTree

var _pass = 0
var _fail = 0
var _errors = []

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
	_assert(a == b, "%s  (got %s  want %s)" % [name, str(a), str(b)])

func _assert_gt(a, b, name: String) -> void:
	_assert(a > b, "%s  (%s > %s)" % [name, str(a), str(b)])

# ─── Timeline ────────────────────────────────────────────────

var _tick_count_a = 0
var _tick_count_b = 0
var _tick_count_c = 0
var _tick_count_d = 0
var _received = []

func _on_tick_a(_n): _tick_count_a += 1
func _on_tick_b(_n): _tick_count_b += 1
func _on_tick_c(_n): _tick_count_c += 1
func _on_tick_d(_n): _tick_count_d += 1
func _on_tick_recv(n): _received.append(n)

func _run_timeline_tests() -> void:
	print("--- Timeline ---")
	var TL = preload("res://src/core/timeline.gd")

	_tick_count_a = 0
	var t = TL.new()
	t.tick_advanced.connect(_on_tick_a)
	t.update(1.0)
	_assert_eq(_tick_count_a, 2, "1s @1x = 2 ticks")

	_tick_count_b = 0
	t = TL.new()
	t.set_speed_multiplier(2.0)
	t.tick_advanced.connect(_on_tick_b)
	t.update(1.0)
	_assert_eq(_tick_count_b, 4, "1s @2x = 4 ticks")

	_tick_count_c = 0
	t = TL.new()
	t.set_speed_multiplier(4.0)
	t.tick_advanced.connect(_on_tick_c)
	t.update(1.0)
	_assert_eq(_tick_count_c, 8, "1s @4x = 8 ticks")

	_tick_count_d = 0
	t = TL.new()
	t.tick_advanced.connect(_on_tick_d)
	t.update(0.4)
	_assert_eq(_tick_count_d, 0, "0.4s = 0 ticks")
	t.update(0.2)
	_assert_eq(_tick_count_d, 1, "0.6s total = 1 tick")

	t = TL.new()
	t.update(2.0)
	t.reset()
	_assert_eq(t.get_current_tick(), 0, "reset clears tick")

	_received = []
	t = TL.new()
	t.tick_advanced.connect(_on_tick_recv)
	t.advance_ticks(3)
	_assert_eq(_received, [1, 2, 3], "advance_ticks(3) = [1,2,3]")

# ─── Chain ───────────────────────────────────────────────────

var _chain_fired = 0
var _chain_recovered = false
var _chain_empty = false

func _on_chain_fired(_c, _i): _chain_fired += 1
func _on_recovered(_d): _chain_recovered = true
func _on_empty(): _chain_empty = true

func _run_chain_tests() -> void:
	print("\n--- Chain ---")
	var Combatant = preload("res://src/core/combatant.gd")
	var CardData = preload("res://src/data_models/card_data.gd")
	var CardRuntime = preload("res://src/core/card_runtime.gd")
	var BattleContext = preload("res://src/core/battle_context.gd")

	var dummy = Combatant.new(&"e", "E", 999)

	# cost-2 카드 테스트
	_chain_fired = 0
	var player = Combatant.new(&"p", "P", 80)
	var ctx = BattleContext.new(player, [dummy])
	var card = CardData.new()
	card.cost = 2
	var rt = CardRuntime.new(card)
	var slots: Array = [rt]
	player.chain.set_slots(slots)
	player.chain.card_fired.connect(_on_chain_fired)
	player.chain.on_tick(ctx)
	_assert_eq(_chain_fired, 0, "cost-2: no fire after 1 tick")
	player.chain.on_tick(ctx)
	_assert_eq(_chain_fired, 1, "cost-2: fires after 2 ticks")

	# recovery
	_chain_recovered = false
	var p2 = Combatant.new(&"p2", "P2", 80)
	var ctx2 = BattleContext.new(p2, [dummy])
	var card2 = CardData.new()
	card2.cost = 1
	var rt2 = CardRuntime.new(card2)
	var slots2: Array = [rt2]
	p2.chain.set_slots(slots2)
	p2.chain.recovery_started.connect(_on_recovered)
	p2.chain.on_tick(ctx2)
	_assert(_chain_recovered, "enters recovery after all cards done")

	# empty chain
	_chain_empty = false
	var p3 = Combatant.new(&"p3", "P3", 80)
	var ctx3 = BattleContext.new(p3, [dummy])
	var empty_slots: Array = []
	p3.chain.set_slots(empty_slots)
	p3.chain.chain_empty.connect(_on_empty)
	p3.chain.on_tick(ctx3)
	_assert(_chain_empty, "empty chain emits chain_empty")

	# recovery min
	var dur = ctx.compute_recovery_duration(player)
	_assert(dur >= BattleContext.RECOVERY_MIN_TICKS, "recovery >= min")

# ─── BattleSimulator ─────────────────────────────────────────

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

	# 玩家 vs 弱敌
	var player = Combatant.new(&"sword", "Sword", 80)
	var slots: Array = []
	for i in 3:
		var c = CardData.new()
		c.cost = 1
		c.effect_script = EffectAttack
		slots.append(CardRuntime.new(c))
	player.chain.set_slots(slots)
	var enemy = Combatant.new(&"slime", "Slime", 30)
	var result = sim.simulate(player, [enemy], 0)
	_assert_eq(result.winner, BattleContext.Winner.PLAYER, "player beats weak enemy")
	_assert_gt(result.ticks_elapsed, 0, "ticks_elapsed > 0")

	# 超时
	var p2 = Combatant.new(&"p", "P", 80)
	var e2 = Combatant.new(&"e", "E", 999)
	var r2 = sim.simulate(p2, [e2], 0, 10)
	_assert_eq(r2.winner, BattleContext.Winner.TIMEOUT, "timeout when nobody wins")

	# 胜率
	var results = sim.simulate_batch(
		func(): return Combatant.new(&"sword", "Sword", 80),
		func(): return [Combatant.new(&"e", "E", 999)],
		3, 0, 5
	)
	_assert_eq(results.size(), 3, "batch returns 3 results")
	# 全超时 winner = TIMEOUT，胜率 = 0
	_assert_eq(BattleSimulator.calc_win_rate(results), 0.0, "0 wins = 0% rate")
	_assert_eq(BattleSimulator.calc_win_rate([]), 0.0, "empty = 0%")
