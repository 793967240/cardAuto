# tests/integration/test_bead_connection.gd
# 阶段 2 §2.2 / TC-2-UI-002 BeadConnectionView 交互逻辑测试
#
# 注意：直接走 _handle_click(pos)，不模拟 InputEvent，让测试稳定。
# 完整鼠标事件路径留给手动 / 4-resolution UI 巡检。
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

func _make_view(slots: Array) -> BeadConnectionView:
	var v := BeadConnectionView.new()
	add_child_autofree(v)
	v.set_slots(slots)
	return v

func _click_out_bead(view: BeadConnectionView, slot_id: StringName) -> void:
	# 通过私有字典获取珠子位置然后调用 _handle_click
	var pos: Vector2 = view._bead_out_pos[slot_id]
	view._handle_click(pos)

func _click_in_bead(view: BeadConnectionView, slot_id: StringName) -> void:
	var pos: Vector2 = view._bead_in_pos[slot_id]
	view._handle_click(pos)

# ─── 基础布局 ────────────────────────────────────────────────

func test_set_slots_populates_bead_positions() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	# 基础底座只有出口珠
	assert_true(v._bead_out_pos.has(&"sword_base"))
	assert_false(v._bead_in_pos.has(&"sword_base"))
	# 扩展底座有进出双珠
	assert_true(v._bead_in_pos.has(&"ext_a"))
	assert_true(v._bead_out_pos.has(&"ext_a"))

# ─── 两步法连线 ──────────────────────────────────────────────

func test_click_out_then_in_creates_connection() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	# 1) 点 sword_base 出口
	_click_out_bead(v, &"sword_base")
	assert_eq(v._selected_out_id, &"sword_base", "出口被选中")
	# 2) 点 ext_a 入口
	_click_in_bead(v, &"ext_a")
	# 连线创建
	assert_eq(v.get_connections(), {&"sword_base": &"ext_a"}, "连线创建")
	# 选中态清空
	assert_eq(v._selected_out_id, &"", "选中态清空")

func test_click_blank_clears_selection() -> void:
	var base := _make_base(&"sword_base")
	var v := _make_view([base])
	_click_out_bead(v, &"sword_base")
	assert_eq(v._selected_out_id, &"sword_base")
	# 点空白（远离任何珠子）
	v._handle_click(Vector2(5, 5))
	assert_eq(v._selected_out_id, &"")

# ─── 删除连线 ────────────────────────────────────────────────

func test_click_used_out_bead_removes_connection() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	v.set_connections({&"sword_base": &"ext_a"})
	# 点已有连线的出口珠 → 删除
	_click_out_bead(v, &"sword_base")
	assert_eq(v.get_connections().size(), 0, "连线被删除")

func test_click_used_in_bead_removes_connection() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	v.set_connections({&"sword_base": &"ext_a"})
	_click_in_bead(v, &"ext_a")
	assert_eq(v.get_connections().size(), 0, "连线被删除（点入口端）")

# ─── 校验：成环 / 分叉 / 自连 / 连基础 ───────────────────────

func test_cannot_connect_to_base_slot() -> void:
	# 基础底座无 has_bead_in，所以这种点击根本不会触发，但保险测一下
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	# 改造：手动让基础底座有入口珠（异常配置）
	v._bead_in_pos[&"sword_base"] = Vector2(0, 30)
	_click_out_bead(v, &"ext_a")
	_click_in_bead(v, &"sword_base")
	assert_eq(v.get_connections().size(), 0, "基础底座作为目标被拒")

func test_clicking_used_in_bead_deletes_existing_connection() -> void:
	# UX：点击已被指向的入口珠 = 撤销该连线（KISS）
	# 即"分叉"在 UI 层不可能直接发生：要建立 ext_a→ext_b 必须先删 sword_base→ext_b
	var base := _make_base(&"sword_base")
	var ext_a := _make_ext(&"ext_a")
	var ext_b := _make_ext(&"ext_b")
	var v := _make_view([base, ext_a, ext_b])
	v.set_connections({&"sword_base": &"ext_b"})
	# 点 ext_a 出口选中
	_click_out_bead(v, &"ext_a")
	# 点 ext_b 入口（已被使用）→ 删除 sword_base→ext_b
	_click_in_bead(v, &"ext_b")
	assert_eq(v.get_connections().size(), 0, "已用入口被点击触发删除而非分叉")

func test_validator_rejects_fork_when_called_directly() -> void:
	# 兜底：即使外部脏数据 / 测试直接喂 set_connections，
	# _validate_connection 在尝试建立分叉时仍应返回 false
	var base := _make_base(&"sword_base")
	var ext_a := _make_ext(&"ext_a")
	var ext_b := _make_ext(&"ext_b")
	var v := _make_view([base, ext_a, ext_b])
	# 直接给内部塞 sword_base→ext_b（不经 UI）
	v._connections = {&"sword_base": &"ext_b"}
	# 此时 _validate_connection(ext_a, ext_b) 应返回 false（分叉）
	assert_false(v._validate_connection(&"ext_a", &"ext_b"),
		"_validate_connection 拒绝分叉")

func test_validator_rejects_cycle() -> void:
	# 同 fork：通过点击 UI 几乎制造不出真成环（点已用入口珠会先触发删除）
	# 这里直接调 _validate_connection 验证 validator 自身的成环检测
	var base := _make_base(&"sword_base")
	var ext_a := _make_ext(&"ext_a")
	var ext_b := _make_ext(&"ext_b")
	var v := _make_view([base, ext_a, ext_b])
	v._connections = {
		&"sword_base": &"ext_a",
		&"ext_a": &"ext_b",
	}
	# 尝试 ext_b → ext_a 应被识别为成环
	assert_false(v._validate_connection(&"ext_b", &"ext_a"),
		"_validate_connection 拒绝成环")

# ─── orphan 计算 ──────────────────────────────────────────────

func test_orphan_when_no_connection() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	# 无连线 → ext_a 是 orphan
	assert_true(&"ext_a" in v.get_orphan_ids(), "未连接的扩展底座是 orphan")

func test_orphan_resolved_after_connect() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	_click_out_bead(v, &"sword_base")
	_click_in_bead(v, &"ext_a")
	assert_eq(v.get_orphan_ids().size(), 0, "连线后 ext_a 不再是 orphan")

func test_partial_chain_partial_orphan() -> void:
	# base → ext_a 已连，ext_b 未连
	var base := _make_base(&"sword_base")
	var ext_a := _make_ext(&"ext_a")
	var ext_b := _make_ext(&"ext_b")
	var v := _make_view([base, ext_a, ext_b])
	v.set_connections({&"sword_base": &"ext_a"})
	var orphans := v.get_orphan_ids()
	assert_true(&"ext_b" in orphans)
	assert_false(&"ext_a" in orphans)

# ─── signal ──────────────────────────────────────────────────

func test_connections_changed_signal_emits_on_create() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	var emitted := [false]
	v.connections_changed.connect(func(): emitted[0] = true)
	_click_out_bead(v, &"sword_base")
	_click_in_bead(v, &"ext_a")
	assert_true(emitted[0], "创建连线触发 signal")

func test_connections_changed_signal_emits_on_remove() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	v.set_connections({&"sword_base": &"ext_a"})
	var count := [0]
	v.connections_changed.connect(func(): count[0] += 1)
	_click_out_bead(v, &"sword_base")  # 删除
	assert_eq(count[0], 1)

# ─── set/get connections ────────────────────────────────────

func test_set_connections_then_get_returns_copy() -> void:
	var base := _make_base(&"sword_base")
	var ext := _make_ext(&"ext_a")
	var v := _make_view([base, ext])
	var src := {&"sword_base": &"ext_a"}
	v.set_connections(src)
	var got := v.get_connections()
	assert_eq(got, src)
	# get 应返回副本（修改不影响内部）
	got[&"sword_base"] = &"ext_b"
	assert_eq(v.get_connections()[&"sword_base"], &"ext_a", "get 返回副本")

# ─── 与 ChainComposer 集成 ──────────────────────────────────

func test_connections_feed_into_chain_composer() -> void:
	# 这是 UI-002 与 CORE-005 的端到端契约：UI 输出的 connections 字典
	# 必须能直接喂给 ChainComposer.Spec
	var base := _make_base(&"sword_base", 1)
	var ext := _make_ext(&"ext_a", 1)
	var v := _make_view([base, ext])
	_click_out_bead(v, &"sword_base")
	_click_in_bead(v, &"ext_a")

	var spec := ChainComposer.Spec.new()
	spec.slots = [base, ext]
	spec.connections = v.get_connections()
	# 装一张占位卡进去验证编译成功
	var cd := CardData.new()
	cd.id = &"sample"
	cd.cost = 1
	spec.slot_cards = {&"sword_base": [cd], &"ext_a": [cd]}
	var r := ChainComposer.compose(spec)
	assert_eq(r.errors.size(), 0, "UI 输出可直接喂 ChainComposer")
	assert_eq(r.layout.size(), 2)
