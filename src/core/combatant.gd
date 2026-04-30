# src/core/combatant.gd
# 战斗参与者基类（玩家/敌人共用）
class_name Combatant extends RefCounted

var combatant_id: StringName
var display_name: String
var max_hp: int
var hp: int
var tags: Array[StringName] = []          # 角色标签（&"sword", &"player" 等）
var statuses: Array[StatusInstance] = []  # 当前状态列表
var chain: Chain                           # 该战斗者的链条

signal hp_changed(old_val: int, new_val: int)
signal died()
signal status_applied(status: StatusInstance)
signal status_expired(status_id: StringName)

func _init(id: StringName, name: String, hp_max: int) -> void:
	combatant_id = id
	display_name = name
	max_hp = hp_max
	hp = hp_max
	chain = Chain.new(self)

## 受到伤害（考虑虚弱状态）
func take_damage(amount: int, source_tags: Array[StringName] = []) -> int:
	var final_dmg := amount
	# 虚弱：受到伤害 +50%
	if has_status(StatusInstance.ID_WEAKNESS):
		final_dmg = int(final_dmg * 1.5)
	# 印记：一次性额外伤害
	var mark := get_status(StatusInstance.ID_MARK)
	if mark:
		final_dmg += mark.stacks
		remove_status(StatusInstance.ID_MARK)

	var old_hp := hp
	hp = max(0, hp - final_dmg)
	hp_changed.emit(old_hp, hp)
	if hp <= 0:
		died.emit()
	return final_dmg

## 回复血量
func heal(amount: int) -> void:
	var old_hp := hp
	hp = min(max_hp, hp + amount)
	hp_changed.emit(old_hp, hp)

## 是否存活
func is_alive() -> bool:
	return hp > 0

## 施加状态
func apply_status(status: StatusInstance) -> void:
	# 如果已有同类状态，叠加层数
	var existing := get_status(status.status_id)
	if existing:
		existing.add_stacks(status.stacks)
		if status.remaining_ticks > 0:
			existing.remaining_ticks = max(existing.remaining_ticks, status.remaining_ticks)
	else:
		statuses.append(status)
		if status.on_apply.is_valid():
			status.on_apply.call(self)
		status_applied.emit(status)

## 每 tick 推进所有状态
func tick_statuses(ctx: BattleContext) -> void:
	var to_remove: Array[StatusInstance] = []
	for s in statuses:
		if s.advance_tick(self, ctx):
			to_remove.append(s)
	for s in to_remove:
		statuses.erase(s)
		status_expired.emit(s.status_id)

## 获取指定状态
func get_status(id: StringName) -> StatusInstance:
	for s in statuses:
		if s.status_id == id:
			return s
	return null

## 是否拥有指定状态
func has_status(id: StringName) -> bool:
	return get_status(id) != null

## 移除指定状态
func remove_status(id: StringName) -> void:
	var s := get_status(id)
	if s:
		statuses.erase(s)
		status_expired.emit(id)
