# tests/integration/test_trait_samples.gd
# 阶段 2 词条样品验收测试 — 8 个典型词条的 .tres 资源加载 + 行为正确
# 阶段 2 §2.1 / TC-2-DATA-003/004 探路
extends GutTest

# ─── 资源加载 ────────────────────────────────────────────────

const TRAITS := {
	# 独立词条
	"sharp_blade": "res://data/traits/independent/sharp_blade.tres",
	"swift_strike": "res://data/traits/independent/swift_strike.tres",
	"charge_well": "res://data/traits/independent/charge_well.tres",
	"fragile_edge": "res://data/traits/independent/fragile_edge.tres",
	"combo_breath": "res://data/traits/independent/combo_breath.tres",
	# 共享词条
	"flame_aura": "res://data/traits/shared/flame_aura.tres",
	"echo_chamber": "res://data/traits/shared/echo_chamber.tres",
	"recovery_blast": "res://data/traits/shared/recovery_blast.tres",
}

func _load(id: String) -> TraitData:
	return load(TRAITS[id]) as TraitData

func _make_card(cost: int, dmg: int, tags: Array[StringName] = []) -> CardData:
	var cd := CardData.new()
	cd.id = &"sample"
	cd.cost = cost
	cd.tags = tags
	var fx := EffectAttack.new()
	fx.damage = dmg
	cd.effect = fx
	return cd

# ─── 全部 .tres 能加载 ──────────────────────────────────────

func test_all_trait_tres_load() -> void:
	for id in TRAITS:
		var t := _load(id)
		assert_not_null(t, "%s 加载成功" % id)
		assert_eq(t.id, StringName(id), "%s id 匹配" % id)
		assert_not_null(t.effect, "%s effect 非空" % id)

# ─── PASSIVE: sharp_blade（伤害 +2）─────────────────────────

func test_sharp_blade_adds_2_damage() -> void:
	var p := Combatant.new(&"p", "P", 80)
	p.tags = [&"sword"]
	var cd := _make_card(1, 5)
	var rt := CardRuntime.new(cd)
	var slot := ChainSlot.new(rt)
	slot.independent_trait = TraitInstance.new(_load("sharp_blade"))
	p.chain.set_layout([slot])
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	p.chain.on_tick(ctx)
	# fire (5 + 2 = 7 dmg)
	assert_eq(enemy.hp, 93, "sharp_blade +2 = 7 dmg")

# ─── PASSIVE: swift_strike（cost -1）──────────────────────

func test_swift_strike_reduces_cost() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var cd := _make_card(2, 5)
	var rt := CardRuntime.new(cd)
	var slot := ChainSlot.new(rt)
	slot.independent_trait = TraitInstance.new(_load("swift_strike"))
	p.chain.set_layout([slot])
	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	# cost 2 - 1 = 1 → 1 tick 命中
	p.chain.on_tick(ctx)
	assert_eq(dummy.hp, 994, "1 tick 命中（cost 降到 1）")

# ─── ON_PLAY: charge_well（打出 +1 充能）────────────────────

func test_charge_well_grants_charge_on_play() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var cd := _make_card(1, 5)
	var rt := CardRuntime.new(cd)
	var slot := ChainSlot.new(rt)
	slot.independent_trait = TraitInstance.new(_load("charge_well"))
	p.chain.set_layout([slot])
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	p.chain.on_tick(ctx)
	var charge := p.get_status(StatusInstance.ID_CHARGE)
	assert_not_null(charge, "owner 获得充能")
	assert_eq(charge.stacks, 1, "+1 充能")

# ─── PASSIVE: fragile_edge（cost -1，含取舍 tag）────────────

func test_fragile_edge_reduces_cost() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var cd := _make_card(3, 5)
	var rt := CardRuntime.new(cd)
	var slot := ChainSlot.new(rt)
	slot.independent_trait = TraitInstance.new(_load("fragile_edge"))
	p.chain.set_layout([slot])
	var dummy := Combatant.new(&"e", "E", 999)
	var ctx := BattleContext.new(p, [dummy])
	# cost 3 - 1 = 2 → 2 ticks 命中
	p.chain.on_tick(ctx)
	assert_eq(dummy.hp, 999, "1 tick 未命中")
	p.chain.on_tick(ctx)
	assert_eq(dummy.hp, 994, "2 tick 命中")

# ─── ON_CHAIN_END: combo_breath（链条结束重打末位）────────

func test_combo_breath_replays_last_card() -> void:
	var p := Combatant.new(&"p", "P", 80)
	# 链条只有 1 张（cost 1，5 dmg），就是末位
	var cd := _make_card(1, 5)
	var rt := CardRuntime.new(cd)
	var slot := ChainSlot.new(rt)
	var combo := _load("combo_breath")
	# 重置 _triggered_count（共享 Resource 的污染）
	(combo.effect as TraitEffectChainEndReplay).reset()
	slot.independent_trait = TraitInstance.new(combo)
	p.chain.set_layout([slot])
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	# tick 1: fire (5 dmg) → 进入 recovery
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 95, "首次 fire 后 hp=95")
	# 推完 recovery 触发 _restart_chain → on_chain_ended → 重打末位（5 dmg）
	# RECOVERY_MIN_TICKS 默认 1（设计），跑足够 tick 推过 recovery
	for _i in 5:
		p.chain.on_tick(ctx)
		if not p.chain.is_recovering():
			break
	# 现在应该已重启链条 + 触发了一次 chain_end_replay
	# 重启后 current_index=0，再跑 1 tick 第二轮 fire (5 dmg)
	# 但 chain_end_replay 在 _restart_chain 内已经多打了 1 次
	# 所以第 2 轮还没真正 fire 时 hp 应该 = 95 - 5(replay) = 90
	assert_eq(enemy.hp, 90, "combo_breath 重打末位 → hp=90")

# ─── SHARED PASSIVE: flame_aura（共鸣火系）─────────────────

func test_flame_aura_resonance_scales_with_fire_count() -> void:
	var p := Combatant.new(&"p", "P", 80)
	# 链条 3 张全是火卡，每张 5 dmg
	var cd1 := _make_card(1, 5, [&"fire"])
	var cd2 := _make_card(1, 5, [&"fire"])
	var cd3 := _make_card(1, 5, [&"fire"])
	var slot1 := ChainSlot.new(CardRuntime.new(cd1))
	var slot2 := ChainSlot.new(CardRuntime.new(cd2))
	var slot3 := ChainSlot.new(CardRuntime.new(cd3))
	var aura_inst := TraitInstance.new(_load("flame_aura"))
	slot1.shared_trait = aura_inst
	slot2.shared_trait = aura_inst
	slot3.shared_trait = aura_inst
	p.chain.set_layout([slot1, slot2, slot3])
	var enemy := Combatant.new(&"e", "E", 200)
	var ctx := BattleContext.new(p, [enemy])
	# 每张火卡命中 = 5 + 1*3(链中 3 张火) = 8
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 192, "flame_aura: 5+3=8 dmg")
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 184, "flame_aura: 第二张同样")
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 176, "flame_aura: 第三张同样")

func test_flame_aura_ignores_non_fire_cards() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var cd_fire := _make_card(1, 5, [&"fire"])
	var cd_nonfire := _make_card(1, 5, [&"sword"])
	var slot1 := ChainSlot.new(CardRuntime.new(cd_fire))
	var slot2 := ChainSlot.new(CardRuntime.new(cd_nonfire))
	var aura := TraitInstance.new(_load("flame_aura"))
	slot1.shared_trait = aura
	slot2.shared_trait = aura
	p.chain.set_layout([slot1, slot2])
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	# 火卡：5 + 1*1(只有 1 张火) = 6；剑卡：5（不受 aura 影响）
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 94, "火卡 = 6 dmg")
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 89, "剑卡 = 5 dmg（aura 不修饰非火卡）")

# ─── SHARED ON_PLAY: echo_chamber（重打前一张）────────────

func test_echo_chamber_replays_previous_card() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var cd1 := _make_card(1, 7)  # 第一张
	var cd2 := _make_card(1, 3)  # 第二张：echo 触发 → 复打第一张
	var slot1 := ChainSlot.new(CardRuntime.new(cd1))
	var slot2 := ChainSlot.new(CardRuntime.new(cd2))
	var echo_data := _load("echo_chamber")
	(echo_data.effect as TraitEffectEcho).reset()  # 清状态污染
	var echo := TraitInstance.new(echo_data)
	slot1.shared_trait = echo
	slot2.shared_trait = echo
	p.chain.set_layout([slot1, slot2])
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	# tick 1: cd1 fire (7 dmg) → echo 触发但前一张 idx=-1 → 不触发
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 93, "cd1 fire = 7 dmg")
	# tick 2: cd2 fire (3 dmg) → echo 触发 → 重打 cd1 (7 dmg) → 总 10 dmg
	p.chain.on_tick(ctx)
	assert_eq(enemy.hp, 83, "cd2 (3) + echo cd1 (7) = -10")

# ─── SHARED ON_RECOVERY: recovery_blast（修整施 buff）────

func test_recovery_blast_grants_charge_on_recovery() -> void:
	var p := Combatant.new(&"p", "P", 80)
	var cd := _make_card(1, 5)
	var slot := ChainSlot.new(CardRuntime.new(cd))
	slot.shared_trait = TraitInstance.new(_load("recovery_blast"))
	p.chain.set_layout([slot])
	var enemy := Combatant.new(&"e", "E", 100)
	var ctx := BattleContext.new(p, [enemy])
	# tick 1: fire → 进入 recovery → 触发 recovery_blast → +2 charge
	p.chain.on_tick(ctx)
	var ch := p.get_status(StatusInstance.ID_CHARGE)
	assert_not_null(ch)
	assert_eq(ch.stacks, 2, "recovery_blast +2 充能")

# ─── 互斥校验真实运行 ───────────────────────────────────────

func test_swift_strike_and_fragile_edge_mutex() -> void:
	# 两者都 tags=[cost_mod]，都 mutex_tags=[cost_mod] → 互斥
	var swift := _load("swift_strike")
	var fragile := _load("fragile_edge")
	assert_true(swift.is_mutex_with(fragile), "swift_strike 与 fragile_edge 应互斥（同 cost_mod）")

func test_sharp_blade_no_mutex_with_swift() -> void:
	var sharp := _load("sharp_blade")
	var swift := _load("swift_strike")
	assert_false(sharp.is_mutex_with(swift), "sharp_blade 与 swift_strike 不互斥（不同 tag 类）")
