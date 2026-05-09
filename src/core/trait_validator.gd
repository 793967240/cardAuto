# src/core/trait_validator.gd
# 词条互斥校验器
# 阶段 2 §2.1 / TC-2-CORE-003
#
# 输入：某个槽位（独立词条）或某个扩展底座（共享词条）已挂载的词条列表 + 待添加的词条
# 输出：是否允许 + 冲突的词条引用（用于 UI 提示）
#
# 互斥规则：
#   - 独立词条：基础底座单个槽位最多 1 个词条（D2 决议），所以 existing 至多 1 个
#   - 共享词条：扩展底座共享 1 个词条，existing 至多 1 个
#   - 不同槽位/底座之间不互斥（互斥只在同一挂载点内部）
#   - mutex_tags 与 tags 交集 = 互斥（详见 TraitData.is_mutex_with）
class_name TraitValidator extends RefCounted

class Result extends RefCounted:
	var ok: bool
	var conflict: TraitData = null   # 冲突的已挂载词条（如有）
	var reason: StringName = &""     # error key: trait.error.slot_full / trait.error.mutex

	func _init(allowed: bool, conflict_with: TraitData = null, why: StringName = &"") -> void:
		ok = allowed
		conflict = conflict_with
		reason = why


## 校验词条能否挂载到指定挂载点
## @param existing - 该挂载点当前已有的词条列表（基础槽位/扩展底座，至多 1 个）
## @param incoming - 待挂载的词条
static func can_attach(existing: Array, incoming: TraitData) -> Result:
	if incoming == null:
		return Result.new(false, null, &"trait.error.null")

	# 槽位已满（D2 决议：单挂载点 ≤ 1 词条）
	if existing.size() >= 1:
		# 这里是替换语义还是拒绝语义？阶段 2 默认拒绝，由 UI 引导玩家先撤掉旧词条
		return Result.new(false, existing[0], &"trait.error.slot_full")

	# 互斥检查（虽然当前 existing 至多 1 个，仍为未来扩展保留循环）
	for t in existing:
		var td: TraitData = t
		if incoming.is_mutex_with(td):
			return Result.new(false, td, &"trait.error.mutex")

	return Result.new(true)


## 替换语义校验：允许覆盖时调用
## 始终允许，但返回被替换的词条供 UI 二次确认
static func can_replace(existing: Array, incoming: TraitData) -> Result:
	if incoming == null:
		return Result.new(false, null, &"trait.error.null")
	# 替换不触发 slot_full 错误，但仍校验 mutex
	for t in existing:
		var td: TraitData = t
		if td == incoming:
			# 同一词条重复挂载视为无效
			return Result.new(false, td, &"trait.error.duplicate")
	# 互斥规则在替换语义下通常等价于"被替换" — 这里直接放行
	if existing.size() > 0:
		return Result.new(true, existing[0], &"trait.action.replace")
	return Result.new(true)
