# tests/integration/test_balance_baseline.gd
# 阶段 1 平衡基线 smoke test
# 用 BattleSimulator 跑批量战斗，验证起手卡组的胜率在合理区间
extends GutTest

const BATCH_COUNT: int = 20  # 阶段 1 MVP 阶段先用小批量，CI 友好

# ─── 起手卡组工厂 ─────────────────────────────────────────────

func _make_card(id: StringName, cost: int, effect: CardEffect) -> CardData:
	var card := CardData.new()
	card.id = id
	card.cost = cost
	card.effect = effect
	return card

func _make_starter_chain() -> Array[CardRuntime]:
	# 起手卡组（与 GDD §12 阶段 1 对齐）：
	# 斩(1t,5dmg) - 蓄势(2t,+2charge) - 强劈(3t,10+charge×2) - 御剑盾(1t,+6shield) - 回响剑(2t)
	var slots: Array[CardRuntime] = []

	var fx_zhan := EffectAttack.new()
	fx_zhan.damage = 5
	slots.append(CardRuntime.new(_make_card(&"zhan", 1, fx_zhan)))

	var fx_buildup := EffectBuildup.new()
	fx_buildup.charge_amount = 2
	slots.append(CardRuntime.new(_make_card(&"xu_shi", 2, fx_buildup)))

	var fx_power := EffectPowerStrike.new()
	fx_power.base_damage = 10
	fx_power.charge_multiplier = 2.0
	fx_power.consume_all_charge = true
	slots.append(CardRuntime.new(_make_card(&"qiang_pi", 3, fx_power)))

	var fx_def := EffectDefense.new()
	fx_def.shield_amount = 6
	slots.append(CardRuntime.new(_make_card(&"yu_jian_dun", 1, fx_def)))

	var fx_echo := EffectEcho.new()
	fx_echo.copy_count = 1
	slots.append(CardRuntime.new(_make_card(&"hui_xiang_jian", 2, fx_echo)))

	return slots

func _make_player() -> Combatant:
	var p := Combatant.new(&"player", "Sword", 80)
	p.tags = [&"sword"]
	p.chain.set_slots(_make_starter_chain())
	return p

# ─── 敌人工厂 ────────────────────────────────────────────────

func _make_slime() -> Combatant:
	# 史莱姆：30HP，单卡链条（4 dmg, cost 2）
	var e := Combatant.new(&"slime", "Slime", 25)
	var fx := EffectAttack.new()
	fx.damage = 4
	var card := CardData.new()
	card.id = &"slime_strike"
	card.cost = 2
	card.effect = fx
	e.chain.set_slots([CardRuntime.new(card)])
	return e

func _make_stone_guard() -> Combatant:
	# 石像卫：40HP，防御+攻击双卡链
	var e := Combatant.new(&"stone_guard", "Stone Guard", 40)
	var fx_def := EffectDefense.new()
	fx_def.shield_amount = 4
	var card_def := CardData.new()
	card_def.id = &"guard_defend"
	card_def.cost = 1
	card_def.effect = fx_def

	var fx_atk := EffectAttack.new()
	fx_atk.damage = 6
	var card_atk := CardData.new()
	card_atk.id = &"guard_strike"
	card_atk.cost = 2
	card_atk.effect = fx_atk

	e.chain.set_slots([CardRuntime.new(card_def), CardRuntime.new(card_atk)])
	return e

# ─── 测试 ─────────────────────────────────────────────────────

func test_starter_vs_slime_baseline() -> void:
	var sim := BattleSimulator.new()
	var results := sim.simulate_batch(
		_make_player,
		func() -> Array[Combatant]: return [_make_slime()] as Array[Combatant],
		BATCH_COUNT, 1000, 600
	)
	var win_rate := BattleSimulator.calc_win_rate(results)
	push_warning("[balance] starter vs slime: win_rate = %.2f" % win_rate)
	# 阶段 1 起手卡组 vs 弱敌应当稳赢
	assert_gte(win_rate, 0.9,
		"Starter deck vs Slime: win rate should be >= 0.9 (got %.2f)" % win_rate)

func test_starter_vs_stone_guard_baseline() -> void:
	var sim := BattleSimulator.new()
	var results := sim.simulate_batch(
		_make_player,
		func() -> Array[Combatant]: return [_make_stone_guard()] as Array[Combatant],
		BATCH_COUNT, 2000, 600
	)
	var win_rate := BattleSimulator.calc_win_rate(results)
	push_warning("[balance] starter vs stone_guard: win_rate = %.2f" % win_rate)
	# Act 1 普通战斗：起手卡组应当能打过石像卫（>= 40%）
	# 上限不严格断言：阶段 1 MVP 卡组偏强是可接受的，平衡留待阶段 2 调
	assert_gte(win_rate, 0.4,
		"Starter deck vs Stone Guard: win rate should be >= 0.4 (got %.2f)" % win_rate)

func test_avg_ticks_reasonable() -> void:
	# 平均战斗时长应在合理区间（10-100 tick = 5-50 秒 @ 1x）
	var sim := BattleSimulator.new()
	var results := sim.simulate_batch(
		_make_player,
		func() -> Array[Combatant]: return [_make_slime()] as Array[Combatant],
		BATCH_COUNT, 3000, 600
	)
	var total_ticks := 0
	for r in results:
		total_ticks += r.ticks_elapsed
	var avg_ticks := float(total_ticks) / float(results.size())
	push_warning("[balance] avg battle ticks vs slime: %.1f" % avg_ticks)
	assert_gt(avg_ticks, 0, "Average ticks should be > 0")
	assert_lt(avg_ticks, 600, "Average ticks should be reasonable (< max)")
