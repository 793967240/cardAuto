# src/core/chain.gd
# 链条执行器 - 管理卡牌顺序执行与修整阶段
# 不依赖任何 UI 节点
class_name Chain extends RefCounted

enum ChainState {
	EXECUTING,
	RECOVERING,
}

var slots: Array[CardRuntime] = []
var layout: Array = []              # Array[ChainSlot]，与 slots 等长，承载词条元数据
var current_index: int = 0
var current_card_progress: int = 0  # 当前牌已积累的 tick
var recovery_remaining: int = 0     # 修整剩余 tick
var state: ChainState = ChainState.EXECUTING

## 所属战斗者（用于效果触发时传递 source）
var owner: Combatant

signal card_fired(card: CardRuntime, index: int)
signal recovery_started(duration: int)
signal recovery_ended()
signal chain_empty()  # 链条无牌时

func _init(combatant: Combatant) -> void:
	owner = combatant

## 每 tick 由 BattleContext 调用
func on_tick(ctx: BattleContext) -> void:
	if slots.is_empty():
		chain_empty.emit()
		return

	if state == ChainState.RECOVERING:
		recovery_remaining -= 1
		if recovery_remaining <= 0:
			_restart_chain(ctx)
		return

	var card := slots[current_index]

	# 跳过已消耗的卡（一次性卡）
	if card.is_consumed:
		_advance_index(ctx)
		return

	current_card_progress += 1
	if current_card_progress >= _effective_cost(card, ctx):
		card.fire(ctx, owner)
		_fire_trait_hook(current_index, &"on_card_played", [card, ctx, owner])
		card_fired.emit(card, current_index)
		current_card_progress = 0
		_advance_index(ctx)

func _advance_index(ctx: BattleContext) -> void:
	current_index += 1
	if current_index >= slots.size():
		_enter_recovery(ctx)

func _enter_recovery(ctx: BattleContext) -> void:
	state = ChainState.RECOVERING
	recovery_remaining = ctx.compute_recovery_duration(owner)
	# ON_RECOVERY hook（对所有槽位触发，去重共享词条避免重复）
	_fire_trait_hook_all(&"on_recovery_started", [ctx, owner])
	recovery_started.emit(recovery_remaining)

func _restart_chain(ctx: BattleContext) -> void:
	# ON_CHAIN_END hook（修整结束 = 一轮链条完成）
	_fire_trait_hook_all(&"on_chain_ended", [ctx, owner])
	state = ChainState.EXECUTING
	current_index = 0
	current_card_progress = 0
	recovery_ended.emit()

## 在指定槽位触发词条 hook
func _fire_trait_hook(idx: int, method: StringName, args: Array) -> void:
	for t in _active_traits_for_index(idx):
		var ti: TraitInstance = t
		if ti.data.trigger == TraitData.Trigger.PASSIVE:
			continue  # PASSIVE 由 modify_cost / modify_damage 处理，不走事件 hook
		var eff := ti.get_effect()
		if eff == null:
			continue
		if eff.has_method(method):
			eff.callv(method, args)

## 对所有槽位触发 hook（共享词条按引用去重，避免一个共享词条被触发多次）
func _fire_trait_hook_all(method: StringName, args: Array) -> void:
	var fired_shared: Array = []  # 记录已触发的共享 TraitInstance 引用
	for cs in layout:
		var slot: ChainSlot = cs
		if slot == null:
			continue
		# 独立词条
		if slot.independent_trait != null:
			var ti_ind := slot.independent_trait
			if ti_ind.data.trigger != TraitData.Trigger.PASSIVE:
				var eff_ind := ti_ind.get_effect()
				if eff_ind != null and eff_ind.has_method(method):
					eff_ind.callv(method, args)
		# 共享词条（按引用去重）
		if slot.shared_trait != null and not (slot.shared_trait in fired_shared):
			fired_shared.append(slot.shared_trait)
			var ti_sh := slot.shared_trait
			if ti_sh.data.trigger != TraitData.Trigger.PASSIVE:
				var eff_sh := ti_sh.get_effect()
				if eff_sh != null and eff_sh.has_method(method):
					eff_sh.callv(method, args)

## 重置当前卡进度（打断效果使用）
func reset_current_card_progress() -> void:
	current_card_progress = 0

## 计算卡牌的实际 cost（考虑 owner 的 vulnerable 状态 + 词条修饰）
func _effective_cost(card: CardRuntime, ctx: BattleContext) -> int:
	var base := card.effective_cost(ctx)
	# 词条 PASSIVE.modify_cost 聚合
	for t in _active_traits_for_index(current_index):
		var eff := (t as TraitInstance).get_effect()
		if eff != null and (t as TraitInstance).data.trigger == TraitData.Trigger.PASSIVE:
			base = eff.modify_cost(card, base)
	# 易伤：cost +1
	if owner and owner.has_status(StatusInstance.ID_VULNERABLE):
		base += 1
	return max(1, base)

## 计算卡牌伤害修饰（由具体效果在 fire 时查询 chain.modify_damage）
func modify_damage(card: CardRuntime, base: int, slot_index: int = -1) -> int:
	var idx := slot_index if slot_index >= 0 else current_index
	var out := base
	for t in _active_traits_for_index(idx):
		var eff := (t as TraitInstance).get_effect()
		if eff != null and (t as TraitInstance).data.trigger == TraitData.Trigger.PASSIVE:
			out = eff.modify_damage(card, out)
	return out

## 取出指定槽位的所有生效词条（独立 + 共享）
func _active_traits_for_index(idx: int) -> Array:
	if idx < 0 or idx >= layout.size():
		return []
	var slot: ChainSlot = layout[idx]
	if slot == null:
		return []
	return slot.active_traits()

## 设置链条卡牌（旧 API，无词条；保留向后兼容）
func set_slots(cards: Array[CardRuntime]) -> void:
	slots = cards
	# 同步生成空 layout（每槽一个无词条 ChainSlot）
	layout.clear()
	for c in cards:
		layout.append(ChainSlot.new(c))
	current_index = 0
	current_card_progress = 0
	state = ChainState.EXECUTING

## 设置链条布局（新 API，含词条元数据）
func set_layout(chain_slots: Array) -> void:
	layout = chain_slots
	slots.clear()
	for s in chain_slots:
		var cs: ChainSlot = s
		slots.append(cs.card)
	current_index = 0
	current_card_progress = 0
	state = ChainState.EXECUTING

## 是否在修整阶段
func is_recovering() -> bool:
	return state == ChainState.RECOVERING

## 获取当前执行的卡（UI 高亮用）
func get_current_card() -> CardRuntime:
	if slots.is_empty() or current_index >= slots.size():
		return null
	return slots[current_index]
