# tests/integration/test_synergy_combos.gd
# 协同 build 集成测试 - 验证关键玩法机制可靠性
extends GutTest

# ─── 辅助 ────────────────────────────────────────────────────

func _make_card(id: StringName, cost: int, effect: CardEffect) -> CardData:
	var card := CardData.new()
	card.id = id
	card.cost = cost
	card.effect = effect
	return card

func _make_player(hp: int = 80) -> Combatant:
	var p := Combatant.new(&"player", "Player", hp)
	p.tags = [&"sword"]
	return p

func _make_dummy(hp: int = 999) -> Combatant:
	return Combatant.new(&"dummy", "Dummy", hp)

func _make_ctx(player: Combatant, enemy: Combatant) -> BattleContext:
	return BattleContext.new(player, [enemy])

# ─── 协同 1: 充能爆发流 ─────────────────────────────────────────

func test_charge_burst_combo() -> void:
	# 蓄势 + 蓄势 + 强劈：积累 4 充能 → 强劈伤害 = 10 + 4*2 = 18
	var p := _make_player()
	var e := _make_dummy(100)
	var ctx := _make_ctx(p, e)

	# 先连续两次蓄势（每次 +2 充能 → 4 充能）
	var fx_buildup := EffectBuildup.new()
	fx_buildup.charge_amount = 2
	fx_buildup.fire(ctx, p)
	fx_buildup.fire(ctx, p)

	assert_eq(p.get_status(StatusInstance.ID_CHARGE).stacks, 4,
		"After 2 buildups, charge should be 4")

	# 强劈：消耗全部充能，伤害 = 10 + 4*2 = 18
	var fx_power := EffectPowerStrike.new()
	fx_power.base_damage = 10
	fx_power.charge_multiplier = 2.0
	fx_power.consume_all_charge = true
	fx_power.fire(ctx, p)

	assert_eq(e.hp, 100 - 18,
		"Power strike with 4 charge should deal 18 damage (got hp=%d)" % e.hp)
	assert_null(p.get_status(StatusInstance.ID_CHARGE),
		"Charge should be consumed after power strike")

# ─── 协同 2: 回响复制 ─────────────────────────────────────────

func test_echo_copies_previous_card() -> void:
	# 链条：[斩(5dmg) → 回响]
	# 回响触发时，应复制前一张牌（斩）的效果，造成额外 5 点伤害
	var p := _make_player()
	var e := _make_dummy(100)
	var ctx := _make_ctx(p, e)

	var fx_atk := EffectAttack.new()
	fx_atk.damage = 5
	var card_atk := _make_card(&"zhan_test", 1, fx_atk)

	var fx_echo := EffectEcho.new()
	fx_echo.copy_count = 1
	var card_echo := _make_card(&"echo_test", 1, fx_echo)

	p.chain.set_slots([CardRuntime.new(card_atk), CardRuntime.new(card_echo)])

	# tick 1: 斩触发，造成 5 伤害
	p.chain.on_tick(ctx)
	assert_eq(e.hp, 95, "After zhan: enemy hp should be 95")

	# tick 2: 回响触发，复制前一张牌（斩）→ 额外 5 伤害
	p.chain.on_tick(ctx)
	assert_eq(e.hp, 90,
		"After echo (copying zhan): enemy hp should be 90 (got %d)" % e.hp)

# ─── 协同 3: 护盾吸收 ─────────────────────────────────────────

func test_shield_absorbs_damage_correctly() -> void:
	var p := _make_player(80)

	# 加 6 护盾
	var fx_def := EffectDefense.new()
	fx_def.shield_amount = 6
	var dummy := _make_dummy()
	var ctx := _make_ctx(p, dummy)
	fx_def.fire(ctx, p)

	assert_eq(p.get_status(StatusInstance.ID_SHIELD).stacks, 6,
		"Should have 6 shield")

	# 受到 5 伤害：被护盾完全吸收，剩余 1 护盾，HP 不变
	p.take_damage(5)
	assert_eq(p.hp, 80, "HP should be untouched (shield absorbed)")
	assert_eq(p.get_status(StatusInstance.ID_SHIELD).stacks, 1,
		"Shield should have 1 stack left")

	# 再受到 3 伤害：1 护盾抵 1 点 + HP 受 2
	p.take_damage(3)
	assert_eq(p.hp, 78, "HP should drop by 2 after shield depleted")
	assert_null(p.get_status(StatusInstance.ID_SHIELD),
		"Shield should be removed when depleted")

# ─── 协同 4: 打断系统 ─────────────────────────────────────────

func test_interrupt_resets_progress_and_grants_immunity() -> void:
	var p := _make_player()
	var e := _make_dummy(100)
	var ctx := _make_ctx(p, e)

	# 给敌人一张 cost=4 的卡
	var fx_e_atk := EffectAttack.new()
	fx_e_atk.damage = 10
	var enemy_card := _make_card(&"big_attack", 4, fx_e_atk)
	e.chain.set_slots([CardRuntime.new(enemy_card)])

	# 推进 3 tick（敌人卡积累到 3/4）
	for i in 3:
		e.chain.on_tick(ctx)
	assert_eq(e.chain.current_card_progress, 3,
		"Enemy card should have 3 progress")

	# 玩家打断
	var fx_interrupt := EffectInterrupt.new()
	fx_interrupt.also_damage = 5
	fx_interrupt.immune_duration = 4
	fx_interrupt.fire(ctx, p)

	assert_eq(e.chain.current_card_progress, 0,
		"Interrupt should reset enemy card progress")
	assert_true(e.has_status(StatusInstance.ID_INTERRUPT_IMMUNE),
		"Enemy should have interrupt immunity")
	assert_eq(e.hp, 95, "Interrupt also_damage should deal 5")

	# 第二次打断尝试：被免疫 → 进度不变（但伤害正常）
	for i in 2:
		e.chain.on_tick(ctx)
	var progress_before := e.chain.current_card_progress
	fx_interrupt.fire(ctx, p)
	assert_eq(e.chain.current_card_progress, progress_before,
		"Second interrupt should be blocked by immunity")
	assert_eq(e.hp, 90, "But also_damage should still hit (90)")

# ─── 协同 5: 易伤增加 cost ─────────────────────────────────────

func test_vulnerable_increases_card_cost() -> void:
	# 易伤：cost +1，验证 cost=1 的卡变成 cost=2
	var p := _make_player()
	var dummy := _make_dummy()
	var ctx := _make_ctx(p, dummy)

	var fx := EffectAttack.new()
	fx.damage = 5
	var card := _make_card(&"slow_zhan", 1, fx)
	p.chain.set_slots([CardRuntime.new(card)])

	# 施加易伤 3 tick
	p.apply_status(StatusInstance.make_vulnerable(5))

	var fired: Array[int] = [0]
	p.chain.card_fired.connect(func(_c, _i): fired[0] += 1)

	# tick 1: 进度 1，但 cost 因易伤变为 2，未触发
	p.chain.on_tick(ctx)
	assert_eq(fired[0], 0, "With vulnerable, cost-1 card should not fire after 1 tick")

	# tick 2: 进度 2，触发
	p.chain.on_tick(ctx)
	assert_eq(fired[0], 1, "Card should fire after 2 ticks with vulnerable")

# ─── 协同 6: 燃烧持续伤害 ────────────────────────────────────

func test_burn_deals_damage_over_ticks() -> void:
	var c := _make_player(80)
	var dummy := _make_dummy()
	var ctx := _make_ctx(c, dummy)

	# 施加 3 层燃烧，持续 3 tick
	c.apply_status(StatusInstance.make_burn(3, 3))

	# 推进 3 tick
	for i in 3:
		c.tick_statuses(ctx)

	# 总伤害 = 3 + 3 + 3 = 9
	assert_eq(c.hp, 80 - 9,
		"3 ticks of burn (3 dmg each) should deal 9 total damage")
	assert_false(c.has_status(StatusInstance.ID_BURN),
		"Burn should expire after duration")
