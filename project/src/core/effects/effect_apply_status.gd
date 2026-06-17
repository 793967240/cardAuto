# src/core/effects/effect_apply_status.gd
# 施加状态效果 - 通用状态施加器（用于控制型卡牌）
class_name EffectApplyStatus extends CardEffect

## 施加目标：0=敌人, 1=自身
enum Target { ENEMY = 0, SELF = 1 }

@export var target_type: Target = Target.ENEMY
@export var status_id: StringName = &""
@export var stacks: int = 1
@export var duration: int = 3  # -1 = 永久

func fire(ctx: BattleContext, source: Combatant) -> void:
	var target: Combatant
	if target_type == Target.ENEMY:
		target = ctx.choose_target(source)
	else:
		target = source

	if not target or not target.is_alive():
		return

	var status := StatusInstance.new(status_id, stacks, duration)
	status.source_owner = source

	# 燃烧需要特殊处理 on_tick
	if status_id == StatusInstance.ID_BURN:
		status.on_tick = func(owner: Combatant, battle_ctx: BattleContext, self_status: StatusInstance) -> void:
			var dealt := owner.take_damage(self_status.stacks, [])
			battle_ctx.record_damage(self_status.source_owner, owner, dealt, "status.burn.name")

	target.apply_status(status)
	ctx.stats.cards_fired += 1
