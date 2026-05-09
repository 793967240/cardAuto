# src/core/chain_composer.gd
# 链条组合器 - 把"玩家持有的多个底座 + 珠子连线 + 卡牌摆放 + 词条挂载"
# 编译成 Chain 可消费的 Array[ChainSlot]
#
# 阶段 2 §2.2 / TC-2-CORE-005 + TC-2-CORE-006
#
# 设计要点（GDD §3.3）：
#   - 链条形态为「单链」：基础底座 → 扩展底座 A → B → ...（不允许分叉/成环）
#   - 基础底座必须存在且唯一，是链头
#   - 未被任何路径连通的扩展底座「整组不参战」
#   - 共享词条按"扩展底座 id"为粒度，同一底座所有槽位共享同一 TraitInstance 引用
#   - 独立词条以 (base_id, slot_index) 为粒度
#
# 用法：
#   var spec := ChainComposer.Spec.new()
#   spec.slots = [base_slot, ext_a, ext_b]
#   spec.connections = {&"sword_base": &"ext_a", &"ext_a": &"ext_b"}
#   spec.slot_cards = {&"sword_base": [c1, c2, ...], &"ext_a": [c7, c8], ...}
#   var result := ChainComposer.compose(spec)
#   chain.set_layout(result.layout)
class_name ChainComposer extends RefCounted


## 输入规格
class Spec extends RefCounted:
	## 玩家持有的所有底座（基础 + 扩展），顺序无关
	var slots: Array = []  # Array[SlotData]
	## 珠子连线：出口底座 id → 入口底座 id
	## 例：{&"sword_base": &"ext_a", &"ext_a": &"ext_b"}
	var connections: Dictionary = {}
	## 每个底座的卡牌摆放：底座 id → Array[CardData]，长度应等于 slot.slot_count（含 null 占位）
	var slot_cards: Dictionary = {}
	## 独立词条挂载：键 = "{base_id}:{slot_index}"，值 = TraitData
	var independent_traits: Dictionary = {}
	## 共享词条挂载：扩展底座 id → TraitData
	var shared_traits: Dictionary = {}


## 输出结果
class Result extends RefCounted:
	## 编译完成的链条（喂给 Chain.set_layout）
	var layout: Array = []  # Array[ChainSlot]
	## 实际接入链条的底座（按链条顺序）
	var connected_bases: Array = []  # Array[SlotData]
	## 未被连通的扩展底座（不参战，UI 灰显）
	var orphan_bases: Array = []  # Array[SlotData]
	## 链条总时长（tick）— 仅卡牌 base cost 之和，不含词条修饰
	var total_cost: int = 0
	## 编译错误（链头缺失 / 成环 / 分叉）
	var errors: Array = []  # Array[StringName]


## 主入口
static func compose(spec: Spec) -> Result:
	var result := Result.new()

	# 1) 找链头（基础底座，应有且只有 1 个）
	var base: SlotData = null
	var seen_bases: Array = []
	for s in spec.slots:
		var sd: SlotData = s
		if sd.is_base():
			seen_bases.append(sd)
	if seen_bases.size() == 0:
		result.errors.append(&"no_base_slot")
		return result
	if seen_bases.size() > 1:
		result.errors.append(&"multiple_base_slots")
		return result
	base = seen_bases[0]

	# 2) 建索引：id → SlotData
	var by_id: Dictionary = {}
	for s in spec.slots:
		var sd: SlotData = s
		by_id[sd.id] = sd

	# 3) 沿珠子连线遍历，构造已连通底座列表
	var visited: Dictionary = {}  # 防成环
	var ordered: Array = []       # Array[SlotData]
	var cursor: SlotData = base
	while cursor != null:
		if visited.has(cursor.id):
			result.errors.append(&"cycle_detected")
			return result
		visited[cursor.id] = true
		ordered.append(cursor)
		# 找 cursor 的下一节
		var next_id = spec.connections.get(cursor.id, null)
		if next_id == null:
			break
		if not by_id.has(next_id):
			result.errors.append(&"dangling_connection")
			return result
		var next_slot: SlotData = by_id[next_id]
		# 校验：被连接的必须是扩展底座
		if next_slot.is_base():
			result.errors.append(&"base_as_target")
			return result
		# 校验：扩展底座不能被多次接入（分叉）
		# 这里的检测放在"反向：检查每个 next_id 是否被多个底座指向"更好
		cursor = next_slot

	# 4) 检测分叉：connections.values() 内不允许重复
	var inbound: Dictionary = {}
	for src_id in spec.connections:
		var dst_id = spec.connections[src_id]
		if inbound.has(dst_id):
			result.errors.append(&"fork_detected")
			return result
		inbound[dst_id] = src_id

	# 5) 标记 orphan：spec.slots 中未出现在 ordered 的扩展底座
	var ordered_ids: Dictionary = {}
	for sd in ordered:
		ordered_ids[sd.id] = true
	for s in spec.slots:
		var sd: SlotData = s
		if sd.is_extension() and not ordered_ids.has(sd.id):
			result.orphan_bases.append(sd)

	result.connected_bases = ordered

	# 6) 编译 layout：按 ordered 顺序展开每个底座的槽位
	#    共享词条按底座 id 缓存 TraitInstance（同一底座所有槽位引用同一个 inst）
	var shared_inst_cache: Dictionary = {}  # base_id → TraitInstance

	for sd in ordered:
		var sd_typed: SlotData = sd
		# 该底座的共享词条 inst（仅扩展底座）
		var shared_inst: TraitInstance = null
		if sd_typed.is_extension() and spec.shared_traits.has(sd_typed.id):
			if shared_inst_cache.has(sd_typed.id):
				shared_inst = shared_inst_cache[sd_typed.id]
			else:
				var st_data: TraitData = spec.shared_traits[sd_typed.id]
				if st_data != null:
					shared_inst = TraitInstance.new(st_data)
					shared_inst_cache[sd_typed.id] = shared_inst

		# 该底座的卡牌
		var cards_in_base: Array = spec.slot_cards.get(sd_typed.id, [])

		for slot_index in sd_typed.slot_count:
			var card_data: CardData = null
			if slot_index < cards_in_base.size():
				card_data = cards_in_base[slot_index]
			# 跳过空槽（卡数组中 null 表示该槽位未摆牌）
			if card_data == null:
				continue
			var rt := CardRuntime.new(card_data)
			var cs := ChainSlot.new(rt, sd_typed.id)
			# 累计 base cost
			result.total_cost += card_data.cost

			# 独立词条（仅基础底座槽位）
			if sd_typed.is_base():
				var ind_key := "%s:%d" % [str(sd_typed.id), slot_index]
				if spec.independent_traits.has(ind_key):
					var ind_data: TraitData = spec.independent_traits[ind_key]
					if ind_data != null:
						cs.independent_trait = TraitInstance.new(ind_data)

			# 共享词条（扩展底座所有槽位引用同一 inst）
			if sd_typed.is_extension() and shared_inst != null:
				cs.shared_trait = shared_inst

			result.layout.append(cs)

	return result
