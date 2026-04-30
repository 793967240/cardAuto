# tests/unit/test_chain.gd
# Chain 单元测试
extends GutTest

# ─── 测试辅助 ────────────────────────────────────────────────

func _make_combatant(hp: int = 80) -> Combatant:
	return Combatant.new(&"test_combatant", "Test", hp)

func _make_card(cost: int = 1, damage: int = 5) -> CardData:
	var card := CardData.new()
	card.id = &"test_card_%d" % randi()
	card.cost = cost
	card.effect_script = preload("res://src/core/effects/effect_attack.gd")
	return card

func _make_runtime(card: CardData) -> CardRuntime:
	return CardRuntime.new(card)

func _make_ctx(player: Combatant, enemies: Array[Combatant] = []) -> BattleContext:
	if enemies.is_empty():
		var dummy := Combatant.new(&"dummy", "Dummy", 999)
		enemies = [dummy]
	return BattleContext.new(player, enemies)

# ─── 基础执行测试 ─────────────────────────────────────────────

func test_chain_with_one_card_fires_after_cost_ticks() -> void:
	var player := _make_combatant()
	var card := _make_card(2)  # cost 2 tick
	var runtime := _make_runtime(card)

	var ctx := _make_ctx(player)
	player.chain.set_slots([runtime])

	var fired_count := 0
	player.chain.card_fired.connect(func(_c, _i): fired_count += 1)

	# 1 tick - 未触发
	player.chain.on_tick(ctx)
	assert_eq(fired_count, 0, "Card with cost 2 should not fire after 1 tick")

	# 2 tick - 触发
	player.chain.on_tick(ctx)
	assert_eq(fired_count, 1, "Card with cost 2 should fire after 2 ticks")

func test_chain_enters_recovery_after_all_cards() -> void:
	var player := _make_combatant()
	var card := _make_card(1)
	var runtime := _make_runtime(card)

	var ctx := _make_ctx(player)
	player.chain.set_slots([runtime])

	var recovery_started := false
	player.chain.recovery_started.connect(func(_d): recovery_started = true)

	# 1 tick - 卡牌触发
	player.chain.on_tick(ctx)
	assert_true(recovery_started, "Chain should enter recovery after all cards fire")

func test_chain_recovery_duration_respects_minimum() -> void:
	var player := _make_combatant()
	var ctx := _make_ctx(player)

	# 默认修整时长 2 tick
	var duration := ctx.compute_recovery_duration(player)
	assert_gte(duration, BattleContext.RECOVERY_MIN_TICKS, "Recovery duration should be >= min")

func test_chain_restarts_after_recovery() -> void:
	var player := _make_combatant()
	var card := _make_card(1)
	var ctx := _make_ctx(player)
	player.chain.set_slots([_make_runtime(card)])

	var fire_count := 0
	player.chain.card_fired.connect(func(_c, _i): fire_count += 1)

	# 触发卡 → 进修整（2 tick 默认）
	player.chain.on_tick(ctx)  # 触发
	assert_eq(fire_count, 1)

	# 修整 2 tick
	player.chain.on_tick(ctx)
	player.chain.on_tick(ctx)

	# 重新开始 → 再触发
	player.chain.on_tick(ctx)
	assert_eq(fire_count, 2, "Chain should restart and fire again after recovery")

func test_empty_chain_emits_chain_empty() -> void:
	var player := _make_combatant()
	var ctx := _make_ctx(player)
	player.chain.set_slots([])

	var empty_emitted := false
	player.chain.chain_empty.connect(func(): empty_emitted = true)
	player.chain.on_tick(ctx)
	assert_true(empty_emitted, "Empty chain should emit chain_empty signal")

func test_reset_current_card_progress() -> void:
	var player := _make_combatant()
	var card := _make_card(3)  # cost 3 tick
	var ctx := _make_ctx(player)
	player.chain.set_slots([_make_runtime(card)])

	var fire_count := 0
	player.chain.card_fired.connect(func(_c, _i): fire_count += 1)

	# 推进 2 tick
	player.chain.on_tick(ctx)
	player.chain.on_tick(ctx)
	assert_eq(fire_count, 0)

	# 重置进度
	player.chain.reset_current_card_progress()

	# 再推进 2 tick（总共只有 2 tick 进度）
	player.chain.on_tick(ctx)
	player.chain.on_tick(ctx)
	assert_eq(fire_count, 0, "After reset, card should not fire until full cost")

	# 第 3 tick
	player.chain.on_tick(ctx)
	assert_eq(fire_count, 1, "Card should fire after 3 ticks from reset")
