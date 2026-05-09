# src/core/effects/traits/trait_effect_recovery_buff.gd
# 词条效果：进入修整时给 owner 施加状态（如临时增伤标记）
# 阶段 2 §2.1 / GDD §3.5 修整触发型
# 典型词条：修整爆发（recovery_blast）— 进入修整时所有卡 +2 伤（持续 N tick）
#
# 实现：进入修整时给 owner 施加一个标记状态（如 ID_MARK），下一轮卡命中时使用
# 这里直接给 owner 施加 STRENGTH 状态（如果项目有），简化为加 charge 充能
class_name TraitEffectRecoveryBuff extends TraitEffect

@export var status_id: StringName = &"charge"  # 默认给充能
@export var stacks: int = 2
@export var duration_ticks: int = -1  # -1 = 永久（直到被消耗）

func on_recovery_started(_ctx: BattleContext, owner: Combatant) -> void:
	if owner == null:
		return
	var status := StatusInstance.new(status_id, stacks, duration_ticks)
	owner.apply_status(status)
