# tests/integration/test_chain_composer.gd
# ChainComposer 多底座链条编译集成测试
# 阶段 2 §2.2 / TC-2-CORE-005 + 006 / TC-2-TEST-002
extends GutTest

# ─── 辅助 ────────────────────────────────────────────────────

func _make_base(id: StringName, count: int = 6) -> SlotData:
	var s := SlotData.new()
	s.id = id
	s.slot_type = SlotData.SlotType.BASE
	s.slot_count = count
	s.has_bead_in = false
	s.has_bead_out = true
	return s

func _make_ext(id: StringName, count: int = 2) -> SlotData:
	var s := SlotData.new()
	s.id = id
	s.slot_type = SlotData.SlotType.EXTENDED
	s.slot_count = count
	s.has_bead_in = true
	s.has_bead_out = true
	return s

func _make_card(cost: int = 1, dmg: int = 5) -> CardData:
	var cd := CardData.new()
	cd.id = &"test_card"
	cd.cost = cost
	var fx := EffectAttack.new()
	fx.damage = dmg
	cd.effect = fx
	return cd

func _make_trait(id: StringName, scope: TraitData.Scope = TraitData.Scope.INDEPENDENT) -> TraitData:
	var t := TraitData.new()
	t.id = id
	t.scope = scope
	return t

# ─── 基本编译路径 ────────────────────────────────────────────

func test_single_base_no_extensions_compiles() -> void:
	var base := _make_base(&"sword_base", 3)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base]
	spec.slot_cards = {&"sword_base": [_make_card(2, 5), _make_card(1, 3), _make_card(1, 2)]}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0, "无错误")
	assert_eq(r.layout.size(), 3, "3 张卡进入 layout")
	assert_eq(r.connected_bases.size(), 1, "仅链头底座参与")
	assert_eq(r.orphan_bases.size(), 0, "无 orphan")
	assert_eq(r.total_cost, 4, "total_cost = 2+1+1")

func test_base_plus_one_extension_chains_in_order() -> void:
	var base := _make_base(&"sword_base", 2)
	var ext := _make_ext(&"ext_a", 2)
	var spec := ChainComposer.Spec.new()
	spec.slots = [ext, base]  # 故意打乱顺序，验证不依赖输入顺序
	spec.connections = {&"sword_base": &"ext_a"}
	spec.slot_cards = {
		&"sword_base": [_make_card(1, 1), _make_card(1, 2)],
		&"ext_a": [_make_card(1, 3), _make_card(1, 4)],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0, "无错误")
	assert_eq(r.layout.size(), 4, "4 张卡（2+2）")
	assert_eq(r.connected_bases[0].id, &"sword_base", "链头是基础底座")
	assert_eq(r.connected_bases[1].id, &"ext_a", "第二节是 ext_a")
	# layout 顺序：base 槽 0、base 槽 1、ext_a 槽 0、ext_a 槽 1
	assert_eq((r.layout[0] as ChainSlot).base_id, &"sword_base")
	assert_eq((r.layout[2] as ChainSlot).base_id, &"ext_a")

func test_three_bases_chain_in_full_order() -> void:
	var base := _make_base(&"sword_base", 1)
	var ext_a := _make_ext(&"ext_a", 1)
	var ext_b := _make_ext(&"ext_b", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext_a, ext_b]
	spec.connections = {&"sword_base": &"ext_a", &"ext_a": &"ext_b"}
	spec.slot_cards = {
		&"sword_base": [_make_card(1, 1)],
		&"ext_a": [_make_card(1, 2)],
		&"ext_b": [_make_card(1, 3)],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0)
	assert_eq(r.layout.size(), 3)
	assert_eq(r.connected_bases.size(), 3)

# ─── 未连接底座（orphan）────────────────────────────────────

func test_unconnected_extension_becomes_orphan() -> void:
	var base := _make_base(&"sword_base", 1)
	var ext := _make_ext(&"ext_unused", 2)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext]
	# 没有 connections → ext 是 orphan
	spec.slot_cards = {
		&"sword_base": [_make_card(1, 1)],
		&"ext_unused": [_make_card(1, 9), _make_card(1, 9)],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0, "orphan 不算错误，只是不参战")
	assert_eq(r.layout.size(), 1, "仅基础底座的 1 张卡进 layout")
	assert_eq(r.orphan_bases.size(), 1, "1 个 orphan")
	assert_eq(r.orphan_bases[0].id, &"ext_unused")

func test_partial_chain_some_extensions_orphan() -> void:
	# base → ext_a 连通，ext_b 未连
	var base := _make_base(&"sword_base", 1)
	var ext_a := _make_ext(&"ext_a", 1)
	var ext_b := _make_ext(&"ext_b", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext_a, ext_b]
	spec.connections = {&"sword_base": &"ext_a"}
	spec.slot_cards = {
		&"sword_base": [_make_card()],
		&"ext_a": [_make_card()],
		&"ext_b": [_make_card()],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.layout.size(), 2, "2 张卡进 layout")
	assert_eq(r.connected_bases.size(), 2)
	assert_eq(r.orphan_bases.size(), 1)
	assert_eq(r.orphan_bases[0].id, &"ext_b")

# ─── 错误路径 ────────────────────────────────────────────────

func test_no_base_slot_returns_error() -> void:
	var ext_a := _make_ext(&"ext_a", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [ext_a]
	var r := ChainComposer.compose(spec)
	assert_true(&"no_base_slot" in r.errors, "缺少基础底座 → 报错")

func test_multiple_base_slots_returns_error() -> void:
	var base_a := _make_base(&"a", 1)
	var base_b := _make_base(&"b", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base_a, base_b]
	var r := ChainComposer.compose(spec)
	assert_true(&"multiple_base_slots" in r.errors)

func test_cycle_returns_error() -> void:
	var base := _make_base(&"sword_base", 1)
	var ext_a := _make_ext(&"ext_a", 1)
	var ext_b := _make_ext(&"ext_b", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext_a, ext_b]
	# ext_a 指向 ext_b，ext_b 又指回 ext_a → 成环
	spec.connections = {
		&"sword_base": &"ext_a",
		&"ext_a": &"ext_b",
		&"ext_b": &"ext_a",
	}
	var r := ChainComposer.compose(spec)
	assert_true(&"cycle_detected" in r.errors)

func test_fork_returns_error() -> void:
	# base 同时指向 ext_a，ext_a 指向 ext_b；但另一条 base 也指向 ext_b（分叉）
	# 在单源场景下，分叉表现为「同一目标被多个出口指向」
	var base := _make_base(&"base", 1)
	var ext_a := _make_ext(&"ext_a", 1)
	var ext_b := _make_ext(&"ext_b", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext_a, ext_b]
	spec.connections = {
		&"base": &"ext_b",
		&"ext_a": &"ext_b",
	}
	var r := ChainComposer.compose(spec)
	assert_true(&"fork_detected" in r.errors)

func test_dangling_connection_returns_error() -> void:
	var base := _make_base(&"base", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base]
	spec.connections = {&"base": &"nonexistent"}
	var r := ChainComposer.compose(spec)
	assert_true(&"dangling_connection" in r.errors)

# ─── 词条挂载 ────────────────────────────────────────────────

func test_independent_trait_attaches_to_correct_slot() -> void:
	var base := _make_base(&"sword_base", 3)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base]
	spec.slot_cards = {&"sword_base": [_make_card(), _make_card(), _make_card()]}
	var t := _make_trait(&"sharp")
	spec.independent_traits = {"sword_base:1": t}  # 仅槽位 1 有词条
	var r := ChainComposer.compose(spec)
	assert_null((r.layout[0] as ChainSlot).independent_trait)
	assert_not_null((r.layout[1] as ChainSlot).independent_trait)
	assert_eq((r.layout[1] as ChainSlot).independent_trait.data, t)
	assert_null((r.layout[2] as ChainSlot).independent_trait)

func test_shared_trait_same_instance_across_extension_slots() -> void:
	var base := _make_base(&"base", 1)
	var ext := _make_ext(&"ext_a", 3)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext]
	spec.connections = {&"base": &"ext_a"}
	spec.slot_cards = {
		&"base": [_make_card()],
		&"ext_a": [_make_card(), _make_card(), _make_card()],
	}
	var st := _make_trait(&"flame_aura", TraitData.Scope.SHARED)
	spec.shared_traits = {&"ext_a": st}
	var r := ChainComposer.compose(spec)
	# layout: [base.0, ext_a.0, ext_a.1, ext_a.2]
	assert_eq(r.layout.size(), 4)
	# 基础底座的槽位不应挂共享词条
	assert_null((r.layout[0] as ChainSlot).shared_trait)
	# ext_a 的 3 个槽位应引用同一 TraitInstance
	var inst1 := (r.layout[1] as ChainSlot).shared_trait
	var inst2 := (r.layout[2] as ChainSlot).shared_trait
	var inst3 := (r.layout[3] as ChainSlot).shared_trait
	assert_not_null(inst1)
	assert_eq(inst1, inst2, "共享词条引用相同")
	assert_eq(inst2, inst3)

# ─── 与 Chain 集成 ──────────────────────────────────────────

func test_compose_then_chain_executes_in_order() -> void:
	var base := _make_base(&"base", 1)
	var ext := _make_ext(&"ext", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext]
	spec.connections = {&"base": &"ext"}
	# base.0 = 5 dmg, ext.0 = 10 dmg
	spec.slot_cards = {
		&"base": [_make_card(1, 5)],
		&"ext": [_make_card(1, 10)],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0)

	var p := Combatant.new(&"p", "P", 80)
	p.tags = [&"sword"]
	p.chain.set_layout(r.layout)
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])

	# 1 tick → base.0 fire (5 dmg)
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 95, "base.0 命中")
	# 1 tick → ext.0 fire (10 dmg)
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 85, "ext.0 命中")

func test_orphan_extension_cards_dont_fire() -> void:
	var base := _make_base(&"base", 1)
	var orphan := _make_ext(&"orphan", 1)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, orphan]
	# 不连 orphan
	spec.slot_cards = {
		&"base": [_make_card(1, 5)],
		&"orphan": [_make_card(1, 99)],  # 99 dmg 但应该不参战
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.layout.size(), 1, "仅 base 的卡进 layout")

	var p := Combatant.new(&"p", "P", 80)
	p.tags = [&"sword"]
	p.chain.set_layout(r.layout)
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	# 跑 5 ticks（够多了）
	for i in 5:
		p.chain.on_tick(ctx)
	# 只有 base.0 (5 dmg) 反复打，不应有 99 伤害单击
	assert_true(enemy.hp >= 100 - 5 * 5, "orphan 卡未参战")
	assert_true(enemy.hp <= 95, "至少打过一次 base 卡")

# ─── 空槽位处理 ──────────────────────────────────────────────

func test_null_card_in_slot_is_skipped() -> void:
	var base := _make_base(&"base", 3)
	var spec := ChainComposer.Spec.new()
	spec.slots = [base]
	# 槽位 1 是 null（玩家没摆牌）
	spec.slot_cards = {&"base": [_make_card(), null, _make_card()]}
	var r := ChainComposer.compose(spec)
	assert_eq(r.layout.size(), 2, "空槽不进 layout")
