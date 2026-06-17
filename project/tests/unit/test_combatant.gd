# tests/unit/test_combatant.gd
# Combatant 单元测试
extends GutTest

# ─── 辅助 ────────────────────────────────────────────────────

func _make_combatant(hp: int = 80) -> Combatant:
	return Combatant.new(&"hero", "Hero", hp)

func _make_ctx(c: Combatant) -> BattleContext:
	var dummy := Combatant.new(&"dummy", "Dummy", 999)
	return BattleContext.new(c, [dummy])

# ─── HP 测试 ──────────────────────────────────────────────────

func test_take_damage_reduces_hp() -> void:
	var c := _make_combatant(80)
	c.take_damage(10)
	assert_eq(c.hp, 70, "HP should decrease by damage amount")

func test_take_damage_cannot_go_below_zero() -> void:
	var c := _make_combatant(10)
	c.take_damage(100)
	assert_eq(c.hp, 0, "HP should not go below 0")

func test_heal_increases_hp() -> void:
	var c := _make_combatant(80)
	c.take_damage(30)
	c.heal(10)
	assert_eq(c.hp, 60, "Heal should restore HP")

func test_heal_cannot_exceed_max_hp() -> void:
	var c := _make_combatant(80)
	c.heal(100)
	assert_eq(c.hp, 80, "HP should not exceed max_hp")

func test_is_alive_false_at_zero_hp() -> void:
	var c := _make_combatant(10)
	c.take_damage(10)
	assert_false(c.is_alive(), "Combatant should be dead at 0 HP")

# ─── 护盾测试 ─────────────────────────────────────────────────

func test_shield_absorbs_damage() -> void:
	var c := _make_combatant(80)
	var shield := StatusInstance.make_shield(5)
	c.apply_status(shield)
	c.take_damage(3)
	assert_eq(c.hp, 80, "Shield should fully absorb 3 damage")
	assert_eq(c.get_status(StatusInstance.ID_SHIELD).stacks, 2, "Shield should have 2 stacks remaining")

func test_shield_partial_absorb() -> void:
	var c := _make_combatant(80)
	var shield := StatusInstance.make_shield(3)
	c.apply_status(shield)
	c.take_damage(10)
	assert_eq(c.hp, 73, "Remaining 7 damage should hit HP after shield depleted")
	assert_null(c.get_status(StatusInstance.ID_SHIELD), "Shield should be removed after depletion")

# ─── 虚弱测试 ─────────────────────────────────────────────────

func test_weakness_increases_damage_taken() -> void:
	var c := _make_combatant(80)
	c.apply_status(StatusInstance.make_weakness(3))
	var dealt := c.take_damage(10)
	assert_eq(dealt, 15, "Weakness should increase damage taken by 50%")
	assert_eq(c.hp, 65)

# ─── 状态测试 ─────────────────────────────────────────────────

func test_apply_status_stacks_same_type() -> void:
	var c := _make_combatant(80)
	c.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, 2))
	c.apply_status(StatusInstance.new(StatusInstance.ID_CHARGE, 3))
	assert_eq(c.get_status(StatusInstance.ID_CHARGE).stacks, 5, "Same status should stack")

func test_remove_status() -> void:
	var c := _make_combatant(80)
	c.apply_status(StatusInstance.make_weakness(3))
	c.remove_status(StatusInstance.ID_WEAKNESS)
	assert_false(c.has_status(StatusInstance.ID_WEAKNESS), "Status should be removed")

func test_burn_deals_damage_per_tick() -> void:
	var c := _make_combatant(80)
	var ctx := _make_ctx(c)
	c.apply_status(StatusInstance.make_burn(5, 3))
	c.tick_statuses(ctx)
	assert_eq(c.hp, 75, "Burn should deal 5 damage per tick")

func test_burn_expires_after_duration() -> void:
	var c := _make_combatant(80)
	var ctx := _make_ctx(c)
	c.apply_status(StatusInstance.make_burn(5, 2))
	c.tick_statuses(ctx)  # tick 1: burn, remaining 1
	c.tick_statuses(ctx)  # tick 2: burn, remaining 0 → expires
	assert_false(c.has_status(StatusInstance.ID_BURN), "Burn should expire after duration")
	c.tick_statuses(ctx)  # tick 3: no more burn
	assert_eq(c.hp, 70, "Only 2 ticks of burn should have been dealt")

func test_died_signal_emitted_on_zero_hp() -> void:
	var c := _make_combatant(10)
	# GDScript lambda 不能写外部 var（捕获是值），用数组的可变性绕开
	var died_flag: Array = [false]
	c.died.connect(func(): died_flag[0] = true)
	c.take_damage(10)
	assert_true(died_flag[0], "died signal should be emitted when HP reaches 0")
