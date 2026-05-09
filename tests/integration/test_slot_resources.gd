# tests/integration/test_slot_resources.gd
# 阶段 2 §2.2 / TC-2-DATA-006
# 验证 1 基础底座 + 9 扩展底座 .tres 全部能加载，并能进 ChainComposer
extends GutTest

const BASE_SLOT_PATHS := {
	"sword_base": "res://data/slots/base/sword_base.tres",
}

const EXT_SLOT_PATHS := {
	"ext_1x1_simple": "res://data/slots/extended/ext_1x1_simple.tres",
	"ext_1x1_charged": "res://data/slots/extended/ext_1x1_charged.tres",
	"ext_1x1_swift": "res://data/slots/extended/ext_1x1_swift.tres",
	"ext_1x2_balanced": "res://data/slots/extended/ext_1x2_balanced.tres",
	"ext_1x2_resonance": "res://data/slots/extended/ext_1x2_resonance.tres",
	"ext_1x2_echo": "res://data/slots/extended/ext_1x2_echo.tres",
	"ext_1x3_long": "res://data/slots/extended/ext_1x3_long.tres",
	"ext_1x3_combo": "res://data/slots/extended/ext_1x3_combo.tres",
	"ext_1x3_recovery": "res://data/slots/extended/ext_1x3_recovery.tres",
}

func _make_card(cost: int = 1, dmg: int = 5) -> CardData:
	var cd := CardData.new()
	cd.id = &"test"
	cd.cost = cost
	var fx := EffectAttack.new()
	fx.damage = dmg
	cd.effect = fx
	return cd

# ─── .tres 加载 ──────────────────────────────────────────────

func test_base_slot_loads_with_correct_schema() -> void:
	var s := load(BASE_SLOT_PATHS["sword_base"]) as SlotData
	assert_not_null(s, "sword_base 加载成功")
	assert_eq(s.id, &"sword_base")
	assert_eq(s.slot_count, 6, "基础底座 6 槽位")
	assert_true(s.is_base(), "is_base() 真")
	assert_false(s.is_extension())
	assert_false(s.has_bead_in, "基础底座无入口珠")
	assert_true(s.has_bead_out, "基础底座有出口珠")

func test_all_extension_slots_load() -> void:
	for id in EXT_SLOT_PATHS:
		var s := load(EXT_SLOT_PATHS[id]) as SlotData
		assert_not_null(s, "%s 加载成功" % id)
		assert_eq(s.id, StringName(id), "%s id 匹配" % id)
		assert_true(s.is_extension(), "%s 是扩展底座" % id)
		assert_true(s.has_bead_in, "%s 有入口珠" % id)
		assert_true(s.has_bead_out, "%s 有出口珠" % id)
		assert_eq(s.shared_trait_slots, 1, "%s 含共享词条槽" % id)

func test_extension_slot_counts_match_naming() -> void:
	# 命名约定: ext_1xN_xxx → slot_count = N
	for id in EXT_SLOT_PATHS:
		var s := load(EXT_SLOT_PATHS[id]) as SlotData
		var expected := -1
		if id.begins_with("ext_1x1"):
			expected = 1
		elif id.begins_with("ext_1x2"):
			expected = 2
		elif id.begins_with("ext_1x3"):
			expected = 3
		assert_eq(s.slot_count, expected, "%s slot_count = %d" % [id, expected])

# ─── 与 ChainComposer 集成 ──────────────────────────────────

func test_base_only_compiles() -> void:
	var base := load(BASE_SLOT_PATHS["sword_base"]) as SlotData
	var spec := ChainComposer.Spec.new()
	spec.slots = [base]
	var cards: Array = []
	for i in 6:
		cards.append(_make_card())
	spec.slot_cards = {&"sword_base": cards}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0)
	assert_eq(r.layout.size(), 6, "6 槽全有卡 → layout 6")

func test_base_plus_1x1_compiles() -> void:
	var base := load(BASE_SLOT_PATHS["sword_base"]) as SlotData
	var ext := load(EXT_SLOT_PATHS["ext_1x1_simple"]) as SlotData
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext]
	spec.connections = {&"sword_base": &"ext_1x1_simple"}
	var b_cards: Array = []
	for i in 6:
		b_cards.append(_make_card())
	spec.slot_cards = {
		&"sword_base": b_cards,
		&"ext_1x1_simple": [_make_card()],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0)
	assert_eq(r.layout.size(), 7, "6 + 1 = 7 张")
	assert_eq(r.connected_bases.size(), 2)

func test_base_plus_1x2_plus_1x3_compiles() -> void:
	var base := load(BASE_SLOT_PATHS["sword_base"]) as SlotData
	var ext_2 := load(EXT_SLOT_PATHS["ext_1x2_balanced"]) as SlotData
	var ext_3 := load(EXT_SLOT_PATHS["ext_1x3_long"]) as SlotData
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext_2, ext_3]
	spec.connections = {
		&"sword_base": &"ext_1x2_balanced",
		&"ext_1x2_balanced": &"ext_1x3_long",
	}
	var b_cards: Array = []
	for i in 6:
		b_cards.append(_make_card())
	spec.slot_cards = {
		&"sword_base": b_cards,
		&"ext_1x2_balanced": [_make_card(), _make_card()],
		&"ext_1x3_long": [_make_card(), _make_card(), _make_card()],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0)
	assert_eq(r.layout.size(), 11, "6 + 2 + 3 = 11 张")
	assert_eq(r.connected_bases.size(), 3)

func test_max_chain_length_three_extensions() -> void:
	# 6 + 3*3 = 15 张（三个 1×3 串联）
	var base := load(BASE_SLOT_PATHS["sword_base"]) as SlotData
	var e1 := load(EXT_SLOT_PATHS["ext_1x3_long"]) as SlotData
	var e2 := load(EXT_SLOT_PATHS["ext_1x3_combo"]) as SlotData
	var e3 := load(EXT_SLOT_PATHS["ext_1x3_recovery"]) as SlotData
	var spec := ChainComposer.Spec.new()
	spec.slots = [base, e1, e2, e3]
	spec.connections = {
		&"sword_base": &"ext_1x3_long",
		&"ext_1x3_long": &"ext_1x3_combo",
		&"ext_1x3_combo": &"ext_1x3_recovery",
	}
	var b_cards: Array = []
	for i in 6:
		b_cards.append(_make_card())
	spec.slot_cards = {
		&"sword_base": b_cards,
		&"ext_1x3_long": [_make_card(), _make_card(), _make_card()],
		&"ext_1x3_combo": [_make_card(), _make_card(), _make_card()],
		&"ext_1x3_recovery": [_make_card(), _make_card(), _make_card()],
	}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0)
	assert_eq(r.layout.size(), 15, "6 + 9 = 15 张满链")
