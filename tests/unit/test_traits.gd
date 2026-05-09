# tests/unit/test_traits.gd
# 词条系统单元测试
# 阶段 2 §2.1 / TC-2-TEST-001
# 覆盖：
#   - TraitData.is_mutex_with（互斥规则）
#   - TraitInstance.upgrade（lv1 → lv2）
#   - TraitValidator.can_attach / can_replace
#   - Chain.modify_damage（PASSIVE 修饰聚合）
#   - Chain hook 触发：on_card_played / on_recovery_started / on_chain_ended
#   - 共享词条多槽位引用去重
extends GutTest

# ─── 测试辅助 ────────────────────────────────────────────────

func _make_trait(id: StringName, scope: TraitData.Scope = TraitData.Scope.INDEPENDENT,
		trigger: TraitData.Trigger = TraitData.Trigger.PASSIVE) -> TraitData:
	var t := TraitData.new()
	t.id = id
	t.scope = scope
	t.trigger = trigger
	return t

func _make_card(cost: int = 1, dmg: int = 5) -> CardRuntime:
	var cd := CardData.new()
	cd.id = &"test_card"
	cd.cost = cost
	var fx := EffectAttack.new()
	fx.damage = dmg
	cd.effect = fx
	return CardRuntime.new(cd)

# 一个把 cost 全部归一的 PASSIVE 词条
class _CostMinusOne extends TraitEffect:
	func modify_cost(_card: CardRuntime, base: int) -> int:
		return base - 1

# 一个把伤害翻倍的 PASSIVE 词条
class _DamageDouble extends TraitEffect:
	func modify_damage(_card: CardRuntime, base: int) -> int:
		return base * 2

# 一个事件 hook 计数器
class _EventCounter extends TraitEffect:
	var played_count: Array = [0]
	var recovery_count: Array = [0]
	var chain_end_count: Array = [0]
	func on_card_played(_c, _ctx, _src) -> void:
		played_count[0] += 1
	func on_recovery_started(_ctx, _own) -> void:
		recovery_count[0] += 1
	func on_chain_ended(_ctx, _own) -> void:
		chain_end_count[0] += 1

# ─── TraitData 互斥 ──────────────────────────────────────────

func test_mutex_tags_intersect_returns_true() -> void:
	var a := _make_trait(&"a")
	a.tags = [&"cost_mod"]
	var b := _make_trait(&"b")
	b.mutex_tags = [&"cost_mod"]
	assert_true(a.is_mutex_with(b), "a.tags ∩ b.mutex_tags 非空 → 互斥")
	assert_true(b.is_mutex_with(a), "互斥关系对称")

func test_mutex_no_intersect_returns_false() -> void:
	var a := _make_trait(&"a")
	a.tags = [&"damage_mod"]
	var b := _make_trait(&"b")
	b.mutex_tags = [&"cost_mod"]
	assert_false(a.is_mutex_with(b), "无交集 → 不互斥")

func test_mutex_with_null_returns_false() -> void:
	var a := _make_trait(&"a")
	assert_false(a.is_mutex_with(null), "对 null 返回 false")

# ─── TraitInstance 升级 ──────────────────────────────────────

func test_upgrade_switches_to_plus_data() -> void:
	var base := _make_trait(&"sharp")
	var plus := _make_trait(&"sharp_plus")
	base.upgrade = plus
	var inst := TraitInstance.new(base)
	assert_eq(inst.get_level(), 1, "初始 lv1")
	assert_true(inst.upgrade(), "升级成功返回 true")
	assert_eq(inst.data, plus, "data 切到 plus")
	assert_eq(inst.get_level(), 2, "升级后 lv2")
	assert_true(inst.is_upgraded(), "is_upgraded() 为真")

func test_upgrade_without_plus_returns_false() -> void:
	var base := _make_trait(&"sharp")  # 没 set upgrade
	var inst := TraitInstance.new(base)
	assert_false(inst.upgrade(), "无 +版本时升级失败")
	assert_eq(inst.get_level(), 1, "等级保持 lv1")

# ─── TraitValidator ──────────────────────────────────────────

func test_validator_empty_slot_allows_any() -> void:
	var t := _make_trait(&"a")
	var r := TraitValidator.can_attach([], t)
	assert_true(r.ok, "空槽位允许挂载")

func test_validator_full_slot_rejects() -> void:
	var existing := _make_trait(&"a")
	var incoming := _make_trait(&"b")
	var r := TraitValidator.can_attach([existing], incoming)
	assert_false(r.ok, "满槽拒绝")
	assert_eq(r.reason, &"trait.error.slot_full", "reason = slot_full")
	assert_eq(r.conflict, existing, "返回冲突词条")

func test_validator_replace_returns_old() -> void:
	var existing := _make_trait(&"a")
	var incoming := _make_trait(&"b")
	var r := TraitValidator.can_replace([existing], incoming)
	assert_true(r.ok, "替换允许")
	assert_eq(r.conflict, existing, "返回被替换词条")

func test_validator_replace_duplicate_rejects() -> void:
	var t := _make_trait(&"a")
	var r := TraitValidator.can_replace([t], t)
	assert_false(r.ok, "重复挂载同一词条拒绝")
	assert_eq(r.reason, &"trait.error.duplicate")

# ─── Chain.modify_damage PASSIVE 聚合 ────────────────────────

func test_chain_modify_damage_aggregates_passive() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var card := _make_card(1, 10)
	var slot := ChainSlot.new(card)

	var trait_data := _make_trait(&"dmg_double")
	trait_data.effect = _DamageDouble.new()
	slot.independent_trait = TraitInstance.new(trait_data)

	var layout: Array = [slot]
	p.chain.set_layout(layout)
	var out := p.chain.modify_damage(card, 10, 0)
	assert_eq(out, 20, "PASSIVE.modify_damage 翻倍")

func test_chain_effective_cost_aggregates_passive() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var card := _make_card(3, 5)
	var slot := ChainSlot.new(card)

	var trait_data := _make_trait(&"cost_minus_one")
	trait_data.effect = _CostMinusOne.new()
	slot.independent_trait = TraitInstance.new(trait_data)

	var layout: Array = [slot]
	p.chain.set_layout(layout)
	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	var eff_cost := p.chain._effective_cost(card, ctx)
	assert_eq(eff_cost, 2, "cost 3 - 1 = 2")

func test_chain_passive_floor_min_one() -> void:
	# 即使词条把 cost 降到 0 或负数，最终 cost 不低于 1
	var p := Combatant.new(&"p", "P", 80)
	var card := _make_card(1, 5)
	var slot := ChainSlot.new(card)
	var trait_data := _make_trait(&"cost_minus_one")
	trait_data.effect = _CostMinusOne.new()
	slot.independent_trait = TraitInstance.new(trait_data)
	var layout: Array = [slot]
	p.chain.set_layout(layout)
	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	var eff_cost := p.chain._effective_cost(card, ctx)
	assert_eq(eff_cost, 1, "cost 1 - 1 但 floor 1")

# ─── 事件 hook ───────────────────────────────────────────────

func test_on_card_played_hook_fires_per_card() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var counter := _EventCounter.new()
	var trait_data := _make_trait(&"counter", TraitData.Scope.INDEPENDENT, TraitData.Trigger.ON_PLAY)
	trait_data.effect = counter

	var card := _make_card(1, 5)
	var slot := ChainSlot.new(card)
	slot.independent_trait = TraitInstance.new(trait_data)
	p.chain.set_layout([slot])

	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	# 1 tick → fire
	p.chain.on_tick(ctx)
	assert_eq(counter.played_count[0], 1, "ON_PLAY hook 触发 1 次")

func test_on_recovery_started_hook_fires_once() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var counter := _EventCounter.new()
	var trait_data := _make_trait(&"counter", TraitData.Scope.INDEPENDENT, TraitData.Trigger.ON_RECOVERY)
	trait_data.effect = counter

	var card := _make_card(1, 5)
	var slot := ChainSlot.new(card)
	slot.independent_trait = TraitInstance.new(trait_data)
	p.chain.set_layout([slot])

	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	p.chain.on_tick(ctx)  # fire + 进修整
	assert_eq(counter.recovery_count[0], 1, "ON_RECOVERY hook 触发 1 次")

func test_shared_trait_fires_only_once_across_slots() -> void:
	# 关键回归：共享词条挂在 N 个槽位上时，事件 hook 只触发 1 次（按引用去重）
	var p := Combatant.new(&"p", "P", 80)
	var counter := _EventCounter.new()
	var trait_data := _make_trait(&"shared_counter", TraitData.Scope.SHARED, TraitData.Trigger.ON_RECOVERY)
	trait_data.effect = counter
	var shared_inst := TraitInstance.new(trait_data)

	# 3 个槽位都挂同一个 shared_inst
	var slot_a := ChainSlot.new(_make_card(1, 5))
	slot_a.shared_trait = shared_inst
	var slot_b := ChainSlot.new(_make_card(1, 5))
	slot_b.shared_trait = shared_inst
	var slot_c := ChainSlot.new(_make_card(1, 5))
	slot_c.shared_trait = shared_inst
	p.chain.set_layout([slot_a, slot_b, slot_c])

	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	# 跑到链条结束（3 张 cost-1 卡 = 3 ticks）
	p.chain.on_tick(ctx)
	p.chain.on_tick(ctx)
	p.chain.on_tick(ctx)
	# 第 3 次 on_tick 后进入 recovery
	assert_eq(counter.recovery_count[0], 1, "共享词条仅触发 1 次（按引用去重）")
