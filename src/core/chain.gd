# src/core/chain.gd
# 链条执行器 - 管理卡牌顺序执行与修整阶段
# 不依赖任何 UI 节点
class_name Chain extends RefCounted

enum ChainState {
	EXECUTING,
	RECOVERING,
}

var slots: Array[CardRuntime] = []
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
	if current_card_progress >= card.effective_cost(ctx):
		card.fire(ctx, owner)
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
	recovery_started.emit(recovery_remaining)

func _restart_chain(ctx: BattleContext) -> void:
	state = ChainState.EXECUTING
	current_index = 0
	current_card_progress = 0
	recovery_ended.emit()

## 重置当前卡进度（打断效果使用）
func reset_current_card_progress() -> void:
	current_card_progress = 0

## 设置链条卡牌
func set_slots(cards: Array[CardRuntime]) -> void:
	slots = cards
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
