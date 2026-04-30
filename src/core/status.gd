# src/core/status.gd
# 状态/标签系统 - 虚弱/易伤/燃烧/充能等
class_name StatusInstance extends RefCounted

var status_id: StringName       # &"weakness" / &"vulnerable" / &"burn" / &"charge"
var stacks: int = 1
var remaining_ticks: int = -1   # -1 = 永久（直到被消耗）
var on_apply: Callable          # 施加时回调
var on_tick: Callable           # 每 tick 回调
var on_expire: Callable         # 到期回调

func _init(id: StringName, stack_count: int = 1, duration: int = -1) -> void:
	status_id = id
	stacks = stack_count
	remaining_ticks = duration

## 推进 1 tick，返回是否已到期
func advance_tick(owner: Combatant, ctx: BattleContext) -> bool:
	if on_tick.is_valid():
		on_tick.call(owner, ctx, self)

	if remaining_ticks > 0:
		remaining_ticks -= 1
		if remaining_ticks <= 0:
			if on_expire.is_valid():
				on_expire.call(owner, ctx, self)
			return true  # 已到期，应移除

	return false

## 叠加层数
func add_stacks(count: int) -> void:
	stacks += count

## 消耗层数，返回实际消耗数（不超过现有层数）
func consume_stacks(count: int) -> int:
	var consumed: int = min(count, stacks)
	stacks -= consumed
	return consumed


# ─── 常用 Status ID 常量 ───────────────────────────────────────
const ID_WEAKNESS := &"weakness"       # 受到伤害 +50%
const ID_VULNERABLE := &"vulnerable"   # cost +1 tick
const ID_SLOW := &"slow"               # 链条速度 -50%
const ID_BURN := &"burn"               # 每 tick X 伤害
const ID_FREEZE := &"freeze"           # 链条暂停 N tick
const ID_MARK := &"mark"               # 下次受伤 +X
const ID_CHARGE := &"charge"           # 玩家充能资源（剑修/炼丹师）
const ID_INTERRUPT_IMMUNE := &"interrupt_immune"  # 打断免疫
