# tests/unit/test_effects.gd
# 卡牌效果单元测试（攻击/充能/打断/蓄力/强力一击/防御/回响）
extends GutTest

# ─── 辅助 ────────────────────────────────────────────────────

func _make_player(hp: int = 80) -> Combatant:
	var p := Combatant.new(&"player", "Player", hp)
	p.tags = [&"sword"]
	return p

func _make_enemy(hp: int = 40) -> Combatant:
	return Combatant.new(&"enemy", "Enemy", hp)

func _make_ctx(player: Combatant, enemy: Combatant) -> BattleContext:
	return BattleContext.new(player, [enemy])

# ─── EffectAttack ─────────────────────────────────────────────

func test_attack_deals_damage_to_target() -> void:
	var p := _make_player()
	var e := _make_enemy(40)
	var ctx := _make_ctx(p, e)

	var fx := EffectAttack.new()
	fx.damage = 8
	fx.fire(ctx, p)
	assert_eq(e.hp, 32, "Attack should deal 8 damage")

func test_attack_does_not_affect_source() -> void:
	var p := _make_player()
	var e := _make_enemy(40)
	var ctx := _make_ctx(p, e)

	var fx := EffectAttack.new()
	fx.damage = 10
	fx.fire(ctx, p)
	assert_eq(p.hp, 80, "Attacker HP should not change")

func test_attack_multi_hits() -> void:
	var p := _make_player()
	var e := _make_enemy(40)
	var ctx := _make_ctx(p, e)

	var fx := EffectAttack.new()
	fx.damage = 3
	fx.hits = 3
	fx.fire(ctx, p)
	assert_eq(e.hp, 31, "3 hits × 3 damage = 9 total")

# ─── EffectCharge ─────────────────────────────────────────────

func test_charge_adds_stacks() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	var fx := EffectCharge.new()
	fx.charge_amount = 2
	fx.fire(ctx, p)
	assert_eq(p.get_status(StatusInstance.ID_CHARGE).stacks, 2, "Should gain 2 charge stacks")

func test_charge_stacks_on_existing() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	var fx := EffectCharge.new()
	fx.charge_amount = 3
	fx.fire(ctx, p)
	fx.fire(ctx, p)
	assert_eq(p.get_status(StatusInstance.ID_CHARGE).stacks, 6, "Charge should stack to 6")

# ─── EffectBuildup ────────────────────────────────────────────

func test_buildup_adds_more_charge() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	var fx := EffectBuildup.new()
	fx.charge_amount = 4
	fx.fire(ctx, p)
	assert_eq(p.get_status(StatusInstance.ID_CHARGE).stacks, 4, "Buildup should add 4 charge")

# ─── EffectPowerStrike ────────────────────────────────────────

func test_power_strike_consumes_charge() -> void:
	var p := _make_player()
	var e := _make_enemy(100)
	var ctx := _make_ctx(p, e)

	# 预置 5 层充能
	p.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, 5))

	var fx := EffectPowerStrike.new()
	fx.base_damage = 10
	fx.charge_multiplier = 2.0
	fx.consume_all_charge = true
	fx.fire(ctx, p)

	# 10 + 5 * 2 = 20 伤害
	assert_eq(e.hp, 80, "Power strike should deal 20 damage with 5 charge")
	assert_null(p.get_status(StatusInstance.ID_CHARGE), "All charge should be consumed")

func test_power_strike_with_no_charge() -> void:
	var p := _make_player()
	var e := _make_enemy(100)
	var ctx := _make_ctx(p, e)

	var fx := EffectPowerStrike.new()
	fx.base_damage = 10
	fx.charge_multiplier = 2.0
	fx.fire(ctx, p)

	assert_eq(e.hp, 90, "Power strike with no charge should deal base_damage only")

# ─── EffectDefense ────────────────────────────────────────────

func test_defense_adds_shield() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	var fx := EffectDefense.new()
	fx.shield_amount = 6
	fx.fire(ctx, p)
	assert_eq(p.get_status(StatusInstance.ID_SHIELD).stacks, 6, "Defense should add 6 shield")

func test_defense_stacks_on_existing_shield() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	var fx := EffectDefense.new()
	fx.shield_amount = 4
	fx.fire(ctx, p)
	fx.fire(ctx, p)
	assert_eq(p.get_status(StatusInstance.ID_SHIELD).stacks, 8, "Shield should stack")

# ─── EffectInterrupt ──────────────────────────────────────────

func test_interrupt_resets_enemy_card_progress() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	# 给敌人一张 cost=3 的牌
	var card_data := CardData.new()
	card_data.id = &"heavy_strike"
	card_data.cost = 3
	var runtime := CardRuntime.new(card_data)
	e.chain.set_slots([runtime])

	# 推进 2 tick
	e.chain.on_tick(ctx)
	e.chain.on_tick(ctx)
	assert_eq(e.chain.current_card_progress, 2)

	# 打断
	var fx := EffectInterrupt.new()
	fx.fire(ctx, p)
	assert_eq(e.chain.current_card_progress, 0, "Interrupt should reset card progress")

func test_interrupt_immune_prevents_double_interrupt() -> void:
	var p := _make_player()
	var e := _make_enemy()
	var ctx := _make_ctx(p, e)

	var card_data := CardData.new()
	card_data.id = &"test"
	card_data.cost = 5
	e.chain.set_slots([CardRuntime.new(card_data)])

	# 第一次打断成功
	var fx := EffectInterrupt.new()
	fx.fire(ctx, p)
	assert_true(e.has_status(StatusInstance.ID_INTERRUPT_IMMUNE), "Should have interrupt immunity")

	# 推进 2 tick
	e.chain.on_tick(ctx)
	e.chain.on_tick(ctx)
	var progress_before := e.chain.current_card_progress

	# 第二次打断被免疫
	fx.fire(ctx, p)
	assert_eq(e.chain.current_card_progress, progress_before, "Immune target should not be interrupted again")
